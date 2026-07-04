import 'package:flutter/material.dart';

enum AlertSeverity { warning, critical }

class SensorAlert {
  final String deviceId;
  final String field;
  final String message;
  final double value;
  final AlertSeverity severity;
  final DateTime time;
  bool isRead;

  SensorAlert({
    required this.deviceId,
    required this.field,
    required this.message,
    required this.value,
    required this.severity,
    required this.time,
    this.isRead = false,
  });

  String get category {
    switch (field) {
      case 'temp':     return 'High Temp';
      case 'temp_low': return 'Low Temp';
      case 'hum':      return 'High Humidity';
      case 'hum_low':  return 'Low Humidity';
      case 'tvoc':     return 'High TVOC';
      case 'eco2':     return 'High CO₂';
      default:         return field;
    }

  }

  IconData get icon {
    switch (field) {
      case 'temp':
      case 'temp_low': return Icons.thermostat_rounded;
      case 'hum':
      case 'hum_low':  return Icons.water_drop_rounded;
      case 'tvoc':     return Icons.air_rounded;
      case 'eco2':     return Icons.co2_rounded;
      default:         return Icons.warning_rounded;
    }
  }

  Color get color => severity == AlertSeverity.critical
      ? const Color(0xFFD32F2F)
      : const Color(0xFFF57C00);
}
