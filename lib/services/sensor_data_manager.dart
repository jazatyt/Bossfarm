import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'sensor_api_service.dart';
import 'mock_xsmec20_injector.dart'; // demo XS-MEC20 device — see that file for details

class SensorDataManager extends ChangeNotifier {
  static final SensorDataManager _instance = SensorDataManager._internal();
  factory SensorDataManager() => _instance;
  SensorDataManager._internal();

  final String _baseUrl = Uri.base.origin;

  List<String> deviceIds = [];
  Map<String, String> deviceIps = {};
  final Map<String, SensorApiService> apiServices = {};
  final Map<String, bool> fetchingMap = {};
  final Map<String, bool> errorMap = {};

  final List<String> elementIds = [];
  final List<String> soilIds = [];
  final List<String> mineralIds = [];
  Set<String> _blacklistedIds = {}; // IDs manually deleted by user

  int getOnlineCount(List<String> ids) {
    int onlineCount = 0;
    for (var id in ids) {
      final service = apiServices[id];
      final latest = service?.latest;
      final isError = errorMap[id] ?? false;
      if (latest != null) {
        final isOffline = DateTime.now().difference(latest.time).inSeconds > 60;
        if (!isOffline && !isError) onlineCount++;
      }
    }
    return onlineCount;
  }

  Timer? _refreshTimer;
  bool _isInitialized = false;
  bool isFetchingDevices = true;

  // ── Date range state ──────────────────────────────────────────
  /// วันที่เริ่มต้นที่เลือก (null = ยังไม่ได้เลือก, ใช้ค่า default 24h)
  DateTime? selectedStart;
  /// วันที่สิ้นสุดที่เลือก
  DateTime? selectedEnd;
  // ─────────────────────────────────────────────────────────────

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _loadCustomDevices(); // Load from Hive first
    _fetchRegistry();
    _startTimer();
    maybeInjectMockXsMec20(this); // demo XS-MEC20 device — see mock_xsmec20_injector.dart
  }

  void _loadCustomDevices() {
    try {
      final box = Hive.box('sensors_box');
      final List<String> list = box.get('discovered_ids', defaultValue: <String>[]).cast<String>();
      for (var dId in list) {
        if (!apiServices.containsKey(dId)) {
          apiServices[dId] = SensorApiService(apiUrl: '$_baseUrl/api/devices/$dId/latest');
          fetchingMap[dId] = false;
          errorMap[dId] = false;
          if (!deviceIds.contains(dId)) deviceIds.add(dId);
        }
      }
      
      final List<String> blacklist = box.get('blacklisted_ids', defaultValue: <String>[]).cast<String>();
      _blacklistedIds = blacklist.toSet();
    } catch (e) {
      debugPrint('Error loading custom devices: $e');
    }
  }

  void _saveCustomDevices() {
    try {
      final box = Hive.box('sensors_box');
      box.put('discovered_ids', deviceIds);
      box.put('blacklisted_ids', _blacklistedIds.toList());
    } catch (e) {
      debugPrint('Error saving custom devices: $e');
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 25), (_) => refreshAll());
  }

  Future<void> _fetchRegistry() async {
    try {
      isFetchingDevices = true;
      notifyListeners();

      final response = await http.get(Uri.parse('$_baseUrl/api/devices')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final registry = await compute(_parseRegistryIsolate, response.body);

        deviceIps = registry;
        
        // Merge registry with existing discovered devices
        final serverIds = registry.keys.toSet();
        final currentIds = apiServices.keys.toSet();
        deviceIds = serverIds.union(currentIds).toList();

        elementIds.clear();
        soilIds.clear();
        mineralIds.clear();

        for (var dId in deviceIds) {
          final idLower = dId.toLowerCase();
          
          // Try to get type from registry first, then fallback to guesswork
          if (idLower.contains('soil')) {
            soilIds.add(dId);
          } else if (idLower.contains('min') || idLower.contains('npk') || idLower.contains('nitro') || idLower.contains('phos') || idLower.contains('pota') || idLower.startsWith('m') || idLower.contains('ec')) {
            mineralIds.add(dId);
          } else {
            elementIds.add(dId);
          }

          if (!apiServices.containsKey(dId)) {
            apiServices[dId] = SensorApiService(apiUrl: '$_baseUrl/api/devices/$dId/latest');
            fetchingMap[dId] = true;
            errorMap[dId] = false;
          }
        }

        isFetchingDevices = false;
        notifyListeners();

        await refreshAll();
        // Load 5h history as default
        final now = DateTime.now();
        await fetchGlobalHistoryByRange(
          start: now.subtract(const Duration(hours: 5)),
          end: now,
          hours: 5,
        );
      }
    } catch (e) {
      debugPrint('Error fetching registry: $e');
      isFetchingDevices = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    if (deviceIds.isEmpty) {
      await _fetchRegistry();
      if (deviceIds.isEmpty) return;
    }

    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/devices/all/latest')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final List<Map<String, dynamic>> results = await compute(_parseSnapshotsIsolate, res.body);

        final Set<String> foundInLatest = results.map((e) => e['device_id']?.toString() ?? '').toSet();
        
        // Mark ones NOT found in latest as error/offline
        for (var dId in deviceIds) {
          if (!foundInLatest.contains(dId)) {
            errorMap[dId] = true;
            fetchingMap[dId] = false;
          }
        }

        for (var item in results) {
          final String dId = item['device_id']?.toString() ?? '';
          if (dId.isEmpty) continue;

          // Check if blacklisted and has NEW data
          if (_blacklistedIds.contains(dId)) {
            final snap = SensorSnapshot.fromJson(item);
            if (DateTime.now().difference(snap.time).inSeconds <= 60) {
              _blacklistedIds.remove(dId); // Re-activate
              _saveCustomDevices();
            } else {
              continue; // Still ignored
            }
          }

          if (apiServices.containsKey(dId)) {
            final snapshot = SensorSnapshot.fromJson(item);
            apiServices[dId]!.updateFromSnapshot(snapshot);
            fetchingMap[dId] = false;
            errorMap[dId]    = false;

            final data    = (item['reading'] is Map) ? item['reading'] as Map : item;
            final idLower = dId.toLowerCase();
            final label   = data['sensor_type_label']?.toString().toLowerCase() ?? '';

            bool isMineral = false;
            bool isSoil = false;

            if (label == 'environment' || label == 'environmental') {
              // environment node
            } else if (label == 'soil') {
              isSoil = true;
            } else if (label == 'mineral') {
              isMineral = true;
            } else {
              // Fallback: Use legacy pattern matching if no label
              isMineral = idLower.contains('min') || idLower.contains('npk') || idLower.contains('nitro');
              isMineral |= data.containsKey('nitrogen') || data.containsKey('nitro') || data.containsKey('n');
              isMineral |= data.containsKey('phosphorus') || data.containsKey('phos') || data.containsKey('p');
              isMineral |= data.containsKey('potassium') || data.containsKey('pota') || data.containsKey('k');
              isMineral |= (data.containsKey('ec') && !idLower.contains('soil'));

              isSoil = idLower.contains('soil');
              isSoil |= data.containsKey('soil_moisture') || data.containsKey('soil_m') || data.containsKey('soilm');
              if (!isMineral && !isSoil) {
                if (data.containsKey('moisture') && !idLower.contains('env') && !idLower.contains('temp')) {
                  isSoil = true;
                }
              }
            }

            if (!isMineral && !isSoil) {
              if (!elementIds.contains(dId)) elementIds.add(dId);
              mineralIds.remove(dId);
              soilIds.remove(dId);
            } else if (isSoil) {
              if (!soilIds.contains(dId)) soilIds.add(dId);
              mineralIds.remove(dId);
              elementIds.remove(dId);
            } else {
              if (!mineralIds.contains(dId)) mineralIds.add(dId);
              soilIds.remove(dId);
              elementIds.remove(dId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Manager] AllLatest Error: $e');
    }

    notifyListeners();
  }

  // ── ยังคง currentHistoryHours ไว้สำหรับ every-interval logic ──
  int currentHistoryHours = 5;
  bool isFetchingHistory  = false;

  /// Fetch history ด้วย DateTimeRange ที่ผู้ใช้เลือก (max 30 วัน)
  Future<void> fetchGlobalHistoryByRange({
    required DateTime start,
    required DateTime end,
    required int hours,
  }) async {
    selectedStart          = start;
    selectedEnd            = end;
    currentHistoryHours    = hours;

    // เลือก sampling interval ตามความยาวช่วง เพื่อลดภาระ Network และ Rendering
    String every = '5m';
    if (hours >= 720) { // 30 วัน
      every = '6h';
    } else if (hours >= 168) { // 7 วัน
      every = '2h';
    } else if (hours >= 72) { // 3 วัน
      every = '1h';
    } else if (hours >= 24) { // 1 วัน
      every = '30m';
    } else {
      every = '15m'; // ช่วงสั้นๆ
    }

    try {
      isFetchingHistory = true;
      notifyListeners();

      // ใช้ endpoint /api/sensors/range เหมือนในหน้า history
      final startIso = "${start.toUtc().toIso8601String().split('.')[0]}Z";
      final endIso   = "${end.toUtc().toIso8601String().split('.')[0]}Z";
      
      final url = '$_baseUrl/api/sensors/range'
          '?start=${Uri.encodeComponent(startIso)}'
          '&end=${Uri.encodeComponent(endIso)}'
          '&every=$every';

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final Map<String, List<Map<String, dynamic>>> historyData =
            await compute(_parseGlobalHistoryIsolate, res.body);

        historyData.forEach((dId, snapshotsJson) {
          final matchedKey = apiServices.keys.firstWhere(
            (k) => k.toLowerCase() == dId.toLowerCase(),
            orElse: () => '',
          );

          final snapshots = snapshotsJson.map((j) => SensorSnapshot.fromJson(j)).toList();

          if (matchedKey.isNotEmpty) {
            apiServices[matchedKey]!.updateHistoryFromSnapshots(snapshots);
          } else {
            // Check blacklist first
            if (_blacklistedIds.contains(dId)) return;

            // Persistent Auto-Discovery: register it if not found
            final String newId = dId;
            apiServices[newId] = SensorApiService(apiUrl: '$_baseUrl/api/devices/$newId/latest');
            if (!deviceIds.contains(newId)) deviceIds.add(newId);
            fetchingMap[newId] = false;
            errorMap[newId] = false;

            apiServices[newId]!.updateHistoryFromSnapshots(snapshots);

            // Categorize by data
            if (snapshots.isNotEmpty) {
              final last = snapshots.last;
              final idLower = newId.toLowerCase();
              bool isMineral = idLower.contains('min') || idLower.contains('npk') || idLower.contains('nitro');
              isMineral |= (last.nitrogen > 0 || last.phosphorus > 0 || last.potassium > 0);
              bool isSoil = idLower.contains('soil') || (last.soilMoisture > 0);

              if (isSoil) {
                if (!soilIds.contains(newId)) soilIds.add(newId);
              } else if (isMineral) {
                if (!mineralIds.contains(newId)) mineralIds.add(newId);
              } else {
                if (!elementIds.contains(newId)) elementIds.add(newId);
              }
            }
            _saveCustomDevices();
          }
        });
      }
    } catch (e) {
      debugPrint('[Manager] GlobalHistory Error: $e');
    } finally {
      isFetchingHistory = false;
      notifyListeners();
    }
  }

  /// Reset to standard 5-hour view
  Future<void> resetToDefaultHistory() async {
    selectedStart = null;
    selectedEnd = null;
    currentHistoryHours = 5;
    await fetchGlobalHistory(hours: 5);
  }

  /// Wrapper เดิม (ใช้ hours อย่างเดียว) — ยังคงไว้เพื่อ backward compat
  Future<void> fetchGlobalHistory({int? hours}) async {
    final h   = hours ?? currentHistoryHours;
    final now = DateTime.now();
    await fetchGlobalHistoryByRange(
      start: now.subtract(Duration(hours: h)),
      end:   now,
      hours: h,
    );
  }

  Future<void> retrySingle(String dId) async {
    if (!apiServices.containsKey(dId)) return;
    fetchingMap[dId] = true;
    errorMap[dId]    = false;
    notifyListeners();

    try {
      await apiServices[dId]!.fetchLatest();
      fetchingMap[dId] = false;
      errorMap[dId]    = false;
    } catch (e) {
      fetchingMap[dId] = false;
      errorMap[dId]    = true;
    }
    notifyListeners();
  }

  void removeDevice(String dId) {
    _blacklistedIds.add(dId);
    deviceIds.remove(dId);
    elementIds.remove(dId);
    soilIds.remove(dId);
    mineralIds.remove(dId);
    apiServices.remove(dId);
    fetchingMap.remove(dId);
    errorMap.remove(dId);
    _saveCustomDevices(); // Update Hive
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// ── Background Isolates ──────────────────────────────────────────

Map<String, String> _parseRegistryIsolate(String body) {
  final decoded = jsonDecode(body);
  Map<String, String> registry = {};
  if (decoded is Map) {
    registry = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  } else if (decoded is List) {
    for (var item in decoded) {
      if (item is String) {
        registry[item] = '';
      } else if (item is Map) {
        final id = (item['id'] ?? item['device_id'])?.toString() ?? '';
        if (id.isNotEmpty) {
          registry[id] = item['ip']?.toString() ?? '';
        }
      }
    }
  }
  return registry;
}

List<Map<String, dynamic>> _parseSnapshotsIsolate(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
}

Map<String, List<Map<String, dynamic>>> _parseGlobalHistoryIsolate(String body) {
  try {
    final rawDecoded = jsonDecode(body);
    dynamic payload = rawDecoded;
    if (rawDecoded is Map) {
      payload = rawDecoded['data'] ??
          rawDecoded['history'] ??
          rawDecoded['readings'] ??
          rawDecoded;
    }

    Map<String, List<Map<String, dynamic>>> result = {};

    if (payload is Map) {
      payload.forEach((key, value) {
        final String dId = key.toString();
        if (dId == 'status' || dId == 'message' || dId == 'count') return;

        List? readings;
        if (value is List) {
          readings = value;
        } else if (value is Map) {
          readings = value['history'] ?? value['readings'] ?? value['data'];
        }
        if (readings != null) {
          result[dId] =
              readings.map((j) => Map<String, dynamic>.from(j)).toList();
        }
      });
    } else if (payload is List) {
      // ถ้าข้อมูลมาเป็น List รวม (แบบ /api/sensors/range) ให้ Group ตาม device_id
      for (final item in payload) {
        if (item is Map) {
          final dId = item['device_id']?.toString() ??
              item['id']?.toString() ??
              'unknown';
          result.putIfAbsent(dId, () => []);
          result[dId]!.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return result;
  } catch (e) {
    debugPrint('Isolate Parse Error (likely HTML response): $e');
    return {};
  }
}