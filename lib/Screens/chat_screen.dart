import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../models/diagnosis_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import '../Widgets/custom_loading_button.dart';
import '../Widgets/booking_bottom_sheet.dart';

// ─── Design Tokens (Đồng bộ với Home) ─────────────────────────────
const _kBgColor = Color(0xff081125);
const _kCardColor = Color(0xff111B3D);
const _kUserBubbleColor = Color(0xff1A244D);
const _kAccentColor = Color(0xff00E676);
const _kSecondaryColor = Color(0xff00B0FF);
const _kTextColor = Colors.white;
const _kSubTextColor = Color(0xff9EA9C1);

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Uint8List? imageBytes;
  final Map<String, dynamic>? state;
  final int? sessionId;
  final int? logId;
  String? feedback;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.imageBytes,
    this.state,
    this.sessionId,
    this.logId,
    this.feedback,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final String? initialDevice;
  final String? initialQuery;
  final int? sessionId;

  const ChatScreen({super.key, this.initialDevice, this.initialQuery, this.sessionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isBooking = false;
  bool _bannerDismissed = false;
  bool _isChatLocked = false;
  int? _currentSessionId;

  DiagnosisContext _diagnosisCtx = const DiagnosisContext();
  bool _isRedAlert = false;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;

  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    
    // ➕ Gán sessionId truyền từ Home sang biến nội bộ của ChatScreen
    _currentSessionId = widget.sessionId;

    if (_currentSessionId != null) {
      // 🟢 NẾU CÓ SESSION CŨ: Load lại lịch sử từ Backend
      _loadChatHistory(); 
    } else {
      // 🟢 NẾU LÀ SESSION MỚI (Bấm từ nút Thêm hoặc nút Đặt thợ gốc)
      if (widget.initialDevice != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _textController.text =
              "Thiết bị ${widget.initialDevice} nhà tôi đang gặp sự cố, bạn tư vấn giúp tôi nhé.";
          _handleSend(); // <-- Gửi câu này lên NestJS, NestJS sẽ tự tạo session và lấy câu này làm `symptom`
        });
      } else if (widget.initialQuery != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _textController.text = widget.initialQuery!;
          _handleSend();
        });
      } else {
        _messages.add(
          ChatMessage(
            text:
                "Chào bạn! Mình là **SmartElec**. Thiết bị nhà bạn đang gặp sự cố gì?",
            isUser: false,
          ),
        );
      }
    }
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);
    try {
      // Sử dụng hàm getChatMessages có sẵn trong api_service.dart của bạn
      final logs = await ApiService.getChatMessages(_currentSessionId!);
      
      if (mounted) {
        setState(() {
          _messages.clear(); // Xóa tin nhắn mặc định
          for (var log in logs) {
            _messages.add(ChatMessage(
              text: log['message'] ?? log['content'] ?? '', // Phụ thuộc vào key trả về từ NestJS
              isUser: log['sender'] == 'USER' || log['role'] == 'user',
              timestamp: log['createdAt'] != null ? DateTime.parse(log['createdAt']) : DateTime.now(),
              sessionId: _currentSessionId,
            ));
          }
          // (Tùy chọn) Gán lại deviceType và symptom vào thẻ trạng thái ở trên cùng
          if (widget.initialDevice != null) {
             _diagnosisCtx = _diagnosisCtx.copyWith(deviceType: widget.initialDevice);
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tải lịch sử chat: $e")));
      }
    }
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() {});
    } catch (e) {}
  }

  void _toggleListening() async {
    if (_isChatLocked) return;
    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      FocusScope.of(context).unfocus();
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _textController.text = result.recognizedWords);
          }
        },
        localeId: 'vi_VN',
      );
      if (mounted) setState(() => _isListening = true);
    }
  }

  Future<void> _pickImage() async {
    if (_isChatLocked) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) setState(() => _selectedImageBytes = bytes);
      }
    } catch (e) {}
  }

  void _updateState(Map<String, dynamic> response) {
    if (response['state'] != null) {
      final s = response['state'];
      setState(() {
        _diagnosisCtx = _diagnosisCtx.copyWith(
          deviceType: s['device'],
          symptom: s['symptom'],
          situationContext: s['ctx'],
          phase: s['phase'] == 'DIAGNOSING'
              ? DiagnosisPhase.diagnosing
              : DiagnosisPhase.collecting,
          riskLevel: _parseRisk(s['risk']),
          askedQuestions: List<String>.from(s['asked'] ?? []),
          dangerFlags: List<String>.from(s['flags'] ?? []),
        );
        _isRedAlert =
            _diagnosisCtx.riskLevel == RiskLevel.red ||
            _diagnosisCtx.dangerFlags.isNotEmpty;
        if (_isRedAlert) _bannerDismissed = false;
      });
    }
  }

  RiskLevel _parseRisk(String? value) {
    switch (value) {
      case 'RED':
        return RiskLevel.red;
      case 'YELLOW':
        return RiskLevel.yellow;
      case 'GREEN':
        return RiskLevel.green;
      default:
        return RiskLevel.unknown;
    }
  }

  Color _getThemeColor() {
    switch (_diagnosisCtx.riskLevel) {
      case RiskLevel.red:
        return Colors.redAccent;
      case RiskLevel.yellow:
        return Colors.orangeAccent;
      case RiskLevel.green:
        return _kAccentColor;
      default:
        return _kSecondaryColor;
    }
  }

  Color _getBgColor() {
    switch (_diagnosisCtx.riskLevel) {
      case RiskLevel.red:
        return const Color(0xff2A0808); // Nền đỏ đen ngầm cảnh báo
      default:
        return _kBgColor; // Trả về màu nền mặc định 0xff081125
    }
  }

  Future<void> _handleSend() async {
    if (_isChatLocked) return;
    final text = _textController.text.trim();
    final imageToSend = _selectedImageBytes;
    if ((text.isEmpty && imageToSend == null) || _isLoading) return;
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }

    final history = _getHistoryForAi();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, imageBytes: imageToSend),
      );
      _isLoading = true;
      _selectedImageBytes = null;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      String? imageBase64;
      if (imageToSend != null) imageBase64 = base64Encode(imageToSend);
      
      // ✅ THAY ĐỔI: Truyền thêm _currentSessionId vào tham số của API (Cần check/sửa file api_service.dart nếu nó chưa hỗ trợ nhận đối số này)
      final response = await ApiService.sendChatMessage(
        text,
        imageBase64: imageBase64,
        history: history,
        sessionId: _currentSessionId, // <-- Truyền sessionId hiện tại lên Backend
      );

      debugPrint("👉 RESPONSE TỪ CHAT AI: $response");
      
      _updateState(response);

      if (mounted) {
        setState(() {
          // ✅ CẬP NHẬT: Lưu lại sessionId do Backend trả về cho các lượt chat sau
          if (response['sessionId'] != null) {
            _currentSessionId = response['sessionId'] is int 
                ? response['sessionId'] 
                : int.tryParse(response['sessionId'].toString());
          }

          _messages.add(
            ChatMessage(
              text: response['text'],
              isUser: false,
              state: {
                ...(response['state'] ?? {}),
                // Bơm thêm cờ này vào state của tin nhắn để phục vụ render UI ở Phần 1
                'is_booking_triggered': response['is_booking_triggered'], 
              },
              sessionId: _currentSessionId, // <-- Gán session ID mới cập nhật vào đây
              logId: response['logId'] is int ? response['logId'] : null,
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: "⚠️ Lỗi: $e", isUser: false));
          _isLoading = false;
        });
      }
    }
    _scrollToBottom();
  }

  Future<void> _handleBooking(int? sessionId) async {
    if (sessionId == null || _isBooking) return;

    // Hiển thị Phiếu điền thông tin (Bottom Sheet) trực tiếp
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép sheet cuộn lên khi có bàn phím
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingBottomSheet(
        sessionId: sessionId,
        deviceType: _diagnosisCtx.deviceType,
        symptom: _diagnosisCtx.symptom,
        onConfirm: (bookingData) async {
          setState(() => _isBooking = true);
          try {
            await ApiService.bookTechnician(sessionId, bookingData);
            if (mounted) {
              setState(() {
                _isBooking = false;
                _isChatLocked = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "✅ Đã chốt đơn! Hệ thống đang phát sóng tìm thợ quanh khu vực của bạn.",
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isBooking = false);
            }
            rethrow;
          }
        },
      ),
    );
  }

  Future<void> _handleFeedback(ChatMessage msg, String type) async {
    if (msg.feedback == type) {
      setState(() => msg.feedback = null);
      return;
    }
    setState(() => msg.feedback = type);
    if (msg.logId == null) return;
    ApiService.submitAiFeedback(logId: msg.logId!, feedback: type);
  }

  List<Map<String, String>> _getHistoryForAi() {
    final history = _messages
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'content': m.text})
        .toList();
    while (history.isNotEmpty && history.first['role'] == 'model') {
      history.removeAt(0);
    }
    return history;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetSession() {
    setState(() {
      _currentSessionId = null;
      _diagnosisCtx = const DiagnosisContext();
      _isRedAlert = false;
      _messages.clear();
      _bannerDismissed = false;
      _isChatLocked = false;
      _isBooking = false;
      _messages.add(
        ChatMessage(
          text:
              "Đã reset phiên chẩn đoán. Bạn cần SmartElec hỗ trợ thiết bị nào?",
          isUser: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildContextCard() {
    final ctx = _diagnosisCtx;
    if (ctx.deviceType == null && ctx.symptom == null) {
      return const SizedBox.shrink();
    }

    final themeColor = _getThemeColor();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRedAlert ? Icons.warning_rounded : Icons.memory_rounded,
              color: themeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.deviceType ?? "Đang xác định thiết bị...",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _kTextColor,
                  ),
                ),
                if (ctx.symptom != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    ctx.symptom!,
                    style: const TextStyle(color: _kSubTextColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColor.withOpacity(0.3)),
            ),
            child: Text(
              ctx.phase == DiagnosisPhase.diagnosing ? "Chẩn đoán" : "Thu thập",
              style: TextStyle(
                color: themeColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRedAlert && !_bannerDismissed) HapticFeedback.heavyImpact();
    return Scaffold(
      backgroundColor: _getBgColor(),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // 🔔 Biểu ngữ Cảnh báo & Thẻ trạng thái luôn được ghim cố định ở đầu màn hình
            if (_isRedAlert && !_bannerDismissed) _buildRedAlertBanner(),
            _buildContextCard(),

            Expanded(
              child: RefreshIndicator(
                color: Colors.blueAccent,
                onRefresh: () async {
                  _resetSession();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    const SizedBox(height: 8),
                    if (_messages.isEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: _buildEmptyState(),
                      )
                    else
                      ..._messages.map((m) => _buildMessageBubble(m)),
                    if (_isLoading) _buildTypingIndicator(),
                  ],
                ),
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kBgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.white.withOpacity(0.05)),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_kAccentColor, _kSecondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: _kAccentColor.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SmartElec",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "AI Chẩn đoán thiết bị",
                style: TextStyle(color: _kSubTextColor, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _kSubTextColor),
          tooltip: "Reset phiên",
          onPressed: _resetSession,
        ),
      ],
    );
  }

  Widget _buildRedAlertBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CẢNH BÁO NGUY HIỂM',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Phát hiện rủi ro cao — Ngắt điện ngay lập tức!',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _bannerDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final state = msg.state;
   final isReadyToBook = state != null && (
    state['phase'] == 'READY_TO_BOOK' || 
    state['is_booking_triggered'] == true || 
    state['risk'] == 'RED'
     );
    final isRedRisk = state != null && state['risk'] == 'RED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_kAccentColor, _kSecondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? _kUserBubbleColor : _kCardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isRedRisk
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (msg.imageBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            msg.imageBytes!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (msg.text.isNotEmpty) const SizedBox(height: 10),
                      ],
                      if (msg.text.isNotEmpty)
                        MarkdownBody(
                          data: msg.text,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              height: 1.5,
                            ),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            listBullet: const TextStyle(color: _kAccentColor),
                            blockquoteDecoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                left: BorderSide(
                                  color: Colors.orangeAccent,
                                  width: 3,
                                ),
                              ),
                            ),
                            blockquote: const TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isUser) const SizedBox(width: 32),
            ],
          ),
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReadyToBook && !_isChatLocked) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: CustomLoadingButton(
                            text: "Đặt thợ ngay",
                            isLoading: _isBooking,
                            onPressed: () => _handleBooking(msg.sessionId),
                            height: 45,
                            borderRadius: 12,
                            gradientColors: [
                              Colors.green,
                              Colors.green.shade700,
                            ],
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _isBooking ? null : () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Thôi",
                            style: TextStyle(
                              color: _kSubTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      _buildFeedbackButton(
                        Icons.thumb_up_alt_outlined,
                        _kAccentColor,
                        msg.feedback == 'like',
                        () => _handleFeedback(msg, 'like'),
                      ),
                      const SizedBox(width: 8),
                      _buildFeedbackButton(
                        Icons.thumb_down_alt_outlined,
                        Colors.redAccent,
                        msg.feedback == 'dislike',
                        () => _handleFeedback(msg, 'dislike'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackButton(
    IconData icon,
    Color activeColor,
    bool isActive,
    VoidCallback onTap,
  ) {
    final color = isActive ? activeColor : _kSubTextColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isActive ? color : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isActive
              ? (icon == Icons.thumb_up_alt_outlined
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_down_alt_rounded)
              : icon,
          size: 14,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_kAccentColor, _kSecondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kCardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const _AnimatedTypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 48,
              color: _kSubTextColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "SmartElec sẵn sàng hỗ trợ",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Mô tả tình trạng hoặc gửi ảnh thiết bị",
            style: TextStyle(color: _kSubTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kBgColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImageBytes != null)
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12, left: 46),
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kAccentColor.withOpacity(0.5)),
                      image: DecorationImage(
                        image: MemoryImage(_selectedImageBytes!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImageBytes = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _kBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cancel_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 12),
                  child: GestureDetector(
                    onTap: _isChatLocked || _isLoading ? null : _pickImage,
                    child: Icon(
                      Icons.image_rounded,
                      color: _isChatLocked ? Colors.white24 : _kSubTextColor,
                      size: 28,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kCardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isListening
                            ? Colors.redAccent.withOpacity(0.5)
                            : Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            enabled: !_isChatLocked,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSend(),
                            minLines: 1,
                            maxLines: 5,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: _isChatLocked
                                  ? "Hệ thống đang tìm thợ..."
                                  : "Nhắn tin hoặc gửi ảnh...",
                              hintStyle: const TextStyle(
                                color: Colors.white30,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isChatLocked || !_speechEnabled
                              ? null
                              : _toggleListening,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: _isChatLocked
                                  ? Colors.white24
                                  : (_isListening
                                        ? Colors.redAccent
                                        : _kSubTextColor),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isChatLocked || _isLoading ? null : _handleSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: _isChatLocked || _isLoading
                          ? null
                          : const LinearGradient(
                              colors: [_kAccentColor, _kSecondaryColor],
                            ),
                      color: _isChatLocked || _isLoading ? _kCardColor : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _isLoading
                            ? Icons.hourglass_top_rounded
                            : Icons.send_rounded,
                        color: _isChatLocked || _isLoading
                            ? Colors.white30
                            : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();
  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _animations = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -6,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Đang phân tích",
          style: TextStyle(
            color: _kSubTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: _kAccentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
