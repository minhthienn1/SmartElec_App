import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/repair_case.dart';
import '../services/api_service.dart'; // Thay thế storage_service bằng api_service
import 'repair_detail_screen.dart';

class RepairHistoryScreen extends StatefulWidget {
  const RepairHistoryScreen({super.key});

  @override
  State<RepairHistoryScreen> createState() => _RepairHistoryScreenState();
}

class _RepairHistoryScreenState extends State<RepairHistoryScreen> {
  List<RepairCase> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllHistory();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Load lịch sử từ Cloud (API) thay vì Local (SharedPreferences)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadAllHistory() async {
    // Đảm bảo trạng thái loading được bật trước khi gọi API
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getMechanicRepairHistory();
      if (!mounted) return;
      setState(() {
        _history = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Hiển thị lỗi qua SnackBar thay vì crash app
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải lịch sử: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Thử lại',
            textColor: Colors.white,
            onPressed: _loadAllHistory, // Cho phép user retry
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Lịch sử chat với thợ",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadAllHistory, // Pull-to-refresh để tải lại
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return _buildHistoryCard(item);
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
          Icon(Icons.speaker_notes_off, size: 80, color: Colors.grey[300]), // Đổi icon phù hợp với chat
          const SizedBox(height: 16),
          const Text(
            "Chưa có lịch sử chat nào", // <--- Cập nhật text
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(RepairCase item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.mechanicName ?? "Thợ sửa chữa", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  item.rating?.toStringAsFixed(1) ?? "5.0",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy - HH:mm').format(item.date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.chatSummary ?? "Đã thống nhất giá và hoàn tất sửa chữa.",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RepairDetailScreen(repairCase: item),
            ),
          );
        },
      ),
    );
  }
}
