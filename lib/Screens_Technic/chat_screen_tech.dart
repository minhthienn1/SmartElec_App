import 'package:flutter/material.dart';
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
import '../Widgets/quote_bottom_sheet.dart';
import '../core/constants/job_status.dart';

class TechChatScreen extends StatefulWidget {
  final int sessionId;
  final User receiver; // Khách hàng

  const TechChatScreen({
    super.key,
    required this.sessionId,
    required this.receiver,
  });

  @override
  _TechChatScreenState createState() => _TechChatScreenState();
}

class _TechChatScreenState extends State<TechChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryBlue = const Color(0xFF1565C0);
  final ImagePicker _picker = ImagePicker();

  late ChatSocketService _socketService;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _quoteSubscription;

  int? currentUserId;
  bool _isLoadingHistory = true;
  bool _isUploadingMedia = false;
  String _connectionStatus = 'Đang kết nối...';
  String _sessionStatus = JobStatus.matched; // Mặc định là vừa nhận đơn

  final List<ChatMessage> _messages = [];
  StreamSubscription? _statusSubscription;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null) {
      setState(() => currentUserId = user.id);
    }

    if (currentUserId == null) {
      debugPrint(
        "❌ CRITICAL: currentUserId không xác định được. UserProvider chưa được initialize!",
      );
      return;
    }

    try {
      final session = await ApiService.getSessionById(widget.sessionId);
      if (mounted) {
        setState(() {
          _sessionStatus = session.status;
        });
        if (session.status == JobStatus.cancelled) {
          _showCancelledDialog();
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải thông tin phiên chat: $e");
    }

    await _loadChatHistory();
    ApiService().markAllAsRead(widget.sessionId);

    _socketService = ChatSocketService();

    _connectionSubscription = _socketService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() => _connectionStatus = status);
        if (status == 'Đã kết nối lại') {
          debugPrint('♻️ Bắt được event RECONNECT, tải lại lịch sử...');
          _loadChatHistory();
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
            newMessage.sender?.role == 'TECHNICIAN';

        setState(() {
          // Xóa tin tạm nếu có
          if (isFromMe) {
            final tempIndex = _messages.indexWhere(
              (m) =>
                  m.id > 1000000 &&
                  m.content.trim() == newMessage.content.trim(),
            );
            if (tempIndex != -1) {
              _messages.removeAt(tempIndex);
            }
          }

          // Thêm tin thật nếu chưa có
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.insert(0, newMessage);

            // TỰ ĐỘNG ĐÁNH DẤU ĐÃ ĐỌC KHI ĐANG TRONG TRANG CHAT
            if (!isFromMe) {
              ApiService().markAsRead(newMessage.id);
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
            if (_messages[index].metadata != null) {
              _messages[index].metadata!['quoteStatus'] = status;
            } else {
              _messages[index].metadata = {'quoteStatus': status};
            }
          }
        });
      }
    });

    _statusSubscription = _socketService.onJobStatusChanged.listen((data) {
      if (mounted &&
          data['sessionId']?.toString() == widget.sessionId.toString()) {
        setState(() => _sessionStatus = data['status']);
        if (data['status'] == JobStatus.cancelled) {
          _showCancelledDialog();
        }
      }
    });

    await _socketService.connect(widget.sessionId);
  }

  Future<void> _loadChatHistory() async {
    try {
      final rawData = await ApiService.getChatMessages(widget.sessionId);
      if (mounted) {
        setState(() {
          final parsed = rawData.map((e) => ChatMessage.fromJson(e)).toList();
          _messages.addAll(parsed.reversed);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _quoteSubscription?.cancel();
    _statusSubscription?.cancel();
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

  Future<void> _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Đảm bảo có currentUserId trước khi gửi
    if (currentUserId == null) {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        currentUserId = user.id;
      }
    }

    _textController.clear();

    final tempMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      sessionId: widget.sessionId,
      senderId: currentUserId ?? 0,
      type: MessageType.TEXT,
      content: text,
      createdAt: DateTime.now(),
      sender: User(id: currentUserId ?? 0, fullName: 'Tôi', role: 'TECHNICIAN'),
      isRead: false,
    );

    setState(() => _messages.insert(0, tempMsg));
    _scrollToBottom();
    _socketService.sendMessage(widget.sessionId, text, 'TEXT');
  }

  void _showQuoteForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuoteBottomSheet(sessionId: widget.sessionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _buildMessageBubble(_messages[index]),
                    ),
            ),
            if (_isUploadingMedia)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Đang tải tệp lên...",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            _buildStateActionBanner(),
            if (_sessionStatus != JobStatus.completed && _sessionStatus != JobStatus.cancelled)
              _buildBottomInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label = "Đang xử lý";
    Color color = Colors.grey;

    switch (_sessionStatus) {
      case JobStatus.matched:
        label = "Chờ di chuyển";
        color = Colors.orange;
        break;
      case JobStatus.enRoute:
        label = "Đang đến";
        color = Colors.blue;
        break;
      case JobStatus.arrived:
        label = "Đã đến nơi";
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // Ngăn Android 12+ ám màu
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey.shade200, height: 1.0), // Đường viền dưới mỏng, tinh tế
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primaryBlue.withOpacity(0.1),
            backgroundImage: widget.receiver.avatarUrl != null
                ? NetworkImage(widget.receiver.avatarUrl!)
                : null,
            child: widget.receiver.avatarUrl == null
                ? Icon(Icons.person, color: primaryBlue)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.receiver.fullName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isProcessing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                    else
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onSelected: (value) async {
            if (value == 'call') {
              _handleCallCustomer();
            } else if (value == 'cancel') {
              _handleCancelJob();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'call',
              child: Row(
                children: [
                  Icon(Icons.call, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Gọi cho khách'),
                ],
              ),
            ),
            if (_sessionStatus == JobStatus.matched ||
                _sessionStatus == JobStatus.enRoute ||
                _sessionStatus == JobStatus.inProgress ||
                _sessionStatus == JobStatus.arrived)
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Hủy đơn',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 5),
      ],
    );
  }

  void _handleCallCustomer() async {
    final phone = widget.receiver.phoneNumber;
    if (phone == null) return;
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _showCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          "🛑 ĐƠN HÀNG ĐÃ BỊ HỦY",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Khách hàng đã hủy đơn hàng này. Vui lòng không di chuyển đến vị trí khách hàng nữa.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Thoát trang chat
            },
            child: const Text("Xác nhận và Quay lại"),
          ),
        ],
      ),
    );
  }

  void _showCompleteJobDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1A244D),
        title: const Text('Xác nhận hoàn thành', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn đã sửa chữa xong và muốn hoàn thành công việc này?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Đóng dialog
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context); // 1. Đóng hộp thoại xác nhận ngay lập tức
              
              if (_isProcessing) return;
              setState(() => _isProcessing = true);
              
              try {
                // 2. Gọi API hoàn thành công việc
                await ApiService.completeJob(widget.sessionId);
                
                if (mounted) {
                  // 3. Thông báo thành công nhanh
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã hoàn thành công việc!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // 4. ĐÁ RA NGOÀI NGAY LẬP TỨC (Không dùng Future.delayed nữa)
                  // Truyền kèm giá trị 'true' để báo hiệu cho màn hình ngoài biết là đã đổi trạng thái
                  Navigator.pop(context, true); 
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Hoàn thành', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleCancelJob() async {
    if (_isProcessing) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận hủy đơn"),
        content: const Text(
          "Bạn có chắc chắn muốn hủy (từ bỏ) đơn hàng này không? Đơn sẽ được chuyển lại cho thợ khác.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Quay lại"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Xác nhận hủy",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await ApiService.cancelJobTech(widget.sessionId);
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Đã hủy đơn hàng thành công."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Lỗi mạng khi hủy đơn: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == currentUserId;
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
                    backgroundColor: const Color(0xFF1565C0).withOpacity(0.1), // Cập nhật: Nền avatar xanh nhạt
                    backgroundImage: message.sender?.avatarUrl != null
                        ? NetworkImage(message.sender!.avatarUrl!)
                        : null,
                    child: message.sender?.avatarUrl == null
                        ? Text(
                            (message.sender?.fullName ??
                                    widget.receiver.fullName)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF1565C0), // Cập nhật: Chữ avatar màu xanh
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
                            ? const Color(0xFF1565C0) // Cập nhật: Tin nhắn của thợ màu xanh
                            : Colors.white, // Cập nhật: Tin nhắn của khách màu trắng
                    border: message.type == MessageType.TEXT && !isMe
                        ? Border.all(color: Colors.grey.withOpacity(0.2)) // Cập nhật: Viền xám rất nhạt
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 5),
                      bottomRight: Radius.circular(isMe ? 5 : 20),
                    ),
                    boxShadow: !isMe && message.type == MessageType.TEXT ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05), // Cập nhật: Đổ bóng đậm hơn một chút
                        blurRadius: 8, 
                        offset: const Offset(0, 2)
                      )
                    ] : [],
                  ),
                  child: _buildMessageContent(message, isMe),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
          style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
        );
      case MessageType.IMAGE:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message.content,
            width: 220,
            placeholder: (context, url) => const CircularProgressIndicator(),
          ),
        );
      case MessageType.VIDEO:
        return GestureDetector(
          onTap: () async {
            final url = Uri.parse(message.content);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(15),
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
        return _buildQuoteCard(message.metadata ?? {}, isMe);
    }
  }

  Widget _buildQuoteCard(Map<String, dynamic> metadata, bool isMe) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final status = metadata['quoteStatus'];
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1A244D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'BÁO GIÁ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Text(
            metadata['title'] ?? 'Dịch vụ',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(metadata['amount'] ?? 0),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          if (status == 'ACCEPTED')
            const Center(
              child: Text(
                "✅ Đã chấp nhận",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (status == 'REJECTED')
            const Center(
              child: Text(
                "❌ Bị từ chối",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Center(
              child: Text(
                "⏳ Đang chờ duyệt...",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // 1. Hàm kiểm tra trạng thái báo giá mới nhất
  String? _getLatestQuoteStatus() {
    try {
      // Tìm tất cả tin nhắn báo giá
      final quotes = _messages.where((m) => m.type == MessageType.QUOTE_CARD).toList();
      if (quotes.isEmpty) return null;
      // Do _messages đang sort reverse (tin mới nhất ở index 0), ta lấy phần tử đầu tiên
      final latestQuote = quotes.first;
      return latestQuote.metadata?['quoteStatus']; // Trả về 'ACCEPTED', 'REJECTED', hoặc null
    } catch (e) {
      return null;
    }
  }

  // 2. Hàm gọi API chuyển trạng thái sang Đang sửa (IN_PROGRESS)
  void _handleStartRepair() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      // Bạn cần viết thêm hàm startRepair này trong ApiService nhé
      await ApiService.startRepair(widget.sessionId); 
      if (mounted) {
        setState(() {
          _sessionStatus = JobStatus.inProgress;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Lỗi mạng: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStateActionBanner() {
    if (_sessionStatus == JobStatus.completed || _sessionStatus == JobStatus.cancelled) {
      return const SizedBox.shrink(); 
    }

    String buttonText = "";
    IconData buttonIcon = Icons.arrow_forward_rounded; 
    Color buttonColor = const Color(0xFF1565C0);
    VoidCallback? onPressed;

    final latestQuoteStatus = _getLatestQuoteStatus();

    switch (_sessionStatus) {
      case JobStatus.matched:
        buttonText = "Bắt đầu di chuyển";
        buttonIcon = Icons.directions_car_rounded;
        buttonColor = primaryBlue;
        onPressed = () async {
          if (_isProcessing) return;
          setState(() => _isProcessing = true);
          try {
            await ApiService.startEnRoute(widget.sessionId);
            if (mounted) setState(() { _sessionStatus = JobStatus.enRoute; _isProcessing = false; });
          } catch (e) {
            if (mounted) setState(() => _isProcessing = false);
          }
        };
        break;

      case JobStatus.enRoute:
        buttonText = "Đã tới nơi";
        buttonIcon = Icons.location_on_rounded;
        buttonColor = const Color(0xFF0284C7);// Xanh dương chủ đạo
        onPressed = () async {
          if (_isProcessing) return;
          setState(() => _isProcessing = true);
          try {
            await ApiService.confirmArrival(widget.sessionId);
            if (mounted) setState(() { _sessionStatus = JobStatus.arrived; _isProcessing = false; });
          } catch (e) {
            if (mounted) setState(() => _isProcessing = false);
          }
        };
        break;

      case JobStatus.arrived:
        if (latestQuoteStatus == null) {
          buttonText = "TẠO VÀ GỬI BÁO GIÁ";
          buttonIcon = Icons.request_quote_rounded;
          buttonColor = const Color(0xFF0D9488); 
          onPressed = _showQuoteForm;
        } else if (latestQuoteStatus == 'REJECTED') {
          buttonText = "KHÁCH TỪ CHỐI - BÁO GIÁ LẠI";
          buttonIcon = Icons.refresh_rounded;
          buttonColor = const Color(0xFFE53935); 
          onPressed = _showQuoteForm;
        } else if (latestQuoteStatus == 'ACCEPTED') {
          buttonText = "BẮT ĐẦU SỬA CHỮA";
          buttonIcon = Icons.build_circle_rounded;
          buttonColor = const Color(0xFF7C3AED); 
          onPressed = _handleStartRepair;
        } else {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.amber.shade200, width: 1)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706))),
                SizedBox(width: 10),
                Text(
                  "Đang chờ khách duyệt báo giá...", 
                  style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13)
                ),
              ],
            ),
          );
        }
        break;

      case JobStatus.inProgress:
        buttonText = "HOÀN THÀNH CÔNG VIỆC";
        buttonIcon = Icons.check_circle_rounded;
        buttonColor = const Color(0xFF10B981); 
        onPressed = _showCompleteJobDialog;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // Nền trắng chuẩn theme
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea( 
        top: false,
        child: SizedBox(
          height: 48, 
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : onPressed,
            icon: _isProcessing 
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: buttonColor, strokeWidth: 2.5)) 
              : Icon(buttonIcon, color: buttonColor, size: 20), 
            label: Text(
              buttonText,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: buttonColor), 
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor.withOpacity(0.1), 
              elevation: 0, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Đổ bóng đồng bộ với bên khách
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ]
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle, color: primaryBlue, size: 28),
              onPressed: _showAttachmentMenu,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8), // Màu nền hơi ngả xanh rất hợp với theme Thợ
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryBlue.withOpacity(0.15), width: 1.5),
                ),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Nhập tin nhắn...",
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _handleSendText(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.send_rounded, color: primaryBlue, size: 28),
              onPressed: _handleSendText,
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Chụp ảnh"),
              onTap: () => _handlePickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.green),
              title: const Text("Thư viện ảnh"),
              onTap: () => _handlePickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePickImage(ImageSource source) async {
    Navigator.pop(context);
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (file != null) {
      if (mounted) setState(() => _isUploadingMedia = true);
      try {
        final response = await ApiService.uploadChatImage(
          widget.sessionId,
          file.path,
          file.name,
        );

        if (response['data'] != null && mounted) {
          final newMessage = ChatMessage.fromJson(response['data']);
          setState(() {
            if (!_messages.any((m) => m.id == newMessage.id)) {
              _messages.insert(0, newMessage);
            }
            _isUploadingMedia = false;
          });
          _scrollToBottom();
        } else {
          if (mounted) setState(() => _isUploadingMedia = false);
        }
      } catch (e) {
        if (mounted) setState(() => _isUploadingMedia = false);
        debugPrint("Lỗi upload ảnh: $e");
      }
    }
  }
}
