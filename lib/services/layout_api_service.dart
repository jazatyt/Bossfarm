import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LayoutApiService {
  static String get apiUrl => '${Uri.base.origin}/farmapi';

  // Modified mapping object. Instead of flat Map<String, String>, it will return a generic Map.
  Future<Map<String, dynamic>> fetchLayout() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/get_layout_v2.php'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          final dynData = result['data'];
          if (dynData is Map) {
            return Map<String, dynamic>.from(dynData);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching layout: $e');
    }
    return {};
  }

  Future<bool> saveLayout(Map<String, dynamic> layout) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/save_layout_v2.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'layout': layout}),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['status'] == 'success';
      }
    } catch (e) {
      debugPrint('Error saving layout: $e');
    }
    return false;
  }

  // lib/services/layout_api_service.dart

  Future<String?> uploadImage(Uint8List bytes, String fileName, {String? subfolder}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload_image.php'));
      
      // Add subfolder if specified
      if (subfolder != null) {
        request.fields['subfolder'] = subfolder;
      }

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: fileName,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var result = jsonDecode(utf8.decode(responseData));
        if (result['status'] == 'success') {
          return result['image_path']; // คืนค่า Path ที่เก็บใน DB/Server มาให้
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
    return null;
  }

}
