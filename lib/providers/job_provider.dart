import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/secure_storage_service.dart';
import '../services/technician_service.dart';
import '../services/notification_service.dart';
import '../models/chat_message.dart';

class JobProvider extends ChangeNotifier {
  final TechnicianService _service = TechnicianService();
  final _secureStorage = SecureStorageService();

  List<dynamic> broadcastJobs = [];
  bool isLoading = false;
  io.Socket? _socket;

  // 1. Lấy danh sách đơn từ API
  Future<void> fetchJobs() async {
    isLoading = true;
    notifyListeners();
    try {
      broadcastJobs = await _service.getBroadcastJobs();
    } catch (e) {
      debugPrint('❌ Lỗi fetchJobs: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 2. Kết nối Socket
  Future<void> initSocket() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _secureStorage.getAccessToken();
    final baseUrl = dotenv.get('API_URL', fallback: 'http://localhost:3000');

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    debugPrint('🌐 Socket đang kết nối tới: $baseUrl');

    _socket!.onConnect((_) => debugPrint('📡 Socket connected (Job Board) tại $baseUrl'));
    _socket!.onConnectError((err) => debugPrint('❌ Socket lỗi kết nối: $err'));
    _socket!.onError((err) => debugPrint('❌ Socket error: $err'));

    _socket!.on('new_broadcast_job', (data) {
      debugPrint('🔔 Nhận được đơn mới: $data');
      // Thêm đơn vào danh sách hiển thị
      broadcastJobs.insert(0, data);
      notifyListeners();

      // Thống nhất ID: Ưu tiên sessionId (từ backend socket payload), fallback về id
      final String jobId = (data['sessionId'] ?? data['id'] ?? '').toString();

      if (jobId.isNotEmpty) {
        NotificationService.showJobAlertNotification(
          "🔥 ĐƠN HÀNG MỚI!",
          "Có khách hàng đang cần sửa ${data['deviceType'] ?? 'thiết bị'}",
          jobId,
        );
      } else {
        debugPrint('⚠️ Cảnh báo: Nhận đơn mới từ Socket nhưng thiếu ID để bắn notification!');
      }
    });

    _socket!.onDisconnect((_) => debugPrint('🔌 Socket disconnected'));
  }

  // 3. Hàm Nhận đơn (Optimistic Locking) - BẢN CHUẨN 2 THAM SỐ
  Future<void> acceptJob(dynamic job, BuildContext context) async {
    // THỐNG NHẤT ID: Lấy sessionId hoặc id từ object job
    final int? sessionId = job['sessionId'] ?? job['id'];
    final int version = job['version'] ?? 1;

    if (sessionId == null) {
      debugPrint("❌ CRITICAL: Không thể nhận đơn vì thiếu ID. Dữ liệu nhận được: $job");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Lỗi: Không xác định được ID đơn hàng!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      debugPrint("🚀 Đang gửi yêu cầu nhận đơn: sessionId=$sessionId, version=$version");
      final success = await _service.acceptJob(sessionId, version);

      if (success) {
        broadcastJobs.removeWhere((j) => (j['sessionId'] ?? j['id']) == sessionId);
        notifyListeners();

        if (context.mounted) {
          final userData = job['user'];
          if (userData == null) {
            debugPrint("⚠️ Cảnh báo: Nhận đơn thành công nhưng dữ liệu 'user' trả về bị null!");
          }

          final receiver = User(
            id: userData?['id'] ?? 0,
            fullName: userData?['fullName'] ?? 'Khách hàng',
            avatarUrl: userData?['avatarUrl'],
            role: 'USER',
          );

          Navigator.pushNamed(
            context,
            '/chat_detail',
            arguments: {'sessionId': sessionId, 'receiver': receiver},
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Nhận đơn thành công!')),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi thực hiện acceptJob: $e");
      // Xóa đơn khỏi danh sách local nếu đơn đã bị người khác nhận (tránh thợ bấm lại)
      broadcastJobs.removeWhere((j) => (j['sessionId'] ?? j['id']) == sessionId);
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 4. Ẩn đơn khỏi danh sách local khi thợ từ chối (không cần API)
  void hideJob(int? jobId) {
    if (jobId == null) return;
    broadcastJobs.removeWhere((j) => (j['sessionId'] ?? j['id']) == jobId);
    notifyListeners();
  }

  // 5. Hàm dọn dẹp khi đăng xuất
  void clear() {
    debugPrint('🛑 [JobProvider] Clearing data & disconnecting socket...');
    _socket?.disconnect();
    _socket = null;
    broadcastJobs.clear();
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
