import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import '../models/chat_message.dart' as model;
import 'chat_screen_tech.dart';
import '../services/api_service.dart';
import '../services/chat_socket_service.dart';

class TechMessagesScreen extends StatefulWidget {
  const TechMessagesScreen({super.key});

  @override
  State<TechMessagesScreen> createState() => TechMessagesScreenState();
}

class TechMessagesScreenState extends State<TechMessagesScreen> {
  // Public method for tab navigation refresh
  void refreshInbox() {
    _fetchSessions();
  }

  final ApiService _apiService = ApiService();
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  int? currentUserId;

  late ChatSocketService _socketService;
  StreamSubscription? _inboxSubscription;

  @override
  void initState() {
    super.initState();
    _socketService = ChatSocketService();
    _initData();
  }

  Future<void> _initData() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      setState(() => currentUserId = user.id);
    }

    if (currentUserId == null) {
      final idFromToken = await _getUserIdFromToken();
      if (idFromToken != null && mounted) {
        setState(() => currentUserId = idFromToken);
      }
    }

    await _fetchSessions();
    _initSocket();
  }

  /// Giải mã JWT Token để lấy userId an toàn khi Provider null.
  Future<int?> _getUserIdFromToken() async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getAccessToken();
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      final sub = data['sub'];
      if (sub is int) return sub;
      if (sub is String) return int.tryParse(sub);
      return null;
    } catch (_) {
      return null;
    }
  }

  void _initSocket() async {
    await _socketService.connect(null); // Kết nối global

    _inboxSubscription = _socketService.onInboxUpdate.listen((data) {
      if (mounted) {
        _handleInboxUpdate(data);
      }
    });
  }

  void _handleInboxUpdate(Map<String, dynamic> data) {
    final int sessionId = data['sessionId'];
    final lastMsg = data['lastMessage'];

    setState(() {
      int index = _sessions.indexWhere((s) => s['id'] == sessionId);

      if (index != -1) {
        // Cập nhật session cũ: đưa lên đầu và thay tin nhắn mới
        var session = _sessions[index];
        session['messages'] = [lastMsg];
        _sessions.removeAt(index);
        _sessions.insert(0, session);
      } else {
        // Nếu là session mới (khách mới nhắn lần đầu)
        _fetchSessions();
      }
    });
  }

  Future<void> _fetchSessions() async {
    try {
      final sessions = await _apiService.getUserSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Lỗi fetch sessions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _inboxSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
      title: const Text(
        "Hộp thư khách hàng",
        style: TextStyle(
          fontWeight: FontWeight.w700, 
          color: Color(0xFF1A1A1A), 
          fontSize: 20
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0, // Ngăn Material 3 tự đổi màu nền khi cuộn
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey[200], height: 1.0),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1565C0)),
          onPressed: _fetchSessions,
        ),
      ],
    ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSessions,
              child: _sessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemCount: _sessions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 80),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final customer = session['user'];
                        final lastMsg = (session['messages'] as List).isNotEmpty
                            ? session['messages'][0]
                            : null;

                        // KIỂM TRA TIN NHẮN CHƯA ĐỌC (So sánh String-safe để tránh int vs null)
                        final bool isUnread =
                            lastMsg != null &&
                            lastMsg['isRead'] == false &&
                            lastMsg['senderId']?.toString() !=
                                currentUserId?.toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF1565C0).withOpacity(0.08), // Màu nền dịu hơn
                                backgroundImage: customer['avatarUrl'] != null
                                    ? NetworkImage(customer['avatarUrl'])
                                    : null,
                                child: customer['avatarUrl'] == null
                                    ? const Icon(Icons.person_rounded, color: Color(0xFF1565C0))
                                    : null,
                              ),
                              if (isUnread)
                                Positioned(
                                  right: 0,
                                  bottom: 2, // Đẩy lên một chút để không lẹm viền
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935), // Dùng màu đỏ nhẹ cho thông báo chưa đọc thay vì xanh để nổi bật hơn
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            customer['fullName'] ?? "Khách hàng",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            _formatLastMessage(lastMsg),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread ? Colors.black : Colors.grey[600],
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                lastMsg != null
                                    ? DateFormat('HH:mm').format(
                                        DateTime.parse(lastMsg['createdAt']).toLocal(),
                                      )
                                    : "",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUnread ? Colors.blueAccent : Colors.grey,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (session['status'] != null && session['status'] != 'PENDING')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F4F8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFD9E2EC), width: 1),
                                  ),
                                  child: Text(
                                    _getStatusLabel(session['status']), 
                                    style: const TextStyle(
                                      color: Color(0xFF334E68),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TechChatScreen(
                                  sessionId: session['id'],
                                  receiver: model.User(
                                    id: customer['id'],
                                    fullName: customer['fullName'],
                                    avatarUrl: customer['avatarUrl'],
                                    role: 'USER',
                                    phoneNumber: customer['phoneNumber'] ?? "",
                                  ),
                                ),
                              ),
                            );
                            _fetchSessions();
                          },
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "Bạn chưa có cuộc hội thoại nào.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatLastMessage(dynamic msg) {
    if (msg == null) return "Bắt đầu trò chuyện...";
    String type = msg['type']?.toString() ?? 'TEXT';

    if (type == 'IMAGE') return "[Hình ảnh]";
    if (type == 'VIDEO') return "[Video]";
    if (type == 'QUOTE_CARD') return "[Báo giá]";

    return msg['content'] ?? "";
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'MATCHED':
        return "Mới nhận";
      case 'ARRIVING':
      case 'EN_ROUTE': 
        return "Đang tới";
      case 'ARRIVED':
        return "Đã tới nơi";
      case 'QUOTING':
        return "Chờ duyệt giá";
      case 'REPAIRING':
      case 'IN_PROGRESS': 
        return "Đang sửa";
      case 'COMPLETED':
        return "Hoàn thành";
      case 'CANCELLED':
        return "Đã hủy";
      default:
        return status.isNotEmpty 
          ? '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}' 
          : status;
    }
  }
}
