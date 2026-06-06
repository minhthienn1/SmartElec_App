import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/repair_case.dart';
import 'chat_screen.dart';

// Đảm bảo đồng bộ phối màu với hệ thống Chat & Home
const _kBgColor = Color(0xff081125);
const _kCardColor = Color(0xff111B3D);
const _kSubTextColor = Color(0xff9EA9C1);

class AiHistoryScreen extends StatefulWidget {
  const AiHistoryScreen({super.key});

  @override
  State<AiHistoryScreen> createState() => _AiHistoryScreenState();
}

class _AiHistoryScreenState extends State<AiHistoryScreen> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // Hàm load lại danh sách lịch sử chẩn đoán
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      // Tận dụng hàm lấy lịch sử sẵn có của ApiService
      final data = await ApiService.getHistory(); 
      setState(() {
        _sessions = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải lịch sử: $e")),
      );
    }
  }

  // Hàm xử lý popup xác nhận và xóa chat
  Future<void> _hideSession(int sessionId, int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff111B3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Xóa ca chẩn đoán?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Bạn có chắc chắn muốn xóa lịch sử này không?",
          style: TextStyle(color: Color(0xff9EA9C1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Không", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Có", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.hideChatSession(sessionId); 
      
      if (success && mounted) {
        setState(() {
          _sessions.removeAt(index); // Xóa mượt trên UI ngay lập tức
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🗑️ Đã xóa ca chẩn đoán khỏi lịch sử."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating, // Hiển thị đẹp hơn
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 Lỗi! Không thể xóa lúc này."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
      title: const Text(
        "Lịch sử chẩn đoán AI", 
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: Colors.white, // Đã thêm màu trắng
        ),
      ),
      backgroundColor: _kCardColor,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white), // Giúp nút quay lại (back) cũng có màu trắng
    ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff00B0FF)))
          : _sessions.isEmpty
              ? const Center(child: Text("Chưa có ca chẩn đoán nào.", style: TextStyle(color: _kSubTextColor)))
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final item = _sessions[index];
                      final int sessionId = item.id is int ? item.id : (int.tryParse(item.id.toString()) ?? 0);
                      final DateTime parsedDate = item.date;
                      final String formattedTime = DateFormat('dd/MM/yyyy • HH:mm').format(parsedDate);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _kCardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            item.title ?? "Thiết bị lạ",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                "Vấn đề: ${item.symptom ?? 'Chưa rõ nguyên nhân'}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _kSubTextColor, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formattedTime,
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                              ),
                            ],
                          ),
                          // Nút X màu xám thanh lịch bên phải theo ý bạn
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _hideSession(sessionId, index), // Gọi hàm đã tách ra
                          ),
                          onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                sessionId: sessionId,
                                initialDevice: item.title ?? "Chat với AI",
                              ),
                            ),
                          ).then((_) => _fetchHistory());
                        },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}