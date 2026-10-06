import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'sensor_api_service.dart';

// Import for Web
import 'export_stub.dart'
    if (dart.library.io) 'export_native.dart'
    if (dart.library.html) 'export_web.dart';

class ExportService {
  // Soil splits further into 'soil_halisense' / 'soil_xsmec20' since the
  // two probes publish genuinely different field sets (XS-MEC20 has no
  // pH/N/P/K) — each needs its own sheet with matching columns.
  static String _getDeviceType(SensorSnapshot s) {
    // Priority: sensor_type_label from API
    final label = s.sensorTypeLabel?.toLowerCase() ?? '';
    if (label == 'environmental' || label == 'environment') return 'environmental';
    if (label == 'soil') return s.soilModel == 1 ? 'soil_xsmec20' : 'soil_halisense';
    if (label == 'mineral') return 'mineral';

    // Fallback: legacy pattern matching
    final id = s.deviceId?.toLowerCase() ?? '';
    if (id.contains('soil')) return s.soilModel == 1 ? 'soil_xsmec20' : 'soil_halisense';
    if (id.contains('min') || id.contains('npk') || id.contains('nitro'))
      return 'mineral';
    return 'environmental';
  }

  static Future<void> exportToExcel({
    required List<SensorSnapshot> data,
    required String deviceId,
    required dynamic context,
    Map<String, String>? deviceDisplayNames,
  }) async {
    try {
      if (data.isEmpty) return;

      var excel = Excel.createExcel();
      // excel.delete('Sheet1'); // Will delete after content is added to avoid auto-recreation

      // Group data by actual device type
      final Map<String, List<SensorSnapshot>> typeGroups = {};
      for (var s in data) {
        final type = _getDeviceType(s);
        typeGroups.putIfAbsent(type, () => []).add(s);
      }

      // Sort types: 1. environmental, 2. soil (Halisense, then XS-MEC20), 3. mineral
      final List<String> sortedTypes = ['environmental', 'soil_halisense', 'soil_xsmec20', 'mineral'];
      final List<String> availableSortedTypes = sortedTypes.where((t) => typeGroups.containsKey(t)).toList();
      // Add any other types if they exist
      for (var t in typeGroups.keys) {
        if (!availableSortedTypes.contains(t)) availableSortedTypes.add(t);
      }

      final bool multipleTypes = typeGroups.length > 1;
      final bool multipleDevices = deviceId == 'All' || deviceId.contains(',');

      for (var type in availableSortedTypes) {
        final List<SensorSnapshot> groupData = typeGroups[type]!;

        String sheetName = 'Sensor History';
        if (multipleTypes) {
          if (type == 'soil_halisense') sheetName = 'Soil Sensors (Halisense)';
          else if (type == 'soil_xsmec20') sheetName = 'Soil Sensors (XS-MEC20)';
          else if (type == 'mineral') sheetName = 'Mineral Sensors';
          else sheetName = 'Environmental Sensors';
        }

        Sheet sheet = excel[sheetName];

        // Headers
        List<String> headers = ['Time'];
        if (multipleDevices) {
          headers.add('Board');
        }

        if (type == 'soil_halisense') {
          headers.addAll(['Temp (°C)', 'Moisture (%)', 'EC', 'pH', 'N', 'P', 'K']);
        } else if (type == 'soil_xsmec20') {
          headers.addAll(['Temp (°C)', 'Moisture (%)', 'EC']);
        } else if (type == 'mineral') {
          headers.addAll(['EC', 'pH', 'Temp (°C)']);
        } else {
          headers.addAll(['Temp (°C)', '(%) RH', 'CO2 (ppm)', 'Lights']);
        }

        sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

        // Data Rows
        for (var s in groupData) {
          List<CellValue> row = [
            TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(s.time))
          ];

          if (multipleDevices) {
            final id = s.deviceId ?? 'Unknown';
            row.add(TextCellValue(deviceDisplayNames?[id] ?? id));
          }

          if (type == 'soil_halisense') {
            row.add(DoubleCellValue(s.temperature));
            row.add(DoubleCellValue(s.soilMoisture));
            row.add(DoubleCellValue(s.ec));
            row.add(DoubleCellValue(s.ph));
            row.add(DoubleCellValue(s.nitrogen));
            row.add(DoubleCellValue(s.phosphorus));
            row.add(DoubleCellValue(s.potassium));
          } else if (type == 'soil_xsmec20') {
            row.add(DoubleCellValue(s.temperature));
            row.add(DoubleCellValue(s.soilMoisture));
            row.add(DoubleCellValue(s.ec));
          } else if (type == 'mineral') {
            row.add(DoubleCellValue(s.ec));
            row.add(DoubleCellValue(s.ph));
            row.add(DoubleCellValue(s.temperature));
          } else {
            row.add(DoubleCellValue(s.temperature));
            row.add(DoubleCellValue(s.humidity));
            row.add(IntCellValue(s.eco2));
            row.add(TextCellValue(s.lightOn ? 'ON' : 'OFF'));
          }
          sheet.appendRow(row);
        }
      }
      
      // Delete default sheet if it exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final String fileName = "SensorHistory_${deviceId.replaceAll(',', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx";
      final bytes = excel.encode();
      if (bytes == null) return;

      // Delegate to platform-specific implementation
      await saveFile(bytes, fileName, context);
    } catch (e) {
      debugPrint('Export Service Error: $e');
    }
  }
}
