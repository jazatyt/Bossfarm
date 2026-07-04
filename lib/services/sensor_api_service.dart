import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DeviceThresholds {
  final double tempHigh;
  final double tempLow;
  final double humHigh;
  final double humLow;
  final int tvoc;
  final int eco2;

  DeviceThresholds.fromJson(Map<String, dynamic> json)
    : tempHigh = (json['temp']     as num).toDouble(),
      tempLow  = (json['temp_low'] as num).toDouble(),
      humHigh  = (json['hum']      as num).toDouble(),
      humLow   = (json['hum_low']  as num).toDouble(),
      tvoc     = (json['tvoc']     as num).toInt(),
      eco2     = (json['eco2']     as num).toInt();
}

/// ข้อมูล 1 snapshot จาก API /sensors/latest
class SensorSnapshot {
  final DateTime time;
  final double temperature;
  final double humidity;
  final int aqi;
  final int eco2;
  final bool lightOn;
  // Soil & Mineral fields
  final double ec;
  final double soilMoisture;
  final double nitrogen;
  final double phosphorus;
  final double potassium;

  final String? deviceId;
  final int? sensorType;
  final String? sensorTypeLabel;

  SensorSnapshot({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.aqi,
    required this.eco2,
    required this.lightOn,
    this.ec = 0.0,
    this.soilMoisture = 0.0,
    this.nitrogen = 0.0,
    this.phosphorus = 0.0,
    this.potassium = 0.0,
    this.deviceId,
    this.sensorType,
    this.sensorTypeLabel,
  });

  static DateTime _parseDateTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return DateTime.now();
    if (!timeStr.endsWith('Z') && !timeStr.contains('+') && !timeStr.contains('-') && timeStr.contains('T')) {
      timeStr += 'Z';
    } else if (!timeStr.contains('T') && !timeStr.contains('Z') && !timeStr.contains('+')) {
      timeStr = timeStr.replaceAll(' ', 'T') + 'Z';
    }
    return DateTime.tryParse(timeStr)?.toLocal() ?? DateTime.now();
  }

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = (json['reading'] is Map) 
        ? json['reading'] as Map<String, dynamic> 
        : json;

    return SensorSnapshot(
      time:        _parseDateTime((json['timestamp'] ?? json['time'])?.toString()),
      temperature: (data['temperature'] as num?)?.toDouble() ?? (data['temp'] as num?)?.toDouble() ?? 0.0,
      humidity:    (data['humidity'] as num?)?.toDouble() ?? (data['rh'] as num?)?.toDouble() ?? (data['moisture'] as num?)?.toDouble() ?? 0.0,
      aqi:         (data['aqi'] as num?)?.toInt() ?? 0,
      eco2:        (data['eco2'] as num?)?.toInt() ?? 0,
      lightOn:     data['light_on'] == true || json['light_on'] == true,
      ec:          (data['ec'] as num?)?.toDouble() ?? 0.0,
      soilMoisture: (data['soil_moisture'] as num?)?.toDouble() ?? (data['moisture'] as num?)?.toDouble() ?? 0.0,
      nitrogen:    (data['nitrogen'] as num?)?.toDouble() ?? (data['nitro'] as num?)?.toDouble() ?? (data['n'] as num?)?.toDouble() ?? 0.0,
      phosphorus:  (data['phosphorus'] as num?)?.toDouble() ?? (data['phos'] as num?)?.toDouble() ?? (data['p'] as num?)?.toDouble() ?? 0.0,
      potassium:   (data['potassium'] as num?)?.toDouble() ?? (data['pota'] as num?)?.toDouble() ?? (data['k'] as num?)?.toDouble() ?? 0.0,
      deviceId:    (json['device_id'] ?? json['id'])?.toString(),
      sensorType: (data['sensor_type'] as num?)?.toInt(),
      sensorTypeLabel: data['sensor_type_label']?.toString(),
    );
  }
}

/// Service สำหรับดึงข้อมูลจาก REST API เซนเซอร์
class SensorApiService {
  final String apiUrl;
  static const _maxHistory = 1000; 

  final List<Map<String, dynamic>> tempHistory = [];
  final List<Map<String, dynamic>> humidHistory = [];
  final List<Map<String, dynamic>> eco2History = [];
  final List<Map<String, dynamic>> ecHistory = [];
  final List<Map<String, dynamic>> moistureHistory = [];
  final List<Map<String, dynamic>> nitrogenHistory = [];
  final List<Map<String, dynamic>> phosphorusHistory = [];
  final List<Map<String, dynamic>> potassiumHistory = [];
  
  SensorSnapshot? _latest;
  DeviceThresholds? thresholds;

  int get count => tempHistory.length;
  SensorSnapshot? get latest => _latest;

  SensorApiService({required this.apiUrl});

  Future<void> fetchThresholds() async {
    try {
      final url = apiUrl.replaceAll('/latest', '/thresholds_from_device');
      final res = await http.get(Uri.parse(url),
          headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        thresholds = DeviceThresholds.fromJson(json['thresholds']);
      }
    } catch (e) {
      debugPrint('[Thresholds] $apiUrl → $e');
    }
  }

  /// ดึงข้อมูลล่าสุดและเพิ่มเข้า history
  Future<SensorSnapshot?> fetchLatest() async {
    try {
      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: {'accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> json;
        if (decoded is List) {
          if (decoded.isEmpty) return null;
          json = Map<String, dynamic>.from(decoded.first);
        } else if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        } else {
          return null;
        }

        final snapshot = SensorSnapshot.fromJson(json);
        updateFromSnapshot(snapshot);
        return snapshot;
      }
    } catch (e) {
      debugPrint('[SensorApiService] Error: $e');
    }
    return null;
  }

  void updateFromSnapshot(SensorSnapshot snapshot) {
    _latest = snapshot;
    final ts = snapshot.time.toIso8601String();
    
    if (tempHistory.isNotEmpty && tempHistory.last['_time'] == ts) return;

    tempHistory.add({'_time': ts, '_value': snapshot.temperature});
    humidHistory.add({'_time': ts, '_value': snapshot.humidity});
    eco2History.add({'_time': ts, '_value': snapshot.eco2});
    ecHistory.add({'_time': ts, '_value': snapshot.ec});
    moistureHistory.add({'_time': ts, '_value': snapshot.soilMoisture});
    nitrogenHistory.add({'_time': ts, '_value': snapshot.nitrogen});
    phosphorusHistory.add({'_time': ts, '_value': snapshot.phosphorus});
    potassiumHistory.add({'_time': ts, '_value': snapshot.potassium});

    if (tempHistory.length > _maxHistory) {
      tempHistory.removeAt(0);
      humidHistory.removeAt(0);
      eco2History.removeAt(0);
      ecHistory.removeAt(0);
      moistureHistory.removeAt(0);
      nitrogenHistory.removeAt(0);
      phosphorusHistory.removeAt(0);
      potassiumHistory.removeAt(0);
    }
  }

  int _rangeToHours(String range) {
    if (range == '1h' || range == '-10m' || range == '-1h') return 1;
    if (range == '10h') return 10;
    if (range == '24h') return 24;
    if (range == '10d') return 240;
    if (range == '30d') return 720;
    if (range == '90d') return 2160;
    return 1; // Default to 1 hour
  }

  /// ดึงข้อมูลย้อนหลังตามช่วงเวลา
  Future<void> fetchHistory(String range) async {
    final hours = _rangeToHours(range);
    if (hours == 0) return;
    await fetchHistoryByHours(hours);
  }

  Future<void> fetchHistoryByHours(int hours) async {
    try {
      final baseUrl = apiUrl.replaceFirst('/latest', '');
      final uri = Uri.parse('$baseUrl/history?hours=$hours');
      
      final response = await http.get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        
        tempHistory.clear();
        humidHistory.clear();
        eco2History.clear();
        ecHistory.clear();
        moistureHistory.clear();
        nitrogenHistory.clear();
        phosphorusHistory.clear();
        potassiumHistory.clear();

        for (final item in data) {
          final hs = SensorSnapshot.fromJson(item);
          final ts = (item['timestamp'] ?? item['time'] ?? '').toString();
          tempHistory.add({'_time': ts, '_value': hs.temperature});
          humidHistory.add({'_time': ts, '_value': hs.humidity});
          eco2History.add({'_time': ts, '_value': hs.eco2});
          ecHistory.add({'_time': ts, '_value': hs.ec});
          moistureHistory.add({'_time': ts, '_value': hs.soilMoisture});
          nitrogenHistory.add({'_time': ts, '_value': hs.nitrogen});
          phosphorusHistory.add({'_time': ts, '_value': hs.phosphorus});
          potassiumHistory.add({'_time': ts, '_value': hs.potassium});
        }
      }
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
  }

  Future<List<SensorSnapshot>> fetchHistorySnapshots(int hours) async {
    try {
      final baseUrl = apiUrl.replaceFirst('/latest', '');
      final uri = Uri.parse('$baseUrl/history?hours=$hours');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((j) => SensorSnapshot.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('[HistoryData] $e');
    }
    return [];
  }

  void clearHistory() {
    tempHistory.clear();
    humidHistory.clear();
    eco2History.clear();
    ecHistory.clear();
    moistureHistory.clear();
    nitrogenHistory.clear();
    phosphorusHistory.clear();
    potassiumHistory.clear();
  }

  /// อัพเดท history จาก batch API (แทน fetchHistoryByHours)
  void updateHistoryFromSnapshots(List<SensorSnapshot> snapshots) {
    tempHistory.clear();
    humidHistory.clear();
    eco2History.clear();
    ecHistory.clear();
    moistureHistory.clear();
    nitrogenHistory.clear();
    phosphorusHistory.clear();
    potassiumHistory.clear();

    for (final s in snapshots) {
      final ts = s.time.toIso8601String();
      tempHistory.add({'_time': ts, '_value': s.temperature});
      humidHistory.add({'_time': ts, '_value': s.humidity});
      eco2History.add({'_time': ts, '_value': s.eco2});
      ecHistory.add({'_time': ts, '_value': s.ec});
      moistureHistory.add({'_time': ts, '_value': s.soilMoisture});
      nitrogenHistory.add({'_time': ts, '_value': s.nitrogen});
      phosphorusHistory.add({'_time': ts, '_value': s.phosphorus});
      potassiumHistory.add({'_time': ts, '_value': s.potassium});
    }

    // อัพเดท latest จาก snapshot ล่าสุด
    if (snapshots.isNotEmpty) {
      _latest = snapshots.last;
    }
  }
}
