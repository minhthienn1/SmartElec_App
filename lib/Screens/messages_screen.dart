import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'messenger_chat_screen.dart';
import '../models/chat_message.dart' as model;
import '../models/chat_session.dart';
import '../services/api_service.dart';
import '../services/chat_socket_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => MessagesScreenState();
}

class MessagesScreenState extends State<MessagesScreen> {
  // Public method for tab navigation refresh
  void refreshInbox() {
    _loadInitialData();
  }
  // Đổi từ Cam sang Xanh Neon chuẩn hệ sinh thái của app
  final Color _accentColor = const Color(0xff00E676);
  final Color _bgColor = const Color(0xff081125);
  final Color _cardColor = const Color(0xff111B3D);
  
  List<ChatSession> _sessions = [];
  int? _myId;
  bool _isLoading = true;
  String? _error;
  
  late ChatSocketService _socketService;
  StreamSubscription? _inboxSubscription;

  @override
  void initState() {
    super.initState();
    _socketService = ChatSocketService();
    _loadInitialData();
  }

  // --- LOGIC GIỮ NGUYÊN 100% ---
  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getChatSessions(),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final sessions = results[1] as List<ChatSession>;

      if (mounted) {
        setState(() {
          _myId = profile['id'] as int;
          _sessions = sessions;
          _isLoading = false;
        });
        _initSocket();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _initSocket() async {
    await _socketService.connect(null);
    _inboxSubscription = _socketService.onInboxUpdate.listen((data) {
      if (mounted) _handleInboxUpdate(data);
    });
  }

  void _handleInboxUpdate(Map<String, dynamic> data) {
    final int sessionId = data['sessionId'];
    final lastMessageData = data['lastMessage'];
    final lastMsg = SessionMessage.fromJson(lastMessageData);

    setState(() {
      int index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final session = _sessions[index];
        final updatedSession = ChatSession(
          id: session.id,
          deviceType: session.deviceType,
          symptom: session.symptom,
          status: session.status,
          createdAt: session.createdAt,
          updatedAt: lastMsg.createdAt, 
          customer: session.customer,
          technician: session.technician,
          messages: [lastMsg], 
        );
        _sessions.removeAt(index);
        _sessions.insert(0, updatedSession);
      } else {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _inboxSubscription?.cancel();
    super.dispose();
  }
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor, // Nền tối
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Tin nhắn",
          style: TextStyle(
            color: Colors.white, // Chữ trắng
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: _accentColor, size: 24),
              onPressed: () => _loadInitialData(),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _accentColor));
    }
    if (_error != null) return _buildErrorState(_error!);
    if (_sessions.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 100), // Chừa khoảng trống cho BottomNav
      itemCount: _sessions.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 85, right: 16),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withOpacity(0.05), // Đường kẻ mờ sang trọng
        ),
      ),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final otherUser = (session.customer?.id.toString() == _myId.toString())
            ? session.technician
            : session.customer;

        if (otherUser == null) return const SizedBox.shrink();

        final lastMsg = session.messages.isNotEmpty ? session.messages.first : null;
        final bool isUnread = lastMsg != null && lastMsg.senderName == otherUser.fullName;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          leading: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Viền avatar phát sáng nhẹ
              border: Border.all(
                color: isUnread ? _accentColor : Colors.white10, 
                width: 2
              ),
              boxShadow: isUnread ? [
                BoxShadow(color: _accentColor.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)
              ] : [],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: _cardColor,
              backgroundImage: otherUser.avatarUrl != null
                  ? NetworkImage(otherUser.avatarUrl!)
                  : null,
              child: otherUser.avatarUrl == null
                  ? Icon(Icons.person, color: isUnread ? _accentColor : Colors.white54, size: 30)
                  : null,
            ),
          ),
          title: Text(
            otherUser.fullName ?? "Người dùng SmartElec",
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
              fontSize: 16,
              color: Colors.white, // Tên người dùng màu trắng
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatLastMessage(lastMsg),
              style: TextStyle(
                color: isUnread ? Colors.white : const Color(0xff8E9AA6), // Chữ xám nếu đã đọc
                fontSize: 14,
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDateTime(lastMsg?.createdAt ?? session.updatedAt),
                style: TextStyle(
                  color: isUnread ? _accentColor : const Color(0xff8E9AA6),
                  fontSize: 12,
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              if (isUnread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
            ],
          ),
          onTap: () {
          // 1. Đặt debugPrint ở ngay đây (trước khi Navigator.push)
          debugPrint("🛠️ SĐT TỪ BẢN GHI TRƯỚC KHI CHUYỂN TRANG: ${otherUser.phoneNumber}");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MessengerChatScreen(
                sessionId: session.id,
                receiver: model.User(
                  id: otherUser.id,
                  fullName: otherUser.fullName ?? "Người dùng",
                  role: otherUser.role,
                  avatarUrl: otherUser.avatarUrl,
                  // 2. 👉 THÊM DÒNG NÀY VÀO LÀ SỬA ĐƯỢC LỖI:
                  phoneNumber: otherUser.phoneNumber ?? "", 
                ),
              ),
            ),
          ).then((_) => _loadInitialData());
        },
        );
      },
    );
  }

  // LOGIC FORMAT TIME GIỮ NGUYÊN
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && now.day == dateTime.day) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != dateTime.day)) {
      return "Hôm qua";
    } else if (difference.inDays < 7) {
      final weekday = DateFormat('EEEE').format(dateTime);
      return _translateWeekday(weekday);
    } else {
      return DateFormat('dd/MM').format(dateTime);
    }
  }

  String _translateWeekday(String englishWeekday) {
    switch (englishWeekday) {
      case 'Monday': return 'Thứ 2';
      case 'Tuesday': return 'Thứ 3';
      case 'Wednesday': return 'Thứ 4';
      case 'Thursday': return 'Thứ 5';
      case 'Friday': return 'Thứ 6';
      case 'Saturday': return 'Thứ 7';
      case 'Sunday': return 'Chủ Nhật';
      default: return englishWeekday;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.white.withOpacity(0.2)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Chưa có cuộc trò chuyện nào",
            style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _loadInitialData(),
            icon: Icon(Icons.refresh_rounded, color: _accentColor),
            label: Text("Tải lại danh sách", style: TextStyle(color: _accentColor, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _accentColor.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: _accentColor.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              "Đã xảy ra lỗi khi tải tin nhắn",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadInitialData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardColor,
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text("Thử lại", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastMessage(SessionMessage? msg) {
    if (msg == null) return "Chưa có tin nhắn";
    String prefix = msg.senderName != null ? "${msg.senderName}: " : "";
    if (msg.type == "IMAGE") return "$prefix[Hình ảnh]";
    if (msg.type == "VIDEO") return "$prefix[Video]";
    if (msg.type == "QUOTE_CARD") return "$prefix[Báo giá]";
    return "$prefix${msg.content}";
  }
}