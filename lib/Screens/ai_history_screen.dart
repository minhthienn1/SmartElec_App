import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/repair_case.dart';
import 'chat_screen.dart';
import 'ai_chat_summary_screen.dart';

// Tích hợp trực tiếp bảng màu chuẩn vào file này
class AppColors {
  static const Color kPrimaryOrange = Color(0xFFFF7A00);
  static const Color kDarkOrange = Color(0xFFE65C00); 
  static const Color kLightOrange = Color(0xFFFFF3E0); 
  static const Color kBackground = Color(0xFFF9FAFB); 
  static const Color kInputBackground = Colors.white;
  static const Color kTextPrimary = Color(0xFF1F2937);
  static const Color kTextSecondary = Color(0xFF6B7280);
  static const Color kMutedGrey = Color(0xFF9CA3AF);
  static const Color kErrorRed = Color(0xFFEF4444);
  static const Color kIdleBorder = Color(0xFFD1D5DB);
}

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

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
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

  int _safeGetId(dynamic item) {
    if (item.id is int) return item.id as int;
    return (int.tryParse(item.id.toString()) ?? 0);
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteSelectedSessions() async {
    if (_selectedIds.isEmpty) return;
    final int count = _selectedIds.length;

    // Cập nhật Dialog UI sáng màu
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Xóa $count ca chẩn đoán?",
          style: const TextStyle(color: AppColors.kTextPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Bạn có chắc chắn muốn xóa $count lịch sử đã chọn không?",
          style: const TextStyle(color: AppColors.kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Không", style: TextStyle(color: AppColors.kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kErrorRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Có, Xóa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final List<int> idsToHide = _selectedIds.toList();
      final success = await ApiService.hideMultipleSessions(idsToHide); 

      if (success && mounted) {
        setState(() {
          _sessions.removeWhere((item) => _selectedIds.contains(_safeGetId(item)));
          _selectedIds.clear();
          _isEditMode = false;
          _isLoading = false;
        });
        _showSnackBar("🗑️ Đã xóa $count ca chẩn đoán khỏi lịch sử của bạn.", Colors.green);
      } else if (mounted) {
        throw Exception("Máy chủ từ chối yêu cầu xóa lịch sử.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("🚨 Lỗi khi xóa: $e", AppColors.kErrorRed);
      }
    }
  }

  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) return "Hôm nay";
    if (itemDate == yesterday) return "Hôm qua";
    return DateFormat('dd/MM/yyyy').format(itemDate);
  }

  void _toggleEditMode(int initialId) {
    setState(() {
      _isEditMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isEditMode = false; 
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _sessions.length) {
        _selectedIds.clear(); 
        _isEditMode = false;
      } else {
        _selectedIds = _sessions.map((item) => _safeGetId(item)).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground, // Đổi màu nền sáng
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Đã chọn ${_selectedIds.length}" : "Lịch sử chẩn đoán AI",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.kTextPrimary, fontSize: 18),
        ),
        backgroundColor: Colors.white, // Đổi AppBar sang trắng
        surfaceTintColor: Colors.white,
        elevation: 1, // Đổ bóng nhẹ cho AppBar
        shadowColor: Colors.black.withOpacity(0.2),
        centerTitle: true,
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.kTextPrimary),
                onPressed: _cancelEditMode,
              )
            : const BackButton(color: AppColors.kTextPrimary), // Nút back mặc định màu đen
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.kPrimaryOrange))
          : _sessions.isEmpty
              ? const Center(
                  child: Text("Chưa có ca chẩn đoán nào.", style: TextStyle(color: AppColors.kTextSecondary, fontSize: 16)),
                )
              : RefreshIndicator(
                  color: AppColors.kPrimaryOrange,
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final item = _sessions[index];
                      final int sessionId = _safeGetId(item);
                      final DateTime parsedDate = item.date;
                      final String formattedTime = DateFormat('HH:mm').format(parsedDate);
                      final String dateGroup = _getDateGroup(parsedDate);

                      bool showHeader = false;
                      if (index == 0) {
                        showHeader = true;
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
                              padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
                              child: Text(
                                dateGroup,
                                style: const TextStyle(
                                  color: AppColors.kPrimaryOrange, // Header ngày tháng màu cam
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiChatSummaryScreen(
                                      deviceName: item.title,      
                                      symptom: item.symptom,       
                                      aiSummary: item.summary,     
                                    ),
                                  ),
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.kLightOrange : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.kPrimaryOrange : AppColors.kIdleBorder.withOpacity(0.5),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  if (!isSelected) // Đổ bóng cho card thường
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                leading: _isEditMode
                                    ? Checkbox(
                                        value: isSelected,
                                        activeColor: AppColors.kPrimaryOrange,
                                        checkColor: Colors.white,
                                        side: const BorderSide(color: AppColors.kIdleBorder, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (_) => _toggleSelection(sessionId),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.kLightOrange.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.smart_toy_outlined, color: AppColors.kPrimaryOrange, size: 24),
                                      ),
                                title: Text(
                                  item.title ?? "Thiết bị lạ",
                                  style: const TextStyle(color: AppColors.kTextPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(
                                      "Vấn đề: ${item.symptom ?? 'Chưa rõ nguyên nhân'}",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.kTextSecondary, fontSize: 13, height: 1.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 14, color: AppColors.kMutedGrey),
                                        const SizedBox(width: 4),
                                        Text(
                                          formattedTime,
                                          style: const TextStyle(color: AppColors.kMutedGrey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: Icon(
                        _selectedIds.length == _sessions.length ? Icons.deselect_outlined : Icons.select_all_outlined,
                        color: AppColors.kPrimaryOrange,
                        size: 20,
                      ),
                      label: Text(
                        _selectedIds.length == _sessions.length ? "Bỏ chọn hết" : "Chọn tất cả",
                        style: const TextStyle(color: AppColors.kPrimaryOrange, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kErrorRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelectedSessions, 
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      label: Text(
                        "Xóa (${_selectedIds.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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