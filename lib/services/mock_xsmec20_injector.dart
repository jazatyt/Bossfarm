// DEMO DATA FEATURE — deliberate, permanent (decided 2026-10-06, not left
// on by default accidentally — see pi-integration-handoff-xs-mec20.md for
// the original temporary-scaffolding context this grew out of).
//
// Purpose: shows a realistic XS-MEC20 device (SOIL_XSM01) on the dashboard
// for client demos, before/alongside any real XS-MEC20 hardware. Every
// card rendering this device must show the demo badge from
// isDemoDevice()/demoDeviceBadge() below — never let fabricated readings
// render indistinguishably from a real sensor.
//
// To disable: flip kInjectMockXsMec20 to false (keeps the file, data, and
// badge plumbing intact for later re-enable — this is no longer meant to
// be deleted outright).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sensor_api_service.dart';
import 'sensor_data_manager.dart';

/// Controls whether the demo XS-MEC20 device appears on the dashboard.
const bool kInjectMockXsMec20 = true;

const String _mockDeviceId = 'SOIL_XSM01';

/// True if [deviceId] is the fabricated demo device, not a real sensor.
/// UI code must check this and render demoDeviceBadge() wherever it shows
/// this device's name/card, so demo data is never mistaken for live data.
bool isDemoDevice(String deviceId) => deviceId == _mockDeviceId;

/// Small "DEMO" badge — render next to a soil card's name/probe-model chip
/// whenever isDemoDevice(dId) is true.
Widget demoDeviceBadge() {
  return Container(
    margin: const EdgeInsets.only(top: 2),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.orange.shade700, width: 1),
    ),
    child: Text('DEMO',
        style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.orange.shade800)),
  );
}

// Raw "reading" payloads, copied verbatim from mock-soil-payloads.json —
// exact XS-MEC20 wire shape (moisture/temperature/ec only, no ph/n/p/k
// keys at all). Timestamps are NOT included here; they're synthesized
// fresh relative to DateTime.now() each time _buildSnapshots() runs, so
// the mock device always looks live regardless of when you open the app.
const List<Map<String, dynamic>> _mockReadings = [
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.6, "temperature": 28.9, "ec": 89.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.8, "temperature": 28.95, "ec": 90.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -63, "sensor_ok": true, "moisture": 40.01, "temperature": 29.04, "ec": 93.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 40.01, "temperature": 29.1, "ec": 93.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -61, "sensor_ok": true, "moisture": 40.01, "temperature": 29.21, "ec": 93.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 40.01, "temperature": 29.26, "ec": 93.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -63, "sensor_ok": true, "moisture": 40.01, "temperature": 29.3, "ec": 93.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.9, "temperature": 29.28, "ec": 92.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.7, "temperature": 29.24, "ec": 91.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -61, "sensor_ok": true, "moisture": 39.5, "temperature": 29.18, "ec": 90.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.3, "temperature": 29.12, "ec": 89.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -63, "sensor_ok": true, "moisture": 39.2, "temperature": 29.08, "ec": 88.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.4, "temperature": 29.05, "ec": 89.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -61, "sensor_ok": true, "moisture": 39.6, "temperature": 29.02, "ec": 90.0, "alert_moist": false, "alert_ec": false},
  {"sensor_type": 2, "sensor_type_label": "soil", "soil_model": 1, "soil_model_label": "xs_mec20", "firmware": "2.2.0", "rssi": -62, "sensor_ok": true, "moisture": 39.8, "temperature": 29.0, "ec": 91.0, "alert_moist": false, "alert_ec": false},
];

List<SensorSnapshot> _buildSnapshots() {
  final now = DateTime.now();
  final n = _mockReadings.length;
  return List.generate(n, (i) {
    final ts = now.subtract(Duration(seconds: (n - 1 - i) * 5));
    return SensorSnapshot.fromJson({
      'device_id': _mockDeviceId,
      'timestamp': ts.toUtc().toIso8601String(),
      'reading': _mockReadings[i],
    });
  });
}

void _inject(SensorDataManager manager) {
  final points = _buildSnapshots();

  manager.apiServices.putIfAbsent(
    _mockDeviceId,
    () => SensorApiService(apiUrl: 'MOCK://xs-mec20'),
  );
  manager.apiServices[_mockDeviceId]!.updateHistoryFromSnapshots(points);

  if (!manager.deviceIds.contains(_mockDeviceId)) {
    manager.deviceIds.add(_mockDeviceId);
  }
  if (!manager.soilIds.contains(_mockDeviceId)) {
    manager.soilIds.add(_mockDeviceId);
  }
  manager.fetchingMap[_mockDeviceId] = false;
  // The real backend has no SOIL_XSM01, so refreshAll() marks it an error
  // every ~25s cycle; force it back to false here and again via the
  // self-healing listener below.
  manager.errorMap[_mockDeviceId] = false;
}

/// Call once, right after SensorDataManager's real initialization.
/// No-op unless kInjectMockXsMec20 is true.
void maybeInjectMockXsMec20(SensorDataManager manager) {
  if (!kInjectMockXsMec20) return;

  _inject(manager);
  manager.addListener(() {
    if (!kInjectMockXsMec20) return;
    if (manager.errorMap[_mockDeviceId] != false ||
        !manager.soilIds.contains(_mockDeviceId)) {
      _inject(manager);
    }
  });
}
