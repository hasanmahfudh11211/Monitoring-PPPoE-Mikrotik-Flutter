import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'config_service.dart';

class LogService {
  // Actions constants
  static const String ACTION_LOGIN = 'LOGIN';
  static const String ACTION_LOGOUT = 'LOGOUT';
  static const String ACTION_ADD_USER = 'ADD_USER';
  static const String ACTION_EDIT_USER = 'EDIT_USER';
  static const String ACTION_DELETE_USER = 'DELETE_USER';
  static const String ACTION_ADD_PAYMENT = 'ADD_PAYMENT';
  static const String ACTION_EDIT_PAYMENT = 'EDIT_PAYMENT';
  static const String ACTION_DELETE_PAYMENT = 'DELETE_PAYMENT';
  static const String ACTION_ADD_PROFILE = 'ADD_PROFILE';
  static const String ACTION_EDIT_PROFILE = 'EDIT_PROFILE';
  static const String ACTION_SYNC_PPP = 'SYNC_PPP';
  static const String ACTION_DELETE_PROFILE = 'DELETE_PROFILE';
  static const String ACTION_ADD_ODP = 'ADD_ODP';
  static const String ACTION_EDIT_ODP = 'EDIT_ODP';
  static const String ACTION_DELETE_ODP = 'DELETE_ODP';

  /// Mencatat aktivitas ke server (Fire and Forget)
  /// Tidak melempar exception agar tidak mengganggu flow utama aplikasi
  static Future<void> logActivity({
    required String username,
    required String action,
    required String routerId,
    String details = '',
  }) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final url = Uri.parse('$baseUrl/log_activity.php');

      // Fire and forget - kita tidak await response body
      // tapi kita await requestnya terkirim
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'action': action,
              'router_id': routerId,
              'details': details,
            }),
          )
          .timeout(const Duration(seconds: 5)); // Timeout cepat

      if (kDebugMode) {
        print('[LogService] Logged: $action by $username');
      }
    } catch (e) {
      // Silent fail - log error di console debug saja
      if (kDebugMode) {
        print('[LogService] Failed to log activity: $e');
      }
    }
  }

  /// Mengambil daftar log sistem
  static Future<List<Map<String, dynamic>>> getSystemLogs({
    required String routerId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final uri =
          Uri.parse('$baseUrl/get_system_logs.php').replace(queryParameters: {
        'router_id': routerId,
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['error'] ?? 'Gagal memuat log');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gagal memuat log: $e');
    }
  }
}
