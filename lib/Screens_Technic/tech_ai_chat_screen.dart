import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/api_service.dart';
import 'tech_color.dart';


class TechAiColors {
  static const Color primary = TechColors.primary; 
  static const Color navy = TechColors.navy;       
  static const Color background = Color(0xFFFFFFFF);  
  static const Color surface = Color(0xFFF4F9FF);       
  static const Color inputBg = Color(0xFFEBF3FA);       
  static const Color bubbleAi = Color(0xFFF0F7FF);       
  static const Color bubbleUser = Color(0xFF1565C0);     
  static const Color textPrimary = Color(0xFF1E293B);    
  static const Color textSecondary = Color(0xFF64748B); 
  static const Color accentGlow = Color(0xFF1976D2);     
  static const Color chipBg = Color(0xFFE1EFFE);         
  static const Color divider = Color(0xFFE2E8F0);        
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

// ─── Quick Action Chips ────────────────────────────────────────────
class _QuickAction {
  final String label;
  final IconData icon;
  final String query;
  const _QuickAction(this.label, this.icon, this.query);
}

const List<_QuickAction> _quickActions = [
  _QuickAction('Tra mã lỗi', Icons.error_outline_rounded, 'Tra cứu mã lỗi và cách khắc phục'),
  _QuickAction('Sơ đồ mạch', Icons.schema_outlined, 'Mô tả sơ đồ mạch điện và đấu dây'),
  _QuickAction('Quy trình tháo', Icons.build_outlined, 'Hướng dẫn quy trình tháo lắp linh kiện'),
  _QuickAction('Thông số điện', Icons.electrical_services, 'Tra cứu thông số kỹ thuật điện áp, dòng điện'),
  _QuickAction('Nạp gas', Icons.air, 'Quy trình nạp gas và kiểm tra áp suất'),
  _QuickAction('An toàn điện', Icons.shield_outlined, 'Quy trình làm việc an toàn với điện cao áp'),
];

// ════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════════════
class TechAiChatScreen extends StatefulWidget {
  final String? initialQuery;

  const TechAiChatScreen({super.key, this.initialQuery});

  @override
  State<TechAiChatScreen> createState() => _TechAiChatScreenState();
}

class _TechAiChatScreenState extends State<TechAiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TechChatMessage> _messages = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;

  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  late AnimationController _typingController;
  late Animation<double> _typingAnimation;

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

    _messages.add(TechChatMessage(
      text:
          'Xin chào đồng nghiệp! Mình là **SmartElec Pro** — trợ lý kỹ thuật ADVANCED.\n\n'
          'Mình có thể giúp bạn:\n'
          '🔍 Tra cứu & giải mã **mã lỗi** chi tiết\n'
          '📐 Mô tả **sơ đồ mạch điện** & đấu dây\n'
          '🔧 Hướng dẫn **tháo lắp & thay thế** linh kiện\n'
          '⚡ Tra **thông số kỹ thuật** (điện áp, dòng, áp suất gas)\n'
          '🛡️ **An toàn lao động** với điện cao áp\n\n'
          'Bạn đang gặp ca kỹ thuật nào vậy?',
      isUser: false,
    ));

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

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    final imageToSend = _selectedImageBytes;
    if ((text.isEmpty && imageToSend == null) || _isLoading) return;

    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    }

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

      final response = await ApiService.sendTechChatMessage(
        text,
        imageBase64: imageBase64,
        history: history,
      );

      if (mounted) {
        setState(() {
          _messages.add(TechChatMessage(
            text: response['text'] ?? 'Không có phản hồi.',
            isUser: false,
            topic: response['techState']?['topic'],
          ));
          _isLoading = false;
        });
        _scrollToBottom();
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

  void _handleQuickAction(_QuickAction action) {
    _textController.text = action.query;
    _handleSend();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(TechChatMessage(
        text: 'Đã xóa lịch sử. Bạn cần tra cứu kỹ thuật gì tiếp theo?',
        isUser: false,
      ));
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã sao chép nội dung'),
        backgroundColor: TechAiColors.primary,
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
    _speechToText.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechAiColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.length <= 1
                ? _buildWelcomeView()
                : _buildMessageList(),
          ),
          if (_selectedImageBytes != null) _buildImagePreview(),
          _buildInputArea(),
        ],
      ),
    );
  }

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
                colors: [Color(0xD90B1B4D), Color(0xD91565C0)],
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
                colors: [Color(0xFF4FC3F7), Color(0xFF1565C0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: TechAiColors.accentGlow.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
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
                  color: Color(0xFF90CAF9),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 22),
          onPressed: _clearChat,
          tooltip: 'Xóa lịch sử',
        ),
      ],
    );
  }

  // ── Welcome View ──────────────────────────────────────────────────
  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildAiBubble(_messages.first),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tra cứu nhanh:',
              style: TextStyle(
                color: TechAiColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _quickActions.length,
            itemBuilder: (_, i) => _buildQuickChip(_quickActions[i]),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildQuickChip(_QuickAction action) {
    return GestureDetector(
      onTap: () => _handleQuickAction(action),
      child: Container(
        decoration: BoxDecoration(
          color: TechAiColors.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TechAiColors.primary.withOpacity(0.35),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(action.icon, color: TechAiColors.accentGlow, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action.label,
                style: TextStyle(
                  color: TechAiColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message List ──────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == _messages.length) return _buildTypingIndicator();
        final msg = _messages[index];
        return msg.isUser ? _buildUserBubble(msg) : _buildAiBubble(msg);
      },
    );
  }

  // ── AI Bubble ─────────────────────────────────────────────────────
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
                colors: [Color(0xFF4FC3F7), Color(0xFF1565C0)],
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
                    color: TechAiColors.primary.withOpacity(0.25),
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
                        p: TextStyle(
                          color: TechAiColors.textPrimary, // Sẽ tự nhận màu đen xám mới
                          fontSize: 14,
                          height: 1.55,
                        ),
                        strong: TextStyle(
                          color: TechAiColors.primary, // Đổi sang xanh dương đậm
                          fontWeight: FontWeight.bold,
                        ),
                        code: const TextStyle(
                          backgroundColor: Color(0xFFE2E8F0), // Nền xám nhạt cho code
                          color: Color(0xFFC62828), // Chữ code màu đỏ tối hoặc xanh đậm
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // Background code block màu xám sáng
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: TechAiColors.divider,
                          ),
                        ),
                        listBullet: TextStyle(
                          color: TechAiColors.primary, // Đổi dấu chấm đầu dòng thành xanh dương
                          fontSize: 14,
                        ),
                        h3: TextStyle(
                          color: TechAiColors.primary, // Tiêu đề thẻ h3 màu xanh dương đậm
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: TechAiColors.primary, // Đường viền blockquote
                              width: 3,
                            ),
                          ),
                          color: TechAiColors.surface, // Nền ánh xanh
                        ),
                        blockquote: TextStyle(
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
        color: info.$2.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.$2.withOpacity(0.4)),
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

  // ── User Bubble ───────────────────────────────────────────────────
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
                        colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TechAiColors.primary.withOpacity(0.3),
                          blurRadius: 8,
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
            backgroundColor: TechAiColors.primary.withOpacity(0.25),
            child: const Icon(Icons.engineering, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Typing Indicator ──────────────────────────────────────────────
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
                colors: [Color(0xFF4FC3F7), Color(0xFF1565C0)],
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
                color: TechAiColors.primary.withOpacity(0.25),
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
                          color: Color(0xFF4FC3F7),
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

  // ── Image Preview ─────────────────────────────────────────────────
  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TechAiColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TechAiColors.primary.withOpacity(0.3)),
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

  // ── Input Area ────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: TechAiColors.surface,
        border: Border(
          top: BorderSide(color: TechAiColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
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
                      ? TechAiColors.accentGlow
                      : TechAiColors.primary.withOpacity(0.3),
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
                      style: TextStyle(
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
                    color: _isListening ? TechAiColors.accentGlow : TechAiColors.textSecondary,
                    tooltip: 'Giọng nói',
                    padding: const EdgeInsets.only(right: 6, bottom: 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _handleSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isLoading
                    ? const LinearGradient(
                        colors: [Color(0xFF334E6E), Color(0xFF334E6E)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF1565C0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: TechAiColors.accentGlow.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.6),
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
}
