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

  // ─────────────────────────────────────────────────────────────────
  // API 3: Lấy danh sách đơn đã hoàn thành (DỮ LIỆU THẬT TỪ DATABASE)
  // ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getCompletedJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/technicians/jobs/completed'), 
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Lỗi khi tải danh sách đơn hoàn thành');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Lấy thông tin Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      print('--- BẮT ĐẦU GỌI API GET PROFILE ---');
      final url = '$_baseUrl/technicians/profile';
      print('URL: $url');
      
      final headers = await _getHeaders();
      print('Headers đang gửi: $headers'); // Kiểm tra xem có Bearer token chưa

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Status Code nhận được: ${response.statusCode}');
      print('Body nhận được: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API báo lỗi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('LỖI CATCH GET PROFILE: $e');
      rethrow;
    }
  }

  // Lấy danh sách đánh giá
  Future<List<dynamic>> getReviews() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/technicians/reviews'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Không thể tải danh sách đánh giá');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Đổi mật khẩu
  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/technicians/change-password'),
        headers: await _getHeaders(),
        body: json.encode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Lỗi khi đổi mật khẩu');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Cập nhật thông tin số điện thoại và email
  Future<Map<String, dynamic>> updateProfile(String fullName, String phoneNumber, String email) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/technicians/profile'), 
        headers: await _getHeaders(),
        body: json.encode({
          'fullName': fullName,     // Gửi thêm trường này lên Backend
          'phoneNumber': phoneNumber,
          'email': email,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Lỗi khi cập nhật hồ sơ');
      }
    } catch (e) {
      rethrow;
    }
  }
}