import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'sensor_api_service.dart';

// Import for Web
import 'export_stub.dart'
    if (dart.library.io) 'export_native.dart'
    if (dart.library.html) 'export_web.dart';

class ExportService {
  static String _getDeviceType(SensorSnapshot s) {
    // Priority: sensor_type_label from API
    final label = s.sensorTypeLabel?.toLowerCase() ?? '';
    if (label == 'environmental' || label == 'environment') return 'environmental';
    if (label == 'soil') return 'soil';
    if (label == 'mineral') return 'mineral';

    // Fallback: legacy pattern matching
    final id = s.deviceId?.toLowerCase() ?? '';
    if (id.contains('soil')) return 'soil';
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

      // Sort types: 1. environmental, 2. soil, 3. mineral
      final List<String> sortedTypes = ['environmental', 'soil', 'mineral'];
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
          if (type == 'soil') sheetName = 'Soil Sensors';
          else if (type == 'mineral') sheetName = 'Mineral Sensors';
          else sheetName = 'Environmental Sensors';
        }

        Sheet sheet = excel[sheetName];

        // Headers
        List<String> headers = ['Time'];
        if (multipleDevices) {
          headers.add('Board');
        }

        if (type == 'soil') {
          headers.addAll(['(%) RH', 'EC']);
        } else if (type == 'mineral') {
          headers.addAll(['N', 'P', 'K', 'EC']);
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

          if (type == 'soil') {
            row.add(DoubleCellValue(s.humidity != 0.0 ? s.humidity : s.soilMoisture));
            row.add(DoubleCellValue(s.ec));
          } else if (type == 'mineral') {
            row.add(DoubleCellValue(s.nitrogen));
            row.add(DoubleCellValue(s.phosphorus));
            row.add(DoubleCellValue(s.potassium));
            row.add(DoubleCellValue(s.ec));
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
