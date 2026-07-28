import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Alarm model ───────────────────────────────────────────────────────────────

class AlarmItem {
  final String deviceId;
  final String alertType;
  final DateTime triggeredAt;
  final double? value;
  final double? threshold;
  final bool acknowledged;
  final String? timeElapsed;

  AlarmItem({
    required this.deviceId,
    required this.alertType,
    required this.triggeredAt,
    this.value,
    this.threshold,
    required this.acknowledged,
    this.timeElapsed,
  });

  factory AlarmItem.fromJson(Map<String, dynamic> json) {
    return AlarmItem(
      deviceId:    json['device_id'] as String,
      alertType:   json['alert_type'] as String,
      triggeredAt: DateTime.parse(json['triggered_at'] as String).toLocal(),
      value:       (json['value'] as num?)?.toDouble(),
      threshold:   (json['threshold'] as num?)?.toDouble(),
      acknowledged: json['acknowledged'] as bool? ?? false,
      timeElapsed:  json['time_elapsed'] as String?,
    );
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  String get label {
    switch (alertType) {
      case 'temp_high':  return 'อุณหภูมิสูง';
      case 'temp_low':   return 'อุณหภูมิต่ำ';
      case 'hum_high':   return 'ความชื้นสูง';
      case 'hum_low':    return 'ความชื้นต่ำ';
      case 'tvoc':       return 'TVOC สูง';
      case 'eco2':       return 'CO₂ สูง';
      default:           return alertType;
    }
  }

  String get unit {
    switch (alertType) {
      case 'temp_high':
      case 'temp_low':  return '°C';
      case 'hum_high':
      case 'hum_low':   return '%';
      case 'tvoc':      return 'ppb';
      case 'eco2':      return 'ppm';
      default:          return '';
    }
  }

  IconData get icon {
    switch (alertType) {
      case 'temp_high':
      case 'temp_low':  return Icons.thermostat_rounded;
      case 'hum_high':
      case 'hum_low':   return Icons.water_drop_rounded;
      case 'tvoc':      return Icons.air_rounded;
      case 'eco2':      return Icons.co2_rounded;
      default:          return Icons.warning_rounded;
    }
  }

  Color get color {
    switch (alertType) {
      case 'temp_high':  return const Color(0xFFD32F2F);
      case 'temp_low':   return const Color(0xFF1565C0);
      case 'hum_high':   return const Color(0xFF1976D2);
      case 'hum_low':    return const Color(0xFFF57C00);
      case 'tvoc':
      case 'eco2':       return const Color(0xFF7B1FA2);
      default:           return const Color(0xFFD32F2F);
    }
  }

  String get timeFormatted {
    final h = triggeredAt.hour.toString().padLeft(2, '0');
    final m = triggeredAt.minute.toString().padLeft(2, '0');
    final d = triggeredAt.day.toString().padLeft(2, '0');
    final mo = triggeredAt.month.toString().padLeft(2, '0');
    return '$d/$mo ${triggeredAt.year}  $h:$m น.';
  }

  bool get hasValue => value != null && threshold != null;
}

// ── Service ───────────────────────────────────────────────────────────────────

class AlarmService {
  static String get _base => '${Uri.base.origin}/api';
  static String get _thresholdBase => '${Uri.base.origin}/api';

  List<AlarmItem> activeAlarms  = [];
  List<AlarmItem> historyAlarms = [];
  bool isFetching = false;

  Future<void> fetchAll({int historyHours = 24}) async {
    isFetching = true;
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_base/alarms/active'),  headers: {'accept': 'application/json'})
            .timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('$_base/alarms/history?hours=$historyHours'), headers: {'accept': 'application/json'})
            .timeout(const Duration(seconds: 10)),
      ]);

      if (results[0].statusCode == 200) {
        final List raw = jsonDecode(results[0].body);
        activeAlarms = raw.map((j) => AlarmItem.fromJson(j)).toList()
          ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      }
      if (results[1].statusCode == 200) {
        final List raw = jsonDecode(results[1].body);
        historyAlarms = raw.map((j) => AlarmItem.fromJson(j)).toList()
          ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      }
    } catch (e) {
      debugPrint('[AlarmService] $e');
    }
    isFetching = false;
  }

  // Summary counts
  int get criticalCount => activeAlarms.where((a) =>
    a.alertType.contains('high') || a.alertType.contains('tvoc') || a.alertType.contains('eco2')).length;

  int get totalActive => activeAlarms.length;

  // Unique alert types in history
  Map<String, int> get historyByType {
    final map = <String, int>{};
    for (final a in historyAlarms.where((a) => a.hasValue)) {
      map[a.alertType] = (map[a.alertType] ?? 0) + 1;
    }
    return map;
  }

  // ── Threshold Management ──────────────────────────────────────────────────

  /// Updates the global environment thresholds using the dedicated API.
  Future<bool> updateTelemetryThresholds({
    required double tempMin,
    required double tempMax,
    required double humMin,
    required double humMax,
    required int eco2Max,
  }) async {
    try {
      final uri = Uri.parse('$_thresholdBase/thresholds/telemetry').replace(queryParameters: {
        'temperature_max': tempMax.toString(),
        'temperature_min': tempMin.toString(),
        'eco2_max': eco2Max.toString(),
        'humidity_max': humMax.toString(),
        'humidity_min': humMin.toString(),
      });

      debugPrint('[AlarmService] Updating thresholds (POST): $uri');
      
      final res = await http.post(uri).timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200) {
        debugPrint('[AlarmService] Thresholds updated successfully');
        return true;
      } else {
        debugPrint('[AlarmService] Failed to update thresholds: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[AlarmService] Error updating thresholds: $e');
      return false;
    }
  }

  /// Updates the Soil thresholds.
  Future<bool> updateSoilThresholds({
    required double ecMin,
    required double ecMax,
    required double rhMin,
    required double rhMax,
  }) async {
    try {
      final uri = Uri.parse('$_thresholdBase/thresholds/soil').replace(queryParameters: {
        'ec_max': ecMax.toString(),
        'ec_min': ecMin.toString(),
        'rh_max': rhMax.toString(),
        'rh_min': rhMin.toString(),
      });
      final res = await http.post(uri).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AlarmService] update soil thresholds error: $e');
      return false;
    }
  }

  /// Updates the Mineral (NPK) thresholds.
  Future<bool> updateMineralThresholds({
    required double ecMin,
    required double ecMax,
    required double nMin,
    required double nMax,
    required double pMin,
    required double pMax,
    required double kMin,
    required double kMax,
  }) async {
    try {
      final uri = Uri.parse('$_thresholdBase/thresholds/mineral').replace(queryParameters: {
        'ec_max': ecMax.toString(),
        'ec_min': ecMin.toString(),
        'n_max': nMax.toString(),
        'n_min': nMin.toString(),
        'p_max': pMax.toString(),
        'p_min': pMin.toString(),
        'k_max': kMax.toString(),
        'k_min': kMin.toString(),
      });
      final res = await http.post(uri).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AlarmService] update mineral thresholds error: $e');
      return false;
    }
  }

  /// Fetches the current telemetry thresholds.
  Future<Map<String, dynamic>?> fetchTelemetryThresholds() async {
    try {
      final res = await http.get(Uri.parse('$_thresholdBase/thresholds/telemetry')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) { debugPrint('[AlarmService] fetch telemetry error: $e'); }
    return null;
  }

  /// Fetches the current soil thresholds.
  Future<Map<String, dynamic>?> fetchSoilThresholds() async {
    try {
      final res = await http.get(Uri.parse('$_thresholdBase/thresholds/soil')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) { debugPrint('[AlarmService] fetch soil error: $e'); }
    return null;
  }

  /// Fetches the current mineral thresholds.
  Future<Map<String, dynamic>?> fetchMineralThresholds() async {
    try {
      final res = await http.get(Uri.parse('$_thresholdBase/thresholds/mineral')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) { debugPrint('[AlarmService] fetch mineral error: $e'); }
    return null;
  }
  /// บันทึก threshold ทั้งหมดพร้อมกัน คืนค่า map บอกว่าแต่ละตัวสำเร็จไหม
  Future<Map<String, bool>> updateAllThresholds({
    required double tempMin,
    required double tempMax,
    required double humMin,
    required double humMax,
    required int eco2Max,
    required double soilEcMin,
    required double soilEcMax,
    required double soilRhMin,
    required double soilRhMax,
    required double minEcMin,
    required double minEcMax,
    required double nMin,
    required double nMax,
    required double pMin,
    required double pMax,
    required double kMin,
    required double kMax,
  }) async {
    // Sequential — ทีละ call ไม่ให้ server overwhelmed
    bool telemetryOk = false;
    bool soilOk = false;
    bool mineralOk = false;

    try {
      telemetryOk = await updateTelemetryThresholds(
        tempMin: tempMin, tempMax: tempMax,
        humMin: humMin,   humMax: humMax,
        eco2Max: eco2Max,
      );
    } catch (e) {
      debugPrint('[updateAllThresholds] telemetry error: $e');
    }

    try {
      soilOk = await updateSoilThresholds(
        ecMin: soilEcMin, ecMax: soilEcMax,
        rhMin: soilRhMin, rhMax: soilRhMax,
      );
    } catch (e) {
      debugPrint('[updateAllThresholds] soil error: $e');
    }

    try {
      mineralOk = await updateMineralThresholds(
        ecMin: minEcMin, ecMax: minEcMax,
        nMin: nMin, nMax: nMax,
        pMin: pMin, pMax: pMax,
        kMin: kMin, kMax: kMax,
      );
    } catch (e) {
      debugPrint('[updateAllThresholds] mineral error: $e');
    }

    debugPrint('[updateAllThresholds] telemetry=$telemetryOk, soil=$soilOk, mineral=$mineralOk');

    return {
      'telemetry': telemetryOk,
      'soil':      soilOk,
      'mineral':   mineralOk,
    };
  }
}
