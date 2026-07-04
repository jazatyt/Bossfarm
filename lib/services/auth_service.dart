import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'layout_api_service.dart';


class AuthService {
  static const String baseUrl = 'http://localhost/farmapi';

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        final role = result['user']?['role']?.toString().toLowerCase();
        final expiryDate = result['user']?['expiry_date']?.toString();
        _saveLoginState(true, username, role, expiryDate);
      }
      return result;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  void _saveLoginState(bool isLoggedIn, String? username, String? role, String? expiryDate) {
    final box = Hive.box('auth_box');
    box.put('isLoggedIn', isLoggedIn);
    if (username != null) box.put('username', username);
    if (role != null) box.put('role', role);
    if (expiryDate != null) box.put('expiry_date', expiryDate);
  }

  static void logout() {
    final box = Hive.box('auth_box');
    box.put('isLoggedIn', false);
    box.delete('username');
    box.delete('role');
    box.delete('expiry_date');
  }

  String? get currentUsername => Hive.box('auth_box').get('username');
  String get currentRole => Hive.box('auth_box').get('role', defaultValue: 'user');
  String? get currentExpiryDate => Hive.box('auth_box').get('expiry_date');

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String role = 'user',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'role': role,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<List<dynamic>> getUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_users.php'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          return result['users'] ?? [];
        }
      }
    } catch (e) {
      print('Error getting users: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> deleteUser(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserRole(String username, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_user_role.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'role': role}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ✅ อันนี้อันเดียว — ลบอันเก่าออกแล้ว
  Future<Map<String, dynamic>> updateUserExpiry(String username, int days) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_user_expiry.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'days': days}),
      );

      final raw = response.body.trim();

      print('[updateUserExpiry] STATUS: ${response.statusCode}');
      print('[updateUserExpiry] BODY: "$raw"');

      if (raw.isEmpty) {
        return {'status': 'error', 'message': 'Server ไม่ส่งข้อมูลกลับมา (empty response)'};
      }

      if (!raw.startsWith('{')) {
        return {'status': 'error', 'message': 'Response ไม่ใช่ JSON: $raw'};
      }

      return jsonDecode(raw);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  String get logoUrl {
    final cached = Hive.box('auth_box').get('custom_logo_url');
    if (cached != null) {
      final String url = cached.toString();
      return url.contains('?')
          ? '$url&v=${DateTime.now().millisecondsSinceEpoch}'
          : '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$baseUrl/uploads/logo.png?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  void updateLogoUrl(String url) {
    Hive.box('auth_box').put('custom_logo_url', url);
  }

  Future<void> syncLogoFromServer() async {
    try {
      final layoutApi = LayoutApiService();
      final layout = await layoutApi.fetchLayout();
      if (layout.containsKey('logoUrl') && layout['logoUrl'] != null) {
        final String url = layout['logoUrl'].toString();
        if (url.isNotEmpty) {
          updateLogoUrl(url);
        }
      }
    } catch (e) {
      print('Error syncing logo: $e');
    }
  }
}