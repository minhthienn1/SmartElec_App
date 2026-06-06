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
  bool _isEditMode = false; 
  Set<int> _selectedIds = {};

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
        _isEditMode = false; 
        _selectedIds.clear();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải lịch sử: $e")),
      );
    }
  }

  // Hàm tiện ích lấy ID dạng int an toàn
  int _safeGetId(dynamic item) {
    if (item.id is int) return item.id as int;
    return (int.tryParse(item.id.toString()) ?? 0);
  }

  // Tiện ích hiển thị SnackBar thông báo gọn gàng
  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Hàm xử lý xóa các mục đã chọn
  Future<void> _deleteSelectedSessions() async {
    if (_selectedIds.isEmpty) return;

    final int count = _selectedIds.length;

    // 1. Hiện Dialog xác nhận
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff111B3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Xóa $count ca chẩn đoán?",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Bạn có chắc chắn muốn xóa $count lịch sử đã chọn không?",
          style: const TextStyle(color: Color(0xff9EA9C1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Không", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Có", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Gọi API và xử lý UI
    setState(() => _isLoading = true);

    try {
      final List<int> idsToHide = _selectedIds.toList();
      
      // Sử dụng đúng hàm xóa mềm nhiều ID mà bạn đã viết trong ApiService
      final success = await ApiService.hideMultipleSessions(idsToHide); 

      if (success && mounted) {
        setState(() {
          // Xóa các phần tử khỏi UI ngay lập tức
          _sessions.removeWhere((item) => _selectedIds.contains(_safeGetId(item)));
          _selectedIds.clear();
          _isEditMode = false;
          _isLoading = false;
        });
        // Đổi thông báo một chút để khách hàng hiểu là chỉ ẩn đi
        _showSnackBar("🗑️ Đã xóa $count ca chẩn đoán khỏi lịch sử của bạn.", Colors.green);
      } else if (mounted) {
        throw Exception("Máy chủ từ chối yêu cầu xóa lịch sử.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("🚨 Lỗi khi xóa: $e", Colors.redAccent);
      }
    }
  }

  // Phân loại ngày tháng thông minh
  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) return "Hôm nay";
    if (itemDate == yesterday) return "Hôm qua";
    return DateFormat('dd/MM/yyyy').format(itemDate); // Các ngày cũ hơn hiện ngày/tháng/năm
  }

  // Kích hoạt Edit Mode khi nhấn giữ
  void _toggleEditMode(int initialId) {
    setState(() {
      _isEditMode = true;
      _selectedIds.add(initialId);
    });
  }

  // Chọn hoặc Bỏ chọn 1 item
  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        // Tự động thoát Edit Mode nếu không còn item nào được chọn
        if (_selectedIds.isEmpty) _isEditMode = false; 
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // Thoát chế độ chọn
  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _sessions.length) {
        _selectedIds.clear(); // Bỏ chọn hết
        _isEditMode = false;
      } else {
        // Cập nhật cách lấy ID cho chuẩn
        _selectedIds = _sessions.map((item) => _safeGetId(item)).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Đã chọn ${_selectedIds.length}" : "Lịch sử chẩn đoán AI",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _kCardColor,
        elevation: 0,
        centerTitle: true,
        // Nút Hủy chế độ edit
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _cancelEditMode,
              )
            : null,
        iconTheme: const IconThemeData(color: Colors.white),
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
                      final String formattedTime = DateFormat('HH:mm').format(parsedDate);
                      final String dateGroup = _getDateGroup(parsedDate);

                      // Logic hiển thị Header gộp ngày
                      bool showHeader = false;
                      if (index == 0) {
                        showHeader = true; // Item đầu tiên luôn có header
                      } else {
                        final prevItem = _sessions[index - 1];
                        final String prevDateGroup = _getDateGroup(prevItem.date);
                        if (dateGroup != prevDateGroup) showHeader = true;
                      }

                      final isSelected = _selectedIds.contains(sessionId);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
                              child: Text(
                                dateGroup,
                                style: const TextStyle(
                                  color: Color(0xff00B0FF), // Màu xanh nổi bật cho Header
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          GestureDetector(
                            onLongPress: () {
                              if (!_isEditMode) _toggleEditMode(sessionId);
                            },
                            onTap: () {
                              if (_isEditMode) {
                                _toggleSelection(sessionId);
                              } else {
                                // Vào phòng chat như bình thường
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      sessionId: sessionId,
                                      initialDevice: item.title ?? "Chat với AI",
                                    ),
                                  ),
                                ).then((_) => _fetchHistory());
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xff1C2A53) : _kCardColor, // Đổi màu nhẹ khi được chọn
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xff00B0FF) : Colors.white.withOpacity(0.05),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: _isEditMode
                                    ? Checkbox(
                                        value: isSelected,
                                        activeColor: const Color(0xff00B0FF),
                                        side: const BorderSide(color: Colors.grey),
                                        onChanged: (_) => _toggleSelection(sessionId),
                                      )
                                    : null,
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
                                // Nếu không ở chế độ Edit, vẫn giữ nút X nhỏ gọn cho thao tác nhanh
                                trailing: null,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
      bottomNavigationBar: _isEditMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: _kCardColor,
                  border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: Icon(
                        _selectedIds.length == _sessions.length ? Icons.deselect_outlined : Icons.select_all_outlined,
                        color: const Color(0xff00B0FF),
                        size: 20,
                      ),
                      label: Text(
                        _selectedIds.length == _sessions.length ? "Bỏ chọn hết" : "Chọn tất cả",
                        style: const TextStyle(color: Color(0xff00B0FF), fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      // Gọi hàm Xóa nhiều ở đây
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelectedSessions, 
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20,),
                      label: Text(
                        "Xóa (${_selectedIds.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}