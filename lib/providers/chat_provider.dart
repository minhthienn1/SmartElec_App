import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/chat_service.dart';
import '../services/secure_storage_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();
  final _secureStorage = SecureStorageService();

  List<dynamic> messages = [];
  bool isLoading = false;
  IO.Socket? _socket;

  // 1. Load tin nhắn cũ
  Future<void> fetchMessages(int sessionId) async {
    isLoading = true;
    notifyListeners();
    try {
      messages = await _service.getMessages(sessionId);
    } catch (e) {
      debugPrint('❌ Lỗi fetchMessages: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 2. Kết nối Socket vào Room chat riêng
  Future<void> initChatSocket(int sessionId) async {
    if (_socket != null && _socket!.connected) return;

    final token = await _secureStorage.getAccessToken();
    final baseUrl = dotenv.get('API_URL', fallback: 'http://localhost:3000');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('📡 Socket Chat connected');
      // Tham gia vào room của session này
      _socket!.emit('join_room', sessionId);
    });

    // Lắng nghe tin nhắn mới
    _socket!.on('new_message', (data) {
      messages.add(data);
      notifyListeners();
    });

    // Lắng nghe cập nhật báo giá
    _socket!.on('quote_updated', (data) {
      final index = messages.indexWhere((m) => m['id'] == data['messageId']);
      if (index != -1) {
        messages[index] = data['message'];
        notifyListeners();
      }
    });

    _socket!.onDisconnect((_) => debugPrint('🔌 Socket Chat disconnected'));
  }

  // 3. Gửi tin nhắn TEXT
  Future<void> sendMessage(int sessionId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      // Gọi service để gửi tin nhắn
      await _service.sendMessage(sessionId, content);
      // Tin nhắn sẽ tự bay về qua Socket 'new_message'
    } catch (e) {
      debugPrint('❌ Lỗi gửi tin nhắn: $e');
      rethrow;
    }
  }

  // 4. Gửi báo giá
  Future<void> sendQuote(
    int sessionId,
    String title,
    double amount,
    String time,
  ) async {
    try {
      await _service.createQuote(sessionId, title, amount, time);
      // Tin nhắn QUOTE_CARD sẽ tự bay về qua Socket 'new_message'
    } catch (e) {
      debugPrint('❌ Lỗi gửi báo giá: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _socket?.emit('leave_room');
    _socket?.disconnect();
    super.dispose();
  }
}
