import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_socket_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../Widgets/review_bottom_sheet.dart';
import '../core/constants/job_status.dart';

class MessengerChatScreen extends StatefulWidget {
  final int sessionId;
  final User receiver; // Người đang chat cùng (VD: Thợ Lao)

  const MessengerChatScreen({
    super.key,
    required this.sessionId,
    required this.receiver,
  });

  @override
  _MessengerChatScreenState createState() => _MessengerChatScreenState();
}

class _MessengerChatScreenState extends State<MessengerChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryOrange = Colors.orange[800]!;
  final ImagePicker _picker = ImagePicker();

  late ChatSocketService _socketService;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _quoteSubscription;
  StreamSubscription? _jobStatusSubscription;
  StreamSubscription? _statusChangedSubscription;

  int? currentUserId;
  bool _isLoadingHistory = true;
  bool _isUploadingMedia = false;
  bool _isJobCompleted = false; // Đơn đã hoàn thành
  bool _hasReviewed = false; // Đã review chưa
  String _connectionStatus = 'Đang kết nối...';
  String _sessionStatus = JobStatus.aiConsulting;
  DateTime? _sessionUpdatedAt;

  // Danh sách tin nhắn thật
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // ✅ PRODUCTION: Chỉ lấy userId từ UserProvider (đã được load sẵn từ Splash/Main Screen)
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      setState(() => currentUserId = user.id);
    }

    if (currentUserId == null) {
      debugPrint(
        "❌ CRITICAL: currentUserId không xác định được. UserProvider chưa được initialize!",
      );
      // Không gán default - để tránh lỗi UI logic là
      return;
    }

    // Lấy thông tin session để biết status ban đầu
    try {
      final session = await ApiService.getSessionById(widget.sessionId);
      if (mounted) {
        setState(() {
          _sessionStatus = session.status;
          _sessionUpdatedAt = session.updatedAt;
          _hasReviewed = session.review != null;
          if (session.status == JobStatus.completed) {
            _isJobCompleted = true;
          }
        });

        // Tự động mở BottomSheet đánh giá nếu trạng thái là COMPLETED và chưa review
        if (session.status == JobStatus.completed && !_hasReviewed) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted && !_hasReviewed) {
              _showReviewSheet();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi lấy thông tin session: $e");
    }

    // 2. Tải lịch sử tin nhắn
    await _loadChatHistory();
    // Đánh dấu đã đọc tất cả
    ApiService().markAllAsRead(widget.sessionId);

    // 3. Khởi tạo và kết nối Socket
    _socketService = ChatSocketService();

    _connectionSubscription = _socketService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() => _connectionStatus = status);
      }
    });

    _statusChangedSubscription = _socketService.onJobStatusChanged.listen((
      data,
    ) {
      if (mounted &&
          data['sessionId']?.toString() == widget.sessionId.toString()) {
        setState(() {
          _sessionStatus = data['status'];
          _sessionUpdatedAt = DateTime.now();
          if (data['status'] == JobStatus.completed) {
            _isJobCompleted = true;
          }
        });

        if (data['message'] != null) {
          _showSnackBar(data['message'], Colors.blueAccent);
        }

        // Tự động mở BottomSheet đánh giá nếu trạng thái là COMPLETED
        if (data['status'] == JobStatus.completed && !_hasReviewed) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted && !_hasReviewed) {
              _showReviewSheet();
            }
          });
        }
      }
    });

    _messageSubscription = _socketService.onNewMessage.listen((data) {
      if (mounted) {
        final newMessage = ChatMessage.fromJson(data);

        // 🚨 BẢO MẬT: Chỉ hiển thị tin nhắn thuộc phiên chat hiện tại
        if (newMessage.sessionId.toString() != widget.sessionId.toString()) {
          debugPrint(
            "ℹ️ Bỏ qua tin nhắn thuộc phiên khác: ${newMessage.sessionId}",
          );
          return;
        }

        final isFromMe =
            newMessage.senderId == currentUserId &&
            newMessage.sender?.role == 'USER';

        setState(() {
          if (isFromMe) {
            // 1. Tìm và xóa tin nhắn tạm thời (id > 1000000) có nội dung khớp
            final tempIndex = _messages.indexWhere(
              (m) =>
                  m.id > 1000000 &&
                  m.content.trim() == newMessage.content.trim(),
            );
            if (tempIndex != -1) {
              _messages.removeAt(tempIndex);
            }
          }

          // 2. Chỉ thêm tin nhắn mới nếu nó chưa tồn tại (theo ID thật từ Server)
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.insert(0, newMessage);

            // TỰ ĐỘNG ĐÁNH DẤU ĐÃ ĐỌC
            if (!isFromMe) {
              ApiService().markAsRead(newMessage.id);
            }

            // Bắn thông báo nếu tin nhắn là của đối phương
            if (!isFromMe) {
              String body = newMessage.content;
              if (newMessage.type.toString().contains('IMAGE') ||
                  data['type'] == 'IMAGE') {
                body = '[Hình ảnh]';
              } else if (newMessage.type.toString().contains('VIDEO') ||
                  data['type'] == 'VIDEO') {
                body = '[Video]';
              } else if (newMessage.type.toString().contains('QUOTE_CARD') ||
                  data['type'] == 'QUOTE_CARD') {
                body = '[Yêu cầu báo giá]';
              }
              NotificationService.showNewMessageNotification(
                newMessage.sender?.fullName ?? widget.receiver.fullName,
                body,
              );
            }
          }
        });
        _scrollToBottom();
      }
    });

    _quoteSubscription = _socketService.onQuoteUpdated.listen((data) {
      if (mounted) {
        setState(() {
          final messageId = data['messageId'];
          final status = data['status'];
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final msg = _messages[index];
            if (msg.metadata != null) {
              msg.metadata!['quoteStatus'] = status;
            } else {
              msg.metadata = {'quoteStatus': status};
            }
          }
        });
      }
    });

    // Lắng nghe sự kiện JOB_COMPLETED từ thợ
    _jobStatusSubscription = _socketService.onJobCompleted.listen((data) {
      if (mounted &&
          data['sessionId']?.toString() == widget.sessionId.toString()) {
        setState(() => _isJobCompleted = true);
        // Tự động mở BottomSheet đánh giá
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_hasReviewed) {
            _showReviewSheet();
          }
        });
      }
    });

    await _socketService.connect(widget.sessionId);
  }

  Future<void> _loadChatHistory() async {
    try {
      final rawData = await ApiService.getChatMessages(widget.sessionId);
      if (mounted) {
        setState(() {
          // Parse array JSON sang danh sách ChatMessage
          final parsed = rawData.map((e) => ChatMessage.fromJson(e)).toList();
          // API thường trả về tin cũ nhất ở đầu.
          // Vì ListView reverse: true nên ta phải đảo ngược mảng để tin mới nhất nằm ở index 0
          _messages.addAll(parsed.reversed);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải lịch sử chat: $e");
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        _showSnackBar("Không thể tải lịch sử tin nhắn: $e", Colors.redAccent);
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _quoteSubscription?.cancel();
    _jobStatusSubscription?.cancel();
    _statusChangedSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showReviewSheet() async {
    await ReviewBottomSheet.show(
      context,
      sessionId: widget.sessionId,
      technicianName: widget.receiver.fullName,
      technicianAvatarUrl: widget.receiver.avatarUrl,
    );

    if (mounted) {
      // Dù có review hay không, khi đóng sheet này ta thoát màn hình chat luôn
      // vì đơn đã hoàn thành và sẽ bị ẩn khỏi danh sách tin nhắn.
      Navigator.pop(context);
    }
  }

  Widget _buildCompletedBanner() {
    if (!_isJobCompleted) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Đơn hàng đã hoàn thành! 🎉',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_hasReviewed)
            GestureDetector(
              onTap: _showReviewSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Đánh giá',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            const Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text(
                  'Đã đánh giá',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label = "Đang xử lý";
    Color color = Colors.grey;

    switch (_sessionStatus) {
      case JobStatus.aiConsulting:
        label = "Tư vấn AI";
        color = Colors.teal;
        break;
      case JobStatus.broadcasting:
        label = "Tìm thợ...";
        color = Colors.blue;
        break;
      case JobStatus.matched:
        label = "Chờ thợ đi";
        color = Colors.orange;
        break;
      case JobStatus.enRoute:
        label = "Thợ đang đến";
        color = Colors.blue;
        break;
      case JobStatus.arrived:
        label = "Thợ đã đến";
        color = Colors.indigo;
        break;
      case JobStatus.inProgress:
        label = "Đang sửa";
        color = Colors.purple;
        break;
      case JobStatus.completed:
        label = "Hoàn thành";
        color = Colors.green;
        break;
      case JobStatus.cancelled:
        label = "Đã hủy";
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showSnackBar(String msg, [Color color = Colors.green]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Đảm bảo có currentUserId trước khi gửi để tránh lỗi duplicate
    if (currentUserId == null) {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        currentUserId = user.id;
      }
    }

    _textController.clear();

    // 1. Cập nhật UI ngay lập tức (Optimistic Update)
    // Tạo một tin nhắn tạm thời để hiển thị ngay
    final temporaryMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch, // ID tạm
      sessionId: widget.sessionId,
      senderId: currentUserId ?? 0,
      type: MessageType.TEXT,
      content: text,
      createdAt: DateTime.now(),
      sender: User(id: currentUserId ?? 0, fullName: 'Tôi', role: 'USER'),
      isRead: false,
    );

    setState(() {
      _messages.insert(0, temporaryMessage);
    });
    _scrollToBottom();

    // 2. Gửi qua Socket
    _socketService.sendMessage(widget.sessionId, text, 'TEXT');
  }

  Future<void> _handlePickMedia({
    required ImageSource source,
    required bool isVideo,
  }) async {
    try {
      XFile? file;
      if (isVideo) {
        // Chỉ chọn video
        file = await _picker.pickVideo(source: source);
      } else {
        // Chỉ chọn ảnh
        file = await _picker.pickImage(source: source, imageQuality: 70);
      }

      if (file == null) return;

      setState(() => _isUploadingMedia = true);

      final filePath = file.path;
      final fileName = file.name;

      // Gọi API Upload qua REST (Multipart)
      final response = await ApiService.uploadChatImage(
        widget.sessionId,
        filePath,
        fileName,
      );

      // Cập nhật UI ngay lập tức với dữ liệu trả về từ Server
      if (response['data'] != null && mounted) {
        final newMessage = ChatMessage.fromJson(response['data']);
        setState(() {
          // Chỉ insert nếu socket chưa kịp insert (tránh trùng lặp)
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.insert(0, newMessage);
          }
          _isUploadingMedia = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isUploadingMedia = false);
      }
    } catch (e) {
      setState(() => _isUploadingMedia = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff081125),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildConnectionBanner(),
            _buildCompletedBanner(), // ← Banner hoàn thành + nút đánh giá
            Expanded(
              child: _isLoadingHistory
                  ? Center(
                      child: CircularProgressIndicator(color: primaryOrange),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        "Bắt đầu cuộc trò chuyện với ${widget.receiver.fullName}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == currentUserId;
                        return _buildMessageBubble(message, isMe);
                      },
                    ),
            ),
            if (_isUploadingMedia)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: primaryOrange,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Đang tải tệp lên...",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            // Nếu đơn hoàn thành → ẩn input, hiện nút đánh giá lớn
            if (_isJobCompleted && !_hasReviewed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _showReviewSheet,
                    icon: const Icon(Icons.star_rounded, color: Colors.white),
                    label: const Text(
                      'ĐÁNH GIÁ CHẤT LƯỢNG THỢ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              )
            else if (!_isJobCompleted)
              _buildBottomInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xff0e1938),
      elevation: 0.5,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primaryOrange.withOpacity(0.1),
            backgroundImage: widget.receiver.avatarUrl != null
                ? NetworkImage(widget.receiver.avatarUrl!)
                : null,
            child: widget.receiver.avatarUrl == null
                ? Text(
                    widget.receiver.fullName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.receiver.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(),
                  ],
                ),
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    color: _connectionStatus == 'Đã kết nối'
                        ? Colors.green
                        : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: primaryOrange),
          onSelected: (value) {
            if (value == 'call') {
              _handleCallTechnician();
            } else if (value == 'cancel') {
              _handleCancelJob();
            } else if (value == 'redispatch') {
              _handleRedispatchJob();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'call',
              child: Row(
                children: [
                  Icon(Icons.call, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Gọi cho thợ'),
                ],
              ),
            ),
            if (_sessionStatus == JobStatus.matched)
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Hủy đơn hàng', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            if (_sessionStatus == JobStatus.matched)
              PopupMenuItem(
                value: 'redispatch',
                enabled:
                    _sessionUpdatedAt == null ||
                    DateTime.now().difference(_sessionUpdatedAt!).inMinutes >=
                        15,
                child: const Row(
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Tìm thợ khác (Đổi thợ)'),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 5),
      ],
    );
  }

  void _handleCallTechnician() async {
    final phone = widget.receiver.phoneNumber;
    if (phone == null) return;
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _handleCancelJob() {
    if (_sessionStatus == JobStatus.enRoute) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("⚠️ Không thể hủy tự động"),
          content: const Text(
            "Thợ đang trên đường di chuyển đến vị trí của bạn. Nếu bạn muốn hủy, vui lòng gọi điện trực tiếp để xác nhận với thợ nhé!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleCallTechnician();
              },
              child: const Text("Gọi điện cho thợ"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận hủy đơn"),
        content: const Text("Bạn có chắc chắn muốn hủy đơn hàng này không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Không"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.cancelJobUser(widget.sessionId);
                if (mounted) {
                  _showSnackBar("Đã hủy đơn hàng thành công!");
                  Navigator.pop(context);
                }
              } catch (e) {
                _showSnackBar("Lỗi: $e", Colors.redAccent);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hủy đơn", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleRedispatchJob() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tìm thợ khác?"),
        content: const Text(
          "Bạn muốn hủy thợ hiện tại và yêu cầu hệ thống tìm thợ khác cho bạn chứ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.redispatchJob(widget.sessionId);
                if (mounted) {
                  _showSnackBar("Đang tìm thợ mới cho bạn...");
                  // Backend sẽ tự động cập nhật status sang BROADCASTING
                }
              } catch (e) {
                _showSnackBar("Lỗi: $e", Colors.redAccent);
              }
            },
            child: const Text("Xác nhận tìm thợ mới"),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    if (_connectionStatus == 'Đã kết nối' ||
        _connectionStatus == 'Đang kết nối...') {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: Colors.red.shade100,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          _connectionStatus,
          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: primaryOrange.withOpacity(0.1),
                    backgroundImage: message.sender?.avatarUrl != null
                        ? NetworkImage(message.sender!.avatarUrl!)
                        : null,
                    child: message.sender?.avatarUrl == null
                        ? Text(
                            (message.sender?.fullName ??
                                    widget.receiver.fullName)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              color: primaryOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              Flexible(
                child: Container(
                  padding: message.type == MessageType.TEXT
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                      : const EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color:
                        message.type == MessageType.IMAGE ||
                            message.type == MessageType.QUOTE_CARD
                        ? Colors.transparent
                        : isMe
                        ? primaryOrange
                        : const Color(0xff1A244D),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 5),
                      bottomRight: Radius.circular(isMe ? 5 : 20),
                    ),
                  ),
                  child: _buildMessageContent(message, isMe),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Hiển thị giờ (vd: 14:35)
          Text(
            DateFormat('HH:mm').format(message.createdAt.toLocal()),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    switch (message.type) {
      case MessageType.TEXT:
        return Text(
          message.content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.3,
          ),
        );
      case MessageType.IMAGE:
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMe ? 15 : 5),
            bottomRight: Radius.circular(isMe ? 5 : 15),
          ),
          child: CachedNetworkImage(
            imageUrl: message.content,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      case MessageType.VIDEO:
        return GestureDetector(
          onTap: () async {
            final url = Uri.parse(message.content);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                _showSnackBar("Không thể mở video", Colors.red);
              }
            }
          },
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(isMe ? 15 : 5),
                bottomRight: Radius.circular(isMe ? 5 : 15),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                SizedBox(height: 8),
                Text(
                  "Video - Nhấn để xem",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      case MessageType.QUOTE_CARD:
        final title = message.metadata?['title'] ?? 'Yêu cầu báo giá';
        final amount = message.metadata?['amount'] ?? 0;
        final quoteStatus = message.metadata?['quoteStatus'];

        return Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: primaryOrange.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: primaryOrange),
                  const SizedBox(width: 8),
                  Text(
                    'YÊU CẦU BÁO GIÁ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryOrange,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text(title, style: const TextStyle(fontSize: 15, height: 1.3)),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryOrange,
                ),
              ),
              const SizedBox(height: 12),
              if (quoteStatus == 'ACCEPTED')
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '✅ Đã chấp nhận báo giá',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else if (quoteStatus == 'REJECTED')
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '❌ Đã từ chối',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else if (!isMe)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showRejectQuoteDialog(
                          context,
                          message.id,
                          title,
                          amount,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showAcceptQuoteDialog(
                          context,
                          message.id,
                          title,
                          amount,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Đồng ý'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
    }
  }

  void _showAcceptQuoteDialog(
    BuildContext context,
    int messageId,
    String title,
    int amount,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Xác nhận báo giá'),
          content: Text(
            'Bạn có chắc chắn muốn chấp nhận báo giá này không?\n\n$title\n${_formatCurrency(amount)}',
          ),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Chấp nhận'),
              onPressed: () async {
                Navigator.of(context).pop(); // Đóng dialog

                try {
                  await ApiService.updateQuoteStatus(messageId, 'ACCEPTED');
                  if (mounted) {
                    _showSnackBar('Đã chấp nhận báo giá thành công!');
                  }
                } catch (e) {
                  if (mounted) {
                    _showSnackBar(
                      e.toString().replaceAll('Exception: ', ''),
                      Colors.red,
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showRejectQuoteDialog(
    BuildContext context,
    int messageId,
    String title,
    int amount,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Từ chối báo giá'),
          content: Text(
            'Bạn có chắc chắn muốn từ chối báo giá này không?\n\n$title\n${_formatCurrency(amount)}',
          ),
          actions: [
            TextButton(
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Từ chối'),
              onPressed: () async {
                Navigator.of(context).pop(); // Đóng dialog

                try {
                  await ApiService.updateQuoteStatus(messageId, 'REJECTED');
                  if (mounted) {
                    _showSnackBar('Đã từ chối báo giá!');
                  }
                } catch (e) {
                  if (mounted) {
                    _showSnackBar(
                      e.toString().replaceAll('Exception: ', ''),
                      Colors.red,
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Tùy chọn đính kèm',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryOrange,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePickMedia(source: ImageSource.camera, isVideo: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.green),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePickMedia(source: ImageSource.gallery, isVideo: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.red),
                title: const Text('Chọn video từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePickMedia(source: ImageSource.gallery, isVideo: true);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xff0e1938)),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle, color: primaryOrange, size: 28),
              onPressed: _isLoadingHistory ? null : _showAttachmentBottomSheet,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSendText(),
                onChanged: (val) {
                  // Text change handler
                },
                decoration: InputDecoration(
                  hintText: 'Nhắn tin...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xff1A244D),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: primaryOrange),
              onPressed: _handleSendText,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }
}
