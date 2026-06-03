import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_elec/main.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import 'package:smart_elec/services/chat_socket_service.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:smart_elec/models/device.dart';
import '../models/repair_case.dart';
import '../models/chat_session.dart';

class ApiService {
  // Đọc baseUrl từ file .env, fallback về http://192.168.1.120:3000
  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://192.168.1.186:3000';
  static const _storage = FlutterSecureStorage();
  // Instance dùng chung trong class, không cần khởi tạo lại mỗi lần gọi
  static final _secureStorage = SecureStorageService();

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE HELPER: Lấy access_token từ Secure Storage và trả về
  // Map headers chuẩn cho mọi request cần xác thực (Authorization).
  // ─────────────────────────────────────────────────────────────────
  static Future<void> bookTechnician(
    int sessionId,
    Map<String, dynamic> bookingData,
  ) async {
    final headers = await _getHeaders();
    try {
      final response = _handleResponse(
        await http.post(
          Uri.parse('$baseUrl/chats/$sessionId/book'),
          headers: headers,
          body: jsonEncode(bookingData),
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Thành công
      } else {
        // 🚨 BẮT LỖI TỪ BACKEND NHẢ VỀ
        debugPrint(
          "🚨 BACKEND BÁO LỖI: ${response.statusCode} - ${response.body}",
        );

        String serverMessage = 'Không thể tạo đơn đặt thợ. Vui lòng thử lại.';
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['message'] is List) {
            serverMessage = (body['message'] as List).join(', ');
          } else if (body['message'] is String) {
            serverMessage = body['message'] as String;
          }
        } catch (_) {}

        throw Exception(serverMessage);
      }
    } catch (e) {
      // 🚨 IN RA LỖI THẬT SỰ (Mất mạng, null data, v.v...)
      debugPrint("🚨 LỖI THẬT SỰ LÀ: $e");

      if (e is Exception &&
          !e.toString().contains("SocketException") &&
          !e.toString().contains("Connection failed")) {
        rethrow;
      }
      throw Exception('Không thể tạo đơn đặt thợ. Vui lòng thử lại.');
    }
  }

  static Future<void> sendAiFeedback({
    required int? sessionId,
    required String message,
    required String feedback,
  }) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/ai/feedback'),
      headers: headers,
      body: jsonEncode({
        'sessionId': sessionId,
        'message': message,
        'feedback': feedback,
      }),
    );
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // RESPONSE HANDLER: Bắt lỗi 401 (Hết hạn token) để logout cưỡng bức
  // ─────────────────────────────────────────────────────────────────
  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint("🚨 [401] Token hết hạn! Đang đăng xuất...");
      _forceLogout();
    }
    return response;
  }

  static Future<void> _forceLogout() async {
    final context = navigatorKey.currentContext;

    debugPrint('🚨 [ApiService] Bắt đầu forced logout do token hết hạn...');

    try {
      // 1️⃣ NGẮT SOCKET: Đóng hoàn toàn kết nối Socket.io
      debugPrint('1️⃣ [ApiService] Ngắt Socket...');
      try {
        ChatSocketService().disconnect();
        debugPrint('✅ [ApiService] Socket đã ngắt');
      } catch (e) {
        debugPrint('⚠️ [ApiService] Lỗi ngắt socket: $e');
      }

      // 2️⃣ XÓA STORAGE: Xóa sạch SecureStorage
      debugPrint('2️⃣ [ApiService] Xóa SecureStorage...');
      try {
        await _secureStorage.clearAll();
        debugPrint('✅ [ApiService] SecureStorage đã xóa');
      } catch (e) {
        debugPrint('⚠️ [ApiService] Lỗi xóa SecureStorage: $e');
      }

      // 3️⃣ RESET PROVIDER: Gọi UserProvider.logout() để reset state
      if (context != null) {
        debugPrint('3️⃣ [ApiService] Reset UserProvider...');
        try {
          await Provider.of<UserProvider>(context, listen: false).logout();
          debugPrint('✅ [ApiService] UserProvider đã reset');
        } catch (e) {
          debugPrint('⚠️ [ApiService] Lỗi reset UserProvider: $e');
        }

        // 4️⃣ THÔNG BÁO: Hiển thị thông báo ngay lập tức
        debugPrint('4️⃣ [ApiService] Hiển thị thông báo...');
        try {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại!",
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        } catch (e) {
          debugPrint('⚠️ [ApiService] Lỗi hiển thị snackbar: $e');
        }
      }

      // 5️⃣ ĐIỀU HƯỚNG: Về Login và xóa toàn bộ stack
      debugPrint('5️⃣ [ApiService] Điều hướng về Login...');
      try {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        debugPrint('✅ [ApiService] Đã điều hướng về Login');
      } catch (e) {
        debugPrint('⚠️ [ApiService] Lỗi điều hướng: $e');
      }

      debugPrint('✅ [ApiService] Forced logout hoàn tất!');
    } catch (e) {
      debugPrint('❌ [ApiService] FORCED LOGOUT THẤT BẠI: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // AUTH APIs (không cần token)
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                '⏱️ Hệ thống đang khởi động hoặc mất kết nối. Vui lòng thử lại sau.',
              );
            },
          );

      final responseBody = jsonDecode(response.body);

      // Nếu server báo lỗi (SĐT đã tồn tại, lỗi validate...)
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = responseBody['message'] ?? 'Đăng ký thất bại';
        throw Exception(errorMessage); // Ném lỗi ra cho giao diện bắt
      }

      return responseBody as Map<String, dynamic>;
    } on TimeoutException catch (e) {
      debugPrint("⏱️ [Timeout] ApiService Register: $e");
      throw Exception(
        e.message ??
            '⏱️ Hệ thống đang khởi động hoặc mất kết nối. Vui lòng thử lại sau.',
      );
    } catch (e) {
      debugPrint("❌ Lỗi ApiService Register: $e");
      // Quăng thẳng lỗi ra ngoài để UI hiển thị SnackBar
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phoneNumber': phone, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                '⏱️ Hệ thống đang khởi động hoặc mất kết nối. Vui lòng thử lại sau.',
              );
            },
          );

      final responseBody = jsonDecode(response.body);

      // Nếu sai pass hoặc SĐT chưa đăng ký
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = responseBody['message'] ?? 'Đăng nhập thất bại';
        throw Exception(errorMessage); // Ném lỗi ra cho UI
      }

      return responseBody as Map<String, dynamic>;
    } on TimeoutException catch (e) {
      debugPrint("⏱️ [Timeout] ApiService Login: $e");
      throw Exception(
        e.message ??
            '⏱️ Hệ thống đang khởi động hoặc mất kết nối. Vui lòng thử lại sau.',
      );
    } catch (e) {
      debugPrint("❌ Lỗi ApiService Login: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> zaloLogin({
    required String zaloId,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/zalo-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'zaloId': zaloId,
          'name': name,
          'avatarUrl': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseBody = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(responseBody['message'] ?? 'Đăng nhập Zalo thất bại từ máy chủ');
      }
      return responseBody as Map<String, dynamic>;
    } catch (e) {
      debugPrint("❌ Lỗi ApiService Zalo Login: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseBody = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(responseBody['message'] ?? 'Đăng nhập Google thất bại từ máy chủ');
      }
      return responseBody as Map<String, dynamic>;
    } catch (e) {
      debugPrint("❌ Lỗi ApiService Google Login: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> setPasswordForZalo(
    String phoneNumber,
    String newPassword,
  ) async {
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/set-password'),
        headers: headers,
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseBody = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(responseBody['message'] ?? 'Cài đặt mật khẩu thất bại');
      }
      return responseBody as Map<String, dynamic>;
    } catch (e) {
      debugPrint("❌ Lỗi ApiService Set Password: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }


  // ─────────────────────────────────────────────────────────────────
  // CHAT HISTORY APIs (cần JWT token)
  // ─────────────────────────────────────────────────────────────────

  /// Lưu một phiên chẩn đoán lên server và trả về sessionId.
  /// Gọi API: POST /chats/save
  static Future<int> saveHistory(RepairCase repairCase) async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.post(
        Uri.parse('$baseUrl/chats/save'),
        headers: headers,
        body: jsonEncode({
          'title': repairCase.title, // Flutter title → Prisma deviceType
          'summary': repairCase.summary, // Flutter summary → Prisma aiSummary
        }),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String serverMessage = 'Không thể lưu lịch sử chẩn đoán.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        serverMessage = body['message'] as String? ?? serverMessage;
      } catch (_) {}
      throw Exception(serverMessage);
    }

    final data = jsonDecode(response.body);
    return data['id'] as int;
  }

  /// Alias cho luồng Gọi thợ nhanh từ trang chủ
  static Future<int> createQuickSession(String device, String symptom) async {
    return saveHistory(
      RepairCase(id: '', title: device, summary: symptom, date: DateTime.now()),
    );
  }

  /// Lấy toàn bộ lịch sử chẩn đoán của user đang đăng nhập.
  /// Gọi API: GET /chats/history
  /// Tự động map JSON từ chuẩn Prisma (deviceType, aiSummary, id: int)
  /// sang model [RepairCase] của Flutter (title, summary, id: String).
  static Future<List<RepairCase>> getHistory() async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.get(Uri.parse('$baseUrl/chats/history'), headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String serverMessage = 'Không thể tải lịch sử chẩn đoán.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        serverMessage = body['message'] as String? ?? serverMessage;
      } catch (_) {}
      throw Exception('Lỗi ${response.statusCode}: $serverMessage');
    }

    final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;

    return jsonList.map((item) {
      final map = item as Map<String, dynamic>;
      return RepairCase(
        // Ép kiểu id từ int (Prisma/PostgreSQL) sang String (Flutter model)
        id: map['id'].toString(),
        // Mapping: Prisma `deviceType` → Flutter `title`
        title: map['deviceType'] as String? ?? 'Chưa rõ thiết bị',
        // Mapping: Prisma `createdAt` ISO string → Flutter DateTime
        date: DateTime.parse(map['createdAt'] as String),
        // Mapping: Prisma `aiSummary` → Flutter `summary`
        summary:
            (map['symptom'] as String?) ?? (map['aiSummary'] as String?) ?? '',
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // REALTIME CHAT APIs (1-1)
  // ─────────────────────────────────────────────────────────────────

  /// Lấy danh sách các phiên chat (Hộp thư)
  static Future<List<ChatSession>> getChatSessions() async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.get(Uri.parse('$baseUrl/chats'), headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể tải danh sách phiên chat.');
    }

    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((item) => ChatSession.fromJson(item)).toList();
  }

  /// Lấy thông tin chi tiết một phiên chat (bao gồm status)
  static Future<ChatSession> getSessionById(int sessionId) async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.get(Uri.parse('$baseUrl/chats/$sessionId'), headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể lấy thông tin phiên chat.');
    }

    return ChatSession.fromJson(jsonDecode(response.body));
  }

  /// Lấy lịch sử tin nhắn của một phiên chat cụ thể
  static Future<List<dynamic>> getChatMessages(int sessionId) async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.get(
        Uri.parse('$baseUrl/chats/$sessionId/messages'),
        headers: headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể tải tin nhắn.');
    }

    final data = jsonDecode(response.body);
    // API trả về mảng trực tiếp hoặc data.messages tùy thiết kế backend
    // Giả sử API trả về trực tiếp mảng (hoặc có data bọc ngoài)
    if (data is List) {
      return data;
    } else if (data['data'] != null) {
      return data['data']; // Format thường dùng khi có pagination
    }
    return [];
  }

  /// Upload ảnh trong phiên chat lên Cloudflare R2 thông qua REST
  static Future<Map<String, dynamic>> uploadChatImage(
    int sessionId,
    String filePath,
    String fileName,
  ) async {
    final token = await _secureStorage.getAccessToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/chat/upload'),
    );

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['sessionId'] = sessionId.toString();

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Upload ảnh thất bại.';
      try {
        final body = jsonDecode(response.body);
        errorMessage = body['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cập nhật trạng thái báo giá
  static Future<void> updateQuoteStatus(int messageId, String status) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/chats/messages/$messageId/quote'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Cập nhật trạng thái báo giá thất bại. Vui lòng thử lại.',
      );
    }
  }

  /// Xác nhận hoàn thành đơn hàng (Dùng cho Thợ)
  static Future<void> completeJob(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/technician/jobs/$sessionId/complete'),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể hoàn thành đơn hàng. Vui lòng thử lại.');
    }
  }

  /// Thợ bắt đầu di chuyển (Dùng cho Thợ)
  static Future<void> startEnRoute(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/technician/jobs/$sessionId/start-moving'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(
        body['message'] ?? 'Lỗi hệ thống: ${response.statusCode}',
      );
    }
  }

  /// Thợ xác nhận đã đến nơi (Dùng cho Thợ)
  static Future<void> confirmArrival(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/technician/jobs/$sessionId/arrived'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Không thể xác nhận đã đến nơi.');
    }
  }

  static Future<void> startRepair(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/technician/jobs/$sessionId/start-repair'),
      headers: headers,
    );
    
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Không thể bắt đầu sửa chữa. Vui lòng thử lại.');
    }
  }

  /// Thợ chủ động hủy đơn (Từ bỏ - Dùng cho Thợ)
  static Future<void> cancelJobTech(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/technician/jobs/$sessionId/cancel'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Không thể hủy đơn hàng.');
    }
  }

  /// Khách hàng hủy đơn (Dùng cho Khách)
  static Future<void> cancelJobUser(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/user/jobs/$sessionId/cancel'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Không thể hủy đơn hàng.');
    }
  }

  /// Khách hàng yêu cầu tìm thợ khác (Dùng cho Khách - Trị Ghosting)
  static Future<void> redispatchJob(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/user/jobs/$sessionId/redispatch'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Không thể tìm thợ khác.');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DEVICES APIs
  // ─────────────────────────────────────────────────────────────────

  static Future<List<Device>> getDevices() async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.get(Uri.parse('$baseUrl/devices'), headers: headers),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể tải danh sách thiết bị');
    }

    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((item) => Device.fromJson(item)).toList();
  }

  static Future<void> addDevice(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/devices'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể thêm thiết bị mới');
    }
  }

  static Future<void> updateDevice(String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/devices/$id'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể cập nhật thiết bị');
    }
  }

  static Future<void> deleteDevice(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/devices/$id'),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể xóa thiết bị');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // USERS APIs
  // ─────────────────────────────────────────────────────────────────

  /// Cập nhật FCM Token để nhận thông báo đẩy
  static Future<void> updateFcmToken(
    String fcmToken, {
    String? jwtToken,
  }) async {
    try {
      Map<String, String> headers;
      if (jwtToken != null) {
        headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        };
      } else {
        headers = await _getHeaders();
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/users/fcm-token'),
        headers: headers,
        body: jsonEncode({'token': fcmToken}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('❌ Không thể cập nhật FCM Token: ${response.statusCode}');
      } else {
        debugPrint('✅ FCM Token đã được cập nhật lên server');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi FCM Token lên server: $e');
    }
  }

  /// Lấy thông tin cá nhân của user đang đăng nhập
  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await _getHeaders();
    final response = _handleResponse(
      await http.get(
        Uri.parse(
          '$baseUrl/auth/profile',
        ), // Giả định endpoint profile nằm ở /auth/profile
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải thông tin cá nhân');
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final token = await _storage.read(key: 'access_token');

    final response = await http.patch(
      Uri.parse(
        '$baseUrl/users/update-profile',
      ), // Khớp với @Patch('update-profile') ở Backend
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Cập nhật thông tin thất bại');
    }
  }

  /// Gửi tin nhắn cho AI Gemini (thông qua Backend)
  static Future<Map<String, dynamic>> sendChatMessage(
    String message, {
    String? imageBase64,
    List<Map<String, String>>? history,
    int? sessionId, // THÊM THAM SỐ NÀY
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: headers,
      body: jsonEncode({
        'message': message,
        'image': imageBase64,
        'history': history,
        'sessionId': sessionId, // TRUYỀN LÊN BACKEND
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String serverMessage = 'Lỗi kết nối đến máy chủ AI.';
      try {
        final body = jsonDecode(response.body);
        serverMessage = body['message'] ?? serverMessage;
      } catch (_) {}
      throw Exception(serverMessage);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// [Reset AI Session] Hủy bỏ phiên chẩn đoán hiện tại để bắt đầu phiên mới sạch sẽ
  static Future<void> resetAiSession(int sessionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/ai/reset-session'),
      headers: headers,
      body: jsonEncode({'sessionId': sessionId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Không thể reset phiên chat.');
    }
  }

  /// Lấy danh sách các phiên chat (Hộp thư) - Dùng cho cả User và Tech
  Future<List<dynamic>> getUserSessions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/chats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Không thể tải danh sách hộp thư');
    }
  }

  /// Đánh dấu tin nhắn đã đọc
  Future<void> markAsRead(int messageId) async {
    final headers = await _getHeaders();
    await http.patch(
      Uri.parse('$baseUrl/chats/messages/$messageId/read'),
      headers: headers,
    );
  }

  /// Đánh dấu tất cả tin nhắn trong phiên chat là đã đọc
  Future<void> markAllAsRead(int sessionId) async {
    final headers = await _getHeaders();
    await http.patch(
      Uri.parse('$baseUrl/chats/$sessionId/read-all'),
      headers: headers,
    );
  }

  /// Gửi đánh giá sau khi hoàn thành đơn
  static Future<void> submitReview({
    required int sessionId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chats/user/jobs/$sessionId/review'),
      headers: headers,
      body: jsonEncode({
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(
        body['message'] ?? 'Không thể gửi đánh giá. Vui lòng thử lại.',
      );
    }
  }

  /// [RLHF] Gửi phản hồi Like/Dislike cho câu trả lời AI — chạy ngầm, không throw lỗi
  static Future<void> submitAiFeedback({
    required int logId,
    required String feedback, // "LIKE" hoặc "DISLIKE"
  }) async {
    try {
      final headers = await _getHeaders();
      await http.patch(
        Uri.parse('$baseUrl/ai/messages/$logId/feedback'),
        headers: headers,
        body: jsonEncode({'feedback': feedback}),
      );
    } catch (_) {
      // Silent fail — không làm phiền người dùng
    }
  }

  /// Bật/Tắt trạng thái online và cập nhật tọa độ (Dùng cho Thợ)
  static Future<Map<String, dynamic>?> toggleOnline({
    double? lat,
    double? lng,
    bool? isOnline,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/users/toggle-online'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (isOnline != null) 'isOnline': isOnline,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ ApiService Error (toggleOnline): $e');
      return null;
    }
  }
}
