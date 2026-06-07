import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_elec/services/secure_storage_service.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  IO.Socket? _socket;
  final _secureStorage = SecureStorageService();

  bool get isConnected => _socket?.connected ?? false;
  bool _hasConnectedOnce = false;

  // Streams để UI có thể lắng nghe
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _quoteUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _inboxController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _jobCompletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _jobStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<String> get connectionStatus => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get onQuoteUpdated =>
      _quoteUpdatedController.stream;
  Stream<Map<String, dynamic>> get onInboxUpdate => _inboxController.stream;
  Stream<Map<String, dynamic>> get onJobCompleted =>
      _jobCompletedController.stream;
  Stream<Map<String, dynamic>> get onJobStatusChanged =>
      _jobStatusChangedController.stream;

  /// Kết nối tới Server Socket
  Future<void> connect(int? sessionId) async {
    // Nếu đã kết nối rồi thì không kết nối lại nữa, chỉ join room nếu cần
    if (_socket != null && _socket!.connected) {
      debugPrint(
        "ℹ️ ChatSocketService: Đã có kết nối, chỉ thực hiện join room nếu cần",
      );
      _connectionStatusController.add('Đã kết nối');
      if (sessionId != null) {
        joinRoom(sessionId);
      }
      return;
    }

    final token = await _secureStorage.getAccessToken();
    if (token == null) {
      debugPrint("❌ ChatSocketService: Không có token để kết nối Socket");
      _connectionStatusController.add('Lỗi xác thực');
      return;
    }

    final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000';
    _connectionStatusController.add('Đang kết nối...');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      debugPrint('✅ ChatSocketService: Đã kết nối Socket ID: ${_socket?.id}');
      
      if (_hasConnectedOnce) {
        debugPrint('♻️ ChatSocketService: Đã KẾT NỐI LẠI (Reconnected)!');
        _connectionStatusController.add('Đã kết nối lại');
      } else {
        _hasConnectedOnce = true;
        _connectionStatusController.add('Đã kết nối');
      }

      // Vừa kết nối xong thì tự động join room luôn (nếu có sessionId)
      if (sessionId != null) {
        joinRoom(sessionId);
      }
    });

    _socket?.onDisconnect((_) {
      debugPrint('⚠️ ChatSocketService: Mất kết nối Socket');
      _connectionStatusController.add('Mất kết nối');
    });

    _socket?.onConnectError((err) {
      debugPrint('❌ ChatSocketService: Lỗi kết nối Socket - $err');
      _connectionStatusController.add('Lỗi kết nối');
    });

    // Lắng nghe sự kiện có tin nhắn mới từ Server (trong phòng chat)
    _socket?.on('new_message', (data) {
      debugPrint('📩 ChatSocketService: Nhận tin nhắn mới: $data');
      _messageController.add(data); // Đẩy vào stream cho UI nhận
    });

    // Lắng nghe sự kiện cập nhật hộp thư (real-time inbox)
    _socket?.on('inbox_update', (data) {
      debugPrint('📨 ChatSocketService: Cập nhật hộp thư: $data');
      _inboxController.add(data);
    });

    // Lắng nghe sự kiện báo giá được cập nhật
    _socket?.on('quote_updated', (data) {
      debugPrint('💰 ChatSocketService: Báo giá được cập nhật: $data');
      _quoteUpdatedController.add(data);
    });

    // Lắng nghe sự kiện đơn hàng hoàn thành
    _socket?.on('job_completed', (data) {
      debugPrint('🎉 ChatSocketService: Đơn hàng hoàn thành: $data');
      if (data is Map<String, dynamic>) {
        _jobCompletedController.add(data);
      } else {
        _jobCompletedController.add({'status': 'COMPLETED'});
      }
    });

    // Lắng nghe sự kiện thay đổi trạng thái đơn hàng (MATCHED -> IN_PROGRESS)
    _socket?.on('job_status_changed', (data) {
      debugPrint('🔄 ChatSocketService: Trạng thái đơn hàng thay đổi: $data');
      _jobStatusChangedController.add(data);
    });
  }

  /// Tham gia phòng chat
  void joinRoom(int sessionId) {
    if (_socket != null && _socket!.connected) {
      // SỬA: Phải bọc trong object { 'sessionId': ... } để khớp với NestJS Backend
      _socket!.emit('join_room', {'sessionId': sessionId});
      debugPrint('➡️ ChatSocketService: Đã gửi yêu cầu join_room: $sessionId');
    }
  }

  /// Gửi tin nhắn Text qua Socket
  void sendMessage(
    int sessionId,
    String content,
    String type, {
    Map<String, dynamic>? metadata,
  }) {
    if (_socket != null && _socket!.connected) {
      final payload = {
        'sessionId': sessionId,
        'type': type,
        'content': content,
        if (metadata != null) 'metadata': metadata,
      };
      _socket!.emit('send_message', payload);
      debugPrint('⬆️ ChatSocketService: Đã gửi send_message: $payload');
    } else {
      debugPrint('❌ ChatSocketService: Chưa kết nối, không thể gửi tin nhắn.');
    }
  }

  /// Đánh dấu tin nhắn đã đọc
  void markAsRead(int messageId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('mark_as_read', messageId);
    }
  }

  /// Ngắt kết nối và dọn dẹp toàn hệ thống Socket
  void disconnect() {
    debugPrint('🛑 ChatSocketService: Bắt đầu ngắt kết nối Socket...');
    _hasConnectedOnce = false;

    // 1. Ngắt kết nối Socket
    if (_socket != null) {
      try {
        // Xóa tất cả event listeners trước khi disconnect
        _socket?.offAny();
        _socket?.off('new_message');
        _socket?.off('inbox_update');
        _socket?.off('quote_updated');
        _socket?.off('job_completed');
        _socket?.off('job_status_changed');
        _socket?.off('connect');
        _socket?.off('disconnect');
        _socket?.off('connect_error');
        _socket?.off('error');

        // Đóng kết nối
        _socket?.disconnect();
        _socket?.dispose();
        debugPrint('✅ ChatSocketService: Socket đã ngắt kết nối');
      } catch (e) {
        debugPrint('⚠️ ChatSocketService: Lỗi khi ngắt socket - $e');
      } finally {
        _socket = null;
      }
    }

    // 2. Đóng tất cả StreamControllers để tránh memory leak
    try {
      if (!_messageController.isClosed) {
        _messageController.close();
      }
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.close();
      }
      if (!_quoteUpdatedController.isClosed) {
        _quoteUpdatedController.close();
      }
      if (!_inboxController.isClosed) {
        _inboxController.close();
      }
      if (!_jobCompletedController.isClosed) {
        _jobCompletedController.close();
      }
      if (!_jobStatusChangedController.isClosed) {
        _jobStatusChangedController.close();
      }
      debugPrint('✅ ChatSocketService: Đã đóng tất cả StreamControllers');
    } catch (e) {
      debugPrint('⚠️ ChatSocketService: Lỗi khi đóng streams - $e');
    }

    debugPrint('🛑 ChatSocketService: Hoàn thành dọn dẹp hệ thống');
  }

  void dispose() {
    disconnect();
  }
}
