import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/api_service.dart';
import 'tech_ai_history_screen.dart';
import 'tech_color.dart';

// ─── Design Tokens (xanh dương lịch sự, không neon) ─────────────────────────
class TechAiColors {
  static const Color primary = TechColors.primary;
  static const Color navy = TechColors.navy;
  static const Color background = Color(0xFFF8FAFF); // Nền trắng xanh nhạt
  static const Color surface = Color(0xFFF0F4FC);
  static const Color inputBg = Color(0xFFEEF3FB); // Input nhạt hơn
  static const Color bubbleAi = Color(0xFFEFF6FF); // Bubble AI xanh nhạt
  static const Color bubbleUser = Color(0xFF1A56D6);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color accentBlue = Color(0xFF2563EB); // Xanh dương chuẩn
  static const Color chipBg = Color(0xFFDBEAFE);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color sendBtn = Color(0xFF1D4ED8);
}

class TechChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Uint8List? imageBytes;
  String? topic;

  TechChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.imageBytes,
    this.topic,
  }) : timestamp = timestamp ?? DateTime.now();
}

// Quick actions removed as requested

// ════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════════════════════
class TechAiChatScreen extends StatefulWidget {
  final String? initialQuery;
  final int? techSessionId; // session ID từ server nếu có

  const TechAiChatScreen({super.key, this.initialQuery, this.techSessionId});

  @override
  State<TechAiChatScreen> createState() => _TechAiChatScreenState();
}

class _TechAiChatScreenState extends State<TechAiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TechChatMessage> _messages = [];
  bool _isLoading = false;
  int? _currentTechSessionId;

  // ─── Session end state ────────────────────────────────────────────────────
  bool _sessionEnded = false;
  bool _showRatingPanel = false;
  bool _ratingSubmitted = false;
  int _ratingStars = 0;
  final TextEditingController _ratingCommentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;

  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  late AnimationController _typingController;
  late Animation<double> _typingAnimation;

  // Từ khóa thợ muốn kết thúc
  static const _endKeywords = [
    'không', 'ko', 'thôi', 'xong', 'ổn rồi', 'cảm ơn', 'ok', 'okay',
    'không cần', 'đủ rồi', 'tạm được', 'hiểu rồi', 'đã hiểu',
  ];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _typingAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );

    _initSpeech();
    _currentTechSessionId = widget.techSessionId;

    // KHÔNG thêm tin nhắn chào lên đầu — chỉ show QuickChips + trả lời ở dưới
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textController.text = widget.initialQuery!;
        _handleSend();
      });
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
    if (_sessionEnded) return;
    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      FocusScope.of(context).unfocus();
      await _speechToText.listen(
        onResult: (result) {
          if (mounted && !_isLoading) {
            setState(() => _textController.text = result.recognizedWords);
          }
        },
        localeId: 'vi_VN',
      );
      if (mounted) setState(() => _isListening = true);
    }
  }

  Future<void> _pickImage() async {
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

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) setState(() => _selectedImageBytes = bytes);
      }
    } catch (e) {}
  }

  List<Map<String, String>> _getHistoryForAi() {
    return _messages
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'content': m.text})
        .toList();
  }

  /// Kiểm tra xem thợ có muốn kết thúc phiên không
  bool _isEndIntent(String text) {
    final lower = text.toLowerCase().trim();
    return _endKeywords.any((kw) => lower == kw || lower.startsWith('$kw ') || lower.endsWith(' $kw'));
  }

  Future<void> _handleSend() async {
    if (_sessionEnded) return;
    final text = _textController.text.trim();
    final imageToSend = _selectedImageBytes;
    if ((text.isEmpty && imageToSend == null) || _isLoading) return;

    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    }

    // Kiểm tra intent kết thúc từ thợ
    final bool wantsToEnd = _isEndIntent(text) && _messages.isNotEmpty;

    final history = _getHistoryForAi();
    setState(() {
      _isLoading = true;
      _selectedImageBytes = null;
      _messages.add(TechChatMessage(
        text: text,
        isUser: true,
        imageBytes: imageToSend,
      ));
    });
    _textController.clear();
    _scrollToBottom();

    try {
      String? imageBase64;
      if (imageToSend != null) imageBase64 = base64Encode(imageToSend);

      if (wantsToEnd) {
        // AI hỏi xác nhận kết thúc
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _messages.add(TechChatMessage(
              text: 'Bạn có muốn kết thúc phiên hỗ trợ này không? Nếu còn thắc mắc kỹ thuật thêm, cứ nhắn tôi nhé! 😊',
              isUser: false,
            ));
            _isLoading = false;
          });
          _scrollToBottom();
          // Lần sau nếu thợ vẫn đồng ý → trigger end
          _checkAndTriggerSessionEnd(text);
        }
        return;
      }

      final response = await ApiService.sendTechChatMessage(
        text,
        imageBase64: imageBase64,
        history: history,
      );

      if (mounted) {
        final aiText = response['text'] ?? 'Không có phản hồi.';
        setState(() {
          _messages.add(TechChatMessage(
            text: aiText,
            isUser: false,
            topic: response['techState']?['topic'],
          ));
          // Lưu sessionId nếu backend trả về
          if (response['sessionId'] != null) {
            _currentTechSessionId = response['sessionId'] is int
                ? response['sessionId']
                : int.tryParse(response['sessionId'].toString());
          }
          _isLoading = false;
        });
        _scrollToBottom();
        if (response['is_finished'] == true && response['logId'] != null) {
          // Delay nhẹ để người dùng đọc được câu trả lời cuối của AI rồi mới Pop up
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) _showRatingDialog(response['logId']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(TechChatMessage(
            text: '⚠️ Lỗi kết nối: $e\n\nVui lòng thử lại sau vài giây.',
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    }
  }

  /// Kiểm tra xem trước đó AI đã hỏi "còn cần không" chưa, nếu thợ xác nhận → kết thúc
  void _checkAndTriggerSessionEnd(String userReply) {
    if (_messages.length < 2) return;
    final prevAi = _messages.reversed.skip(1).firstWhere(
      (m) => !m.isUser,
      orElse: () => TechChatMessage(text: '', isUser: false),
    );
    if (prevAi.text.contains('kết thúc phiên hỗ trợ')) {
      final lower = userReply.toLowerCase().trim();
      if (_endKeywords.any((kw) => lower == kw || lower.contains(kw))) {
        _triggerSessionEnd();
      }
    }
  }

  void _triggerSessionEnd() {
    setState(() {
      _sessionEnded = true;
      _messages.add(TechChatMessage(
        text: '✅ **Phiên hỗ trợ kỹ thuật đã kết thúc.**\n\nCảm ơn bạn đã sử dụng SmartElec Pro! Chúc bạn sửa thành công! 🔧',
        isUser: false,
      ));
      _showRatingPanel = true;
    });
    _scrollToBottom();
  }

// Quick action handler removed

  void _clearChat() {
    setState(() {
      _messages.clear();
      _sessionEnded = false;
      _showRatingPanel = false;
      _ratingSubmitted = false;
      _ratingStars = 0;
      _ratingCommentController.clear();
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã sao chép nội dung'),
        backgroundColor: TechAiColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _typingController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _ratingCommentController.dispose();
    _speechToText.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechAiColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeView()
                : _buildMessageList(),
          ),
          if (_selectedImageBytes != null) _buildImagePreview(),
          if (!_sessionEnded) _buildInputArea() else _buildSessionEndedBar(),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Gradient xanh dương lịch sự — không neon
                colors: [Color(0xEF0B2560), Color(0xEF1A56D6)],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: TechAiColors.accentBlue.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SmartElec Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Trợ lý Kỹ thuật ADVANCED',
                style: TextStyle(
                  color: Color(0xFFBAD4F9),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 22),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TechAiHistoryScreen()));
          },
          tooltip: 'Lịch sử chẩn đoán',
        ),
      ],
    );
  }

  // ─── Welcome View (chỉ hiện QuickChips, KHÔNG render lại bubble chào) ─────
  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header thay cho bubble chào dài
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TechAiColors.bubbleAi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TechAiColors.accentBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SmartElec Pro sẵn sàng!',
                        style: TextStyle(
                          color: TechAiColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Bạn đang gặp ca kỹ thuật nào? Nhập câu hỏi bên dưới.',
                        style: TextStyle(
                          color: TechAiColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message List ─────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length +
          (_isLoading ? 1 : 0) +
          (_sessionEnded && _showRatingPanel ? 1 : 0),
      itemBuilder: (_, index) {
        // Typing indicator
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        // Rating panel sau kết thúc phiên
        if (_sessionEnded && index == _messages.length + (_isLoading ? 1 : 0)) {
          return _ratingSubmitted ? _buildRatingThankYou() : _buildRatingPanel();
        }
        if (index >= _messages.length) return const SizedBox.shrink();
        final msg = _messages[index];
        return msg.isUser ? _buildUserBubble(msg) : _buildAiBubble(msg);
      },
    );
  }

  // ─── AI Bubble ────────────────────────────────────────────────────────────
  Widget _buildAiBubble(TechChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copyMessage(msg.text),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TechAiColors.bubbleAi,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: TechAiColors.accentBlue.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.topic != null && msg.topic != 'OTHER')
                      _buildTopicBadge(msg.topic!),
                    MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: TechAiColors.textPrimary,
                          fontSize: 14,
                          height: 1.55,
                        ),
                        strong: const TextStyle(
                          color: TechAiColors.accentBlue,
                          fontWeight: FontWeight.bold,
                        ),
                        code: const TextStyle(
                          backgroundColor: Color(0xFFE2E8F0),
                          color: Color(0xFFC62828),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TechAiColors.divider),
                        ),
                        listBullet: const TextStyle(
                          color: TechAiColors.accentBlue,
                          fontSize: 14,
                        ),
                        h3: const TextStyle(
                          color: TechAiColors.accentBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: const Border(
                            left: BorderSide(
                              color: TechAiColors.accentBlue,
                              width: 3,
                            ),
                          ),
                          color: TechAiColors.surface,
                        ),
                        blockquote: const TextStyle(
                          color: TechAiColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            color: TechAiColors.textSecondary.withOpacity(0.6),
                            fontSize: 10,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _copyMessage(msg.text),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: TechAiColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicBadge(String topic) {
    final Map<String, (String, Color)> topicMap = {
      'ERROR_CODE': ('🔍 Mã lỗi', const Color(0xFFEF5350)),
      'WIRING': ('🔌 Đấu dây', const Color(0xFF42A5F5)),
      'DISASSEMBLY': ('🔧 Tháo lắp', const Color(0xFFFF9800)),
      'PARAMETERS': ('⚡ Thông số', const Color(0xFFAB47BC)),
      'SAFETY': ('🛡️ An toàn', const Color(0xFF26A69A)),
      'DIAGNOSIS': ('🧪 Chẩn đoán', const Color(0xFF66BB6A)),
    };
    final info = topicMap[topic];
    if (info == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info.$2.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.$2.withOpacity(0.35)),
      ),
      child: Text(
        info.$1,
        style: TextStyle(
          color: info.$2,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── User Bubble ──────────────────────────────────────────────────────────
  Widget _buildUserBubble(TechChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (msg.imageBytes != null) ...[
                  Container(
                    height: 180,
                    width: 220,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      image: DecorationImage(
                        image: MemoryImage(msg.imageBytes!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                if (msg.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1A56D6)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TechAiColors.accentBlue.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(
                    color: TechAiColors.textSecondary.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: TechAiColors.accentBlue.withOpacity(0.15),
            child: const Icon(Icons.engineering, color: TechAiColors.accentBlue, size: 18),
          ),
        ],
      ),
    );
  }

  // ─── Typing Indicator ─────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: TechAiColors.bubbleAi,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: TechAiColors.accentBlue.withOpacity(0.15),
              ),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimation,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final v = ((_typingAnimation.value + i * 0.15) % 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Opacity(
                      opacity: (v * 0.7 + 0.3).clamp(0.3, 1.0),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: TechAiColors.accentBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Session Ended Bar ────────────────────────────────────────────────────
  Widget _buildSessionEndedBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TechAiColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: TechAiColors.accentBlue, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Phiên đã kết thúc',
              style: TextStyle(
                color: TechAiColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _clearChat,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: TechAiColors.chipBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'Phiên mới',
                style: TextStyle(color: TechAiColors.accentBlue, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Rating Panel (không ép buộc) ─────────────────────────────────────────
  Widget _buildRatingPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TechAiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TechAiColors.chipBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rate_rounded, color: TechAiColors.accentBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'SmartElec Pro hữu ích không?',
                  style: TextStyle(
                    color: TechAiColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showRatingPanel = false),
                style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
                child: const Text('Bỏ qua', style: TextStyle(color: TechAiColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sao đánh giá
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _ratingStars = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _ratingStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: star <= _ratingStars ? TechAiColors.accentBlue : TechAiColors.textSecondary,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // TextField bình luận
          TextField(
            controller: _ratingCommentController,
            maxLines: 2,
            style: const TextStyle(color: TechAiColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nhận xét về câu trả lời kỹ thuật (không bắt buộc)...',
              hintStyle: TextStyle(color: TechAiColors.textSecondary.withOpacity(0.7), fontSize: 13),
              filled: true,
              fillColor: TechAiColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: TechAiColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: TechAiColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: TechAiColors.accentBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ratingStars == 0
                  ? null
                  : () async {
                      if (_currentTechSessionId != null) {
                        await ApiService.submitTechAiRating(
                          sessionId: _currentTechSessionId!,
                          rating: _ratingStars,
                          comment: _ratingCommentController.text,
                        );
                      }
                      if (mounted) setState(() => _ratingSubmitted = true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _ratingStars == 0
                    ? TechAiColors.divider
                    : TechAiColors.accentBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Gửi đánh giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingThankYou() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TechAiColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_rounded, color: TechAiColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text(
            'Cảm ơn bạn đã đánh giá! ($_ratingStars ⭐)',
            style: const TextStyle(
              color: TechAiColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Image Preview ────────────────────────────────────────────────────────
  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TechAiColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TechAiColors.accentBlue.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ảnh đã chọn — AI sẽ phân tích tem mác / bo mạch',
              style: TextStyle(color: TechAiColors.textSecondary, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: TechAiColors.textSecondary, size: 20),
            onPressed: () => setState(() => _selectedImageBytes = null),
          ),
        ],
      ),
    );
  }

  // ─── Input Area (màu xanh lịch sự, không neon) ────────────────────────────
  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: TechAiColors.divider, width: 1),
        ),
        boxShadow: [
          // Shadow nhẹ nhàng, không glow neon
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildInputIconBtn(
            icon: Icons.camera_alt_outlined,
            onTap: _takePhoto,
            tooltip: 'Chụp ảnh',
          ),
          const SizedBox(width: 6),
          _buildInputIconBtn(
            icon: Icons.image_outlined,
            onTap: _pickImage,
            tooltip: 'Chọn ảnh',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: TechAiColors.inputBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isListening
                      ? TechAiColors.accentBlue
                      : TechAiColors.divider,
                  width: _isListening ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        color: TechAiColors.textPrimary,
                        fontSize: 14.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập câu hỏi kỹ thuật...',
                        hintStyle: TextStyle(
                          color: TechAiColors.textSecondary.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                      ),
                    ),
                  ),
                  _buildInputIconBtn(
                    icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    onTap: _toggleListening,
                    color: _isListening ? TechAiColors.accentBlue : TechAiColors.textSecondary,
                    tooltip: 'Giọng nói',
                    padding: const EdgeInsets.only(right: 6, bottom: 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút Send — xanh dương lịch sự, không glow neon
          GestureDetector(
            onTap: _isLoading ? null : _handleSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading
                    ? TechAiColors.divider
                    : TechAiColors.sendBtn,
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: TechAiColors.sendBtn.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
    EdgeInsetsGeometry? padding,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Icon(
            icon,
            color: color ?? TechAiColors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showRatingDialog(int logId) {
    int selectedRating = 0;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc tương tác với popup
      builder: (dialogContext) { // Dùng biến tên khác để tránh nhầm lẫn context
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Column(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                  SizedBox(height: 12),
                  Text("Kết thúc tra cứu", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Bạn đánh giá thế nào về giải pháp của AI?", textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() => selectedRating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: "Nhập bình luận (không bắt buộc)...",
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: TechAiColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Đóng popup
                          Navigator.pop(context); // Về trang trước
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Bỏ qua", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedRating > 0 ? TechAiColors.accentBlue : Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: selectedRating > 0
                            ? () async {
                                // GỌI API RATING THEO logId (Hàm này bạn đã chép vào ApiService ở bước trước)
                                await ApiService.rateTechAiHistory(logId, selectedRating, commentController.text);
                                
                                if (mounted) {
                                  Navigator.pop(dialogContext);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!'), backgroundColor: Colors.green),
                                  );
                                }
                              }
                            : null,
                        child: const Text("Gửi Đánh Giá", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
