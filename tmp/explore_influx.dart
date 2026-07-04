import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final String token = 'ful6bqZ5uAUXVCi-iHh7I-oj9v2GWsyJ9Hy1AUvO2iKd6Zj67jrSyS0DEhfwkwOj0Nb2Lfn8T9FkmSc5BbWHfg==';
  final String org = 'myorg';
  final String bucket = 'esp32_sensors';
  final String baseUrl = 'http://192.168.0.218:8086';

  final fluxQuery = 'import "influxdata/influxdb/schema" schema.measurementFieldKeys(bucket: "$bucket", measurement: "SoilData")';
  
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

    print('Response status: ${response.statusCode}');
    print('Response body:\n${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
