import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/secure_storage_service.dart';

class TechnicianService {
  final String _baseUrl = dotenv.get(
    'API_URL',
    fallback: 'http://localhost:3000',
  );
  final _secureStorage = SecureStorageService();

  // Helper lấy headers kèm access token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // API 1: Lấy danh sách đơn đang phát sóng
  Future<List<dynamic>> getBroadcastJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chats/technician/jobs/broadcast'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Lỗi khi tải danh sách đơn hàng');
      }
    } catch (e) {
      rethrow;
    }
  }

  // API 2: Nhận đơn (Optimistic Locking)
  Future<bool> acceptJob(int sessionId, int currentVersion) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chats/technician/jobs/$sessionId/accept'),
        headers: await _getHeaders(),
        body: json.encode({'currentVersion': currentVersion}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 409) {
        throw Exception('Đơn đã bị thợ khác nhận mất rồi!');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Không thể nhận đơn này');
      }
    } catch (e) {
      rethrow;
    }
  }
}
