import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/secure_storage_service.dart';

class ChatService {
  final String _baseUrl = dotenv.get(
    'API_URL',
    fallback: 'http://localhost:3000',
  );
  final _secureStorage = SecureStorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // 1. Lấy lịch sử tin nhắn
  Future<List<dynamic>> getMessages(int sessionId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/chats/$sessionId/messages'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Không thể tải tin nhắn');
  }

  // 2. Tạo báo giá mới
  Future<void> createQuote(
    int sessionId,
    String title,
    double amount,
    String expectedTime,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chats/$sessionId/quotes'),
      headers: await _getHeaders(),
      body: json.encode({
        'title': title,
        'amount': amount,
        'expectedTime': expectedTime,
      }),
    );
    if (response.statusCode != 201) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Gửi báo giá thất bại');
    }
  }

  // 3. Gửi tin nhắn thường
  Future<void> sendMessage(int sessionId, String content) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chats/$sessionId/messages'),
      headers: await _getHeaders(),
      body: json.encode({'content': content, 'type': 'TEXT'}),
    );
    if (response.statusCode != 201) {
      throw Exception('Không thể gửi tin nhắn');
    }
  }
}
