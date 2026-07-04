import 'package:http/http.dart' as http;

class InfluxService {
  final String token =
      'VwUbP4LzvgmLFywvBtcb3AXcCzYV8GodaTTEjINHVGiygPAheul1zACig2vCNoLp8P79P9mPgkTOtEvJs6X8Pw==';
  final String org = 'myorg';
  final String bucket = 'esp32_sensors';
  final String baseUrl = 'http://100.70.171.1:8086';

  List<String>? _cachedDeviceIds;

  /// Fetch all unique device_ids จาก tag values โดยตรง (ไม่ใช้ distinct)
  Future<List<String>> fetchMeasurements() async {
    final fluxQuery = 'import "influxdata/influxdb/schema" schema.measurements(bucket: "$bucket")';
    final data = await query(fluxQuery);
    return data.map((row) => row['_value']?.toString() ?? '').where((m) => m.isNotEmpty).toList();
  }

  Future<List<String>> fetchDeviceIds() async {
    if (_cachedDeviceIds != null) return _cachedDeviceIds!;

    final fluxQuery = '''
      import "influxdata/influxdb/schema"
      schema.tagValues(
        bucket: "$bucket",
        tag: "device_id",
        predicate: (r) => r["_measurement"] == "IESWIC3A",
        start: -1h
      )
    ''';

    final data = await query(fluxQuery);

    _cachedDeviceIds = data
        .map((row) => row['_value']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    print('Found device IDs: $_cachedDeviceIds');
    return _cachedDeviceIds!;
  }

  void clearDeviceCache() => _cachedDeviceIds = null;

  Future<String> _buildCommonFilters() async {
    final deviceIds = await fetchDeviceIds();

    if (deviceIds.isEmpty) {
      return '|> filter(fn: (r) => r["_measurement"] == "IESWIC3A")';
    }

    final deviceFilter =
        deviceIds.map((id) => 'r["device_id"] == "$id"').join(' or ');

    return '''
    |> filter(fn: (r) => r["_measurement"] == "IESWIC3A")
    |> filter(fn: (r) => $deviceFilter)
  ''';
  }

  Future<Map<String, double>> fetchLatestMetrics({String range = '-1h'}) async {
    final filters = await _buildCommonFilters();

    final fluxQuery = '''
      from(bucket: "$bucket")
        |> range(start: $range)
        $filters
        |> last()
    ''';

    final data = await query(fluxQuery);

    Map<String, List<double>> fieldValues = {};

    for (var row in data) {
      final field = row['_field']?.toString();
      final value = row['_value'];

      // ✅ แก้: รับทั้ง double, int, num และ String ป้องกัน null/type crash
      if (field != null && field.isNotEmpty && value != null) {
        final doubleVal = (value is num)
            ? value.toDouble()
            : double.tryParse(value.toString());
        if (doubleVal != null) {
          fieldValues.putIfAbsent(field, () => []).add(doubleVal);
        }
      }
    }

    return {
      for (var entry in fieldValues.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length
    };
  }

  Future<List<Map<String, dynamic>>> fetchTimeSeries(
    String field, {
    String range = '-1h',
  }) async {
    final filters = await _buildCommonFilters();

    String aggregate = '';

    final fluxQuery = '''
      from(bucket: "$bucket")
        |> range(start: $range)
        $filters
        |> filter(fn: (r) => r["_field"] == "$field")
        $aggregate
        |> yield(name: "mean")
        |> keep(columns: ["_time", "_value"])
    ''';

    final result = await query(fluxQuery);

    // ✅ แก้: กรองแถวที่ _value เป็น null ออก ป้องกัน Chart crash
    return result.where((row) => row['_value'] != null).toList();
  }

  // ── Soil Data ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchSoilEc({String range = '-1h'}) async {
    String aggregate = _getAggregation(range);
    final fluxQuery = '''
      from(bucket: "$bucket")
        |> range(start: $range)
        |> filter(fn: (r) => r["_measurement"] == "SoilData")
        |> filter(fn: (r) => r["_field"] == "ec")
        $aggregate
        |> keep(columns: ["_time", "_value"])
    ''';
    return await query(fluxQuery);
  }

  Future<List<Map<String, dynamic>>> fetchSoilRh({String range = '-1h'}) async {
    String aggregate = _getAggregation(range);
    final fluxQuery = '''
      from(bucket: "$bucket")
        |> range(start: $range)
        |> filter(fn: (r) => r["_measurement"] == "SoilData")
        |> filter(fn: (r) => r["_field"] == "moisture")
        $aggregate
        |> keep(columns: ["_time", "_value"])
    ''';
    return await query(fluxQuery);
  }

  Future<Map<String, double>> fetchSoilMineral({String range = '-1h'}) async {
    final fluxQuery = '''
      from(bucket: "$bucket")
        |> range(start: $range)
        |> filter(fn: (r) => r["_measurement"] == "SoilData")
        |> filter(fn: (r) => r["_field"] == "nitrogen" or r["_field"] == "phosphorus" or r["_field"] == "potassium")
        |> last()
    ''';
    final data = await query(fluxQuery);
    Map<String, double> res = {'nitrogen': 0, 'phosphorus': 0, 'potassium': 0};
    for (var row in data) {
      final f = row['_field'];
      final v = row['_value'];
      if (f != null && v is num) res[f] = v.toDouble();
    }
    return res;
  }

  String _getAggregation(String range) => '';

  Future<List<Map<String, dynamic>>> query(String fluxQuery) async {
    final url = Uri.parse('$baseUrl/api/v2/query?org=$org');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/vnd.flux',
          'Accept': 'application/csv',
        },
        body: fluxQuery,
      );

      if (response.statusCode == 200) {
        return _parseInfluxCSV(response.body);
      } else {
        print('InfluxDB Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error querying InfluxDB: $e');
      return [];
    }
  }

  /// Fetch all data (temp, humid, light) for all farms
  Future<List<Map<String, dynamic>>> fetchGroupedFarmsData({String range = '-1h', int targetCount = 6}) async {
    final farmDataMap = await fetchAllFarmsData(range: range);
    List<String> deviceIds = farmDataMap.keys.toList()..sort();
    
    List<Map<String, dynamic>> groupedFarms = [];
    
    // Group Every 2 Sensors into 1 Farm
    for (int i = 0; i < deviceIds.length; i += 2) {
      int farmIndex = (i ~/ 2) + 1;
      List<Map<String, dynamic>> sensorsInFarm = [];
      
      // Add first sensor
      sensorsInFarm.add(farmDataMap[deviceIds[i]]!);
      
      // Add second sensor if exists
      if (i + 1 < deviceIds.length) {
        sensorsInFarm.add(farmDataMap[deviceIds[i + 1]]!);
      }
      
      // Calculate Averages for Trends
      List<dynamic> avgTempTrend = _averageTrends(sensorsInFarm.map((s) => s['temp_trend'] as List<dynamic>).toList());
      List<dynamic> avgHumidTrend = _averageTrends(sensorsInFarm.map((s) => s['humid_trend'] as List<dynamic>).toList());
      List<dynamic> avgEco2Trend = _averageTrends(sensorsInFarm.map((s) => s['eco2_trend'] as List<dynamic>).toList());
      
      groupedFarms.add({
        'title': 'Farm $farmIndex',
        'sensors': sensorsInFarm,
        'averaged_temp_trend': avgTempTrend,
        'averaged_humid_trend': avgHumidTrend,
        'averaged_eco2_trend': avgEco2Trend,
      });
    }

    // Fill with placeholders up to targetCount
    while (groupedFarms.length < targetCount) {
      groupedFarms.add({
        'title': 'Farm ${groupedFarms.length + 1}',
        'sensors': [],
        'averaged_temp_trend': [],
        'averaged_humid_trend': [],
      });
    }
    
    return groupedFarms;
  }

  List<dynamic> _averageTrends(List<List<dynamic>> trends) {
    // Filter out empty trends
    List<List<dynamic>> validTrends = trends.where((t) => t.isNotEmpty).toList();
    
    if (validTrends.isEmpty) return [];
    if (validTrends.length == 1) return validTrends[0];
    
    // Find the longest trend to ensure we show as much data as possible
    int maxLength = validTrends.map((t) => t.length).reduce((a, b) => a > b ? a : b);
    
    List<dynamic> averages = [];
    for (int i = 0; i < maxLength; i++) {
      double sum = 0;
      int count = 0;
      dynamic timeRef;

      for (var trend in validTrends) {
        if (i < trend.length) {
          final val = trend[i]['_value'];
          if (val is num) {
            sum += val.toDouble();
            count++;
            timeRef ??= trend[i]['_time'];
          }
        }
      }

      if (count > 0) {
        averages.add({
          '_time': timeRef,
          '_value': sum / count,
        });
      }
    }
    return averages;
  }

  Future<Map<String, Map<String, dynamic>>> fetchAllFarmsData({String range = '-1h'}) async {
    String aggregate = _getAggregation(range);
    final fluxQuery = '''
      from(bucket: "$bucket")
        |> range(start: $range)
        |> filter(fn: (r) => r["_measurement"] == "IESWIC3A")
        |> filter(fn: (r) => r["_field"] == "temperature" or r["_field"] == "humidity" or r["_field"] == "light" or r["_field"] == "eco2")
        $aggregate
        |> yield(name: "all_data")
    ''';

    final data = await query(fluxQuery);
    
    // Group by device_id และ กรองค่าที่เป็น null
    Map<String, Map<String, dynamic>> farmData = {};

    for (var row in data) {
      if (row['_value'] == null) continue; // ข้ามข้อมูลเสียหรือบรรทัดหัวข้อที่หลุดมา

      final deviceId = row['device_id']?.toString() ?? 'unknown';
      final field = row['_field']?.toString() ?? '';
      final value = row['_value'];
      final time = row['_time'];

      if (!farmData.containsKey(deviceId)) {
        farmData[deviceId] = {
          'device_id': deviceId,
          'temp_trend': [],
          'humid_trend': [],
          'eco2_trend': [],
          'last_light': 0.0,
        };
      }

      if (field == 'temperature') {
        farmData[deviceId]!['temp_trend'].add({'_time': time, '_value': value});
      } else if (field == 'humidity') {
        farmData[deviceId]!['humid_trend'].add({'_time': time, '_value': value});
      } else if (field == 'eco2') {
        farmData[deviceId]!['eco2_trend'].add({'_time': time, '_value': value});
      } else if (field == 'light') {
        farmData[deviceId]!['last_light'] = value;
      }
    }

    return farmData;
  }

  Future<Map<String, int>> fetchSensorCounts() async {
    // Environment count from IESWIC3A
    final envQuery = 'from(bucket: "$bucket") |> range(start: -1h) |> filter(fn: (r) => r["_measurement"] == "IESWIC3A") |> keep(columns: ["device_id"]) |> unique(column: "device_id") |> count(column: "device_id")';
    
    // Soil count
    final soilQuery = 'from(bucket: "$bucket") |> range(start: -1h) |> filter(fn: (r) => r["_measurement"] == "SoilData" or r["_field"] == "moisture") |> keep(columns: ["device_id"]) |> unique(column: "device_id") |> count(column: "device_id")';
    
    // Manual count
    final manualQuery = 'from(bucket: "$bucket") |> range(start: -1h) |> filter(fn: (r) => r["_measurement"] == "ManualControl" or r["_field"] == "relay") |> keep(columns: ["device_id"]) |> unique(column: "device_id") |> count(column: "device_id")';

    // ดึงข้อมูลแบบขนาน
    final results = await Future.wait([
      query(envQuery),
      query(soilQuery),
      query(manualQuery),
    ]);

    final envData = results[0];
    final soilData = results[1];
    final manualData = results[2];

    int countEnv = envData.isNotEmpty ? ((envData.first['_value'] as num?)?.toInt() ?? 0) : 0;
    int countSoil = soilData.isNotEmpty ? ((soilData.first['_value'] as num?)?.toInt() ?? 0) : 0;
    int countManual = manualData.isNotEmpty ? ((manualData.first['_value'] as num?)?.toInt() ?? 0) : 0;

    return {
      'Soil': countSoil,
      'Environment': countEnv,
      'Manual': countManual,
    };
  }

  List<Map<String, dynamic>> _parseInfluxCSV(String csv) {
    if (csv.trim().isEmpty) return [];

    List<Map<String, dynamic>> results = [];
    List<String> lines = csv.split('\n');
    List<String>? headers;

    for (String line in lines) {
      line = line.trim();
      
      // เมื่อเจอบรรทัดว่าง ให้รีเซ็ต headers เพราะอาจจะเป็นตารางใหม่
      if (line.isEmpty) {
        headers = null;
        continue;
      }
      
      // ข้ามบรรทัด Annotation (#)
      if (line.startsWith('#')) continue;

      List<String> parts = _splitCsvLine(line);

      // ตั้งค่าหัวข้อถ้ายังไม่มี
      if (headers == null) {
        headers = parts;
        continue;
      }

      // ข้ามบรรทัดถ้ามันคือหัวข้อซ้ำ (เช่นกรณีหลายตารางแต่หัวข้อเหมือนเดิม)
      if (parts.first == headers.first && parts.length == headers.length && parts.contains('_value')) {
        continue;
      }

      if (parts.length >= headers.length) {
        Map<String, dynamic> row = {};
        bool hasValue = false;
        
        for (int i = 0; i < headers.length; i++) {
          final key = headers[i].trim();
          if (key.isEmpty) continue; // ข้ามคอลัมน์ที่ไม่มีชื่อ
          
          final value = i < parts.length ? parts[i].trim() : '';

          if (key == '_value') {
            final doubleVal = double.tryParse(value);
            row[key] = doubleVal;
            if (doubleVal != null) hasValue = true;
          } else {
            row[key] = value;
          }
        }
        
        // เก็บเฉพาะแถวที่มีข้อมูลจริง หรือไม่มีคอลัมน์ _value
        if (!headers.contains('_value') || row['_value'] != null) {
          results.add(row);
        }
      }
    }

    return results;
  }

  List<String> _splitCsvLine(String line) => line.split(',');
}