import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import '../models/chat_message.dart' as model;
import 'chat_screen.dart';
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
    // 1. Ưu tiên lấy từ Provider
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      setState(() => currentUserId = user.id);
    }

    // 2. Fallback: Decode JWT nếu Provider chưa sẵn (standalone / push notification)
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
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
                                backgroundColor: Colors.blueAccent.withOpacity(
                                  0.1,
                                ),
                                backgroundImage: customer['avatarUrl'] != null
                                    ? NetworkImage(customer['avatarUrl'])
                                    : null,
                                child: customer['avatarUrl'] == null
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.blueAccent,
                                      )
                                    : null,
                              ),
                              if (isUnread)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
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
                                        DateTime.parse(
                                          lastMsg['createdAt'],
                                        ).toLocal(),
                                      )
                                    : "",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUnread
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (session['status'] == 'MATCHED')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "Đang sửa",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TechChatScreen(
                                  sessionId: session['id'],
                                  receiver: model.User(
                                    id: customer['id'],
                                    fullName: customer['fullName'],
                                    avatarUrl: customer['avatarUrl'],
                                    role: 'USER',
                                  ),
                                ),
                              ),
                            ).then((_) => _fetchSessions());
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
}
