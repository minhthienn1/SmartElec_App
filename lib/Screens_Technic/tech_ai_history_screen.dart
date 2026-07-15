import 'package:flutter/material.dart';
import 'tech_color.dart';
import '../services/api_service.dart';

class TechAiColors {
  static const Color background = Color(0xFFF8FAFF);
  static const Color surface = Color(0xFFF0F4FC);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color divider = Color(0xFFE2E8F0);
}

class TechAiHistoryScreen extends StatefulWidget {
  const TechAiHistoryScreen({super.key});

  @override
  State<TechAiHistoryScreen> createState() => _TechAiHistoryScreenState();
}

class _TechAiHistoryScreenState extends State<TechAiHistoryScreen> {
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getTechAiHistory();
    if (mounted) {
      setState(() {
        List<Map<String, dynamic>> uiItems = [];
        String? currentDateStr;

        for (var item in data) {
          final dtUtc = DateTime.tryParse(item['createdAt'] ?? '');
          if (dtUtc == null) continue;
          final dt = dtUtc.toLocal(); // Convert to local time!
          
          final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
          final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          
          if (dateStr != currentDateStr) {
            uiItems.add({'isHeader': true, 'date': dateStr});
            currentDateStr = dateStr;
          }

          String userMsg = item['userMsg']?.toString().trim() ?? '';
          if (userMsg.isEmpty) userMsg = 'Trò chuyện kỹ thuật';
          String title = userMsg.length > 50 ? userMsg.substring(0, 50) + '...' : userMsg;

          String aiResponse = item['aiResponse']?.toString().trim() ?? 'Không có dữ liệu';
          String summary = aiResponse.length > 150 ? aiResponse.substring(0, 150) + '...' : aiResponse;
          
          String device = item['deviceCategory']?.toString() ?? 'Khác';
          if (device == 'null') device = 'Khác';

          int? score = item['score'];
          String? comment = item['humanUsefulnessNote'];

          uiItems.add({
            'isHeader': false,
            'id': item['id'],
            'date': dateStr,
            'time': timeStr,
            'title': title,
            'device': device,
            'summary': summary,
            'detail': aiResponse,
            'score': score,       
            'comment': comment,
          });
        }
        
        _historyList = uiItems;
        _isLoading = false;
      });
    }
  }

  void _confirmDelete(int index) {
    final item = _historyList[index];
    if (item['isHeader'] == true) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lịch sử?'),
        content: const Text('Bạn có chắc chắn muốn xóa bản ghi lịch sử này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: TechAiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final success = await ApiService.deleteTechAiHistory(item['id']);
              if (mounted) {
                if (success) {
                  _fetchHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa khỏi lịch sử'), backgroundColor: Colors.green),
                  );
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Xóa thất bại'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechAiColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: TechAiColors.textPrimary),
        title: const Text(
          'Lịch sử chẩn đoán',
          style: TextStyle(
            color: TechAiColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: TechAiColors.divider),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: TechAiColors.accentBlue))
          : _historyList.isEmpty
              ? const Center(child: Text('Chưa có lịch sử chẩn đoán nào', style: TextStyle(color: TechAiColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _historyList.length,
                  itemBuilder: (context, index) {
                    final item = _historyList[index];
                    
                    if (item['isHeader'] == true) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : 24, 
                          bottom: 12, 
                          left: 4
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: TechAiColors.accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              item['date'],
                              style: const TextStyle(
                                color: TechAiColors.accentBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GestureDetector(
              onLongPress: () => _confirmDelete(index),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TechAiHistoryDetailScreen(item: item),
                  ),
                );
              },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TechAiColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['time'],
                        style: const TextStyle(
                          color: TechAiColors.accentBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: TechAiColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['title'],
                    style: const TextStyle(
                      color: TechAiColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.build_circle_outlined, size: 14, color: TechAiColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        item['device'],
                        style: const TextStyle(
                          color: TechAiColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TechAiColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item['summary'],
                      style: const TextStyle(
                        color: TechAiColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item['score'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < item['score'] ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        const Text('Đã đánh giá', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ));
        },
      ),
    );
  }
}

class TechAiHistoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const TechAiHistoryDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechAiColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: TechAiColors.textPrimary),
        title: const Text(
          'Chi tiết chẩn đoán AI',
          style: TextStyle(
            color: TechAiColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: TechAiColors.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['time']} - ${item['date']}',
              style: const TextStyle(
                color: TechAiColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['title'],
              style: const TextStyle(
                color: TechAiColors.accentBlue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TechAiColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.build_circle_outlined, color: TechAiColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Thiết bị: ${item['device']}',
                    style: const TextStyle(
                      color: TechAiColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tóm tắt & Hướng xử lý',
              style: TextStyle(
                color: TechAiColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TechAiColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                item['detail'] ?? item['summary'],
                style: const TextStyle(
                  color: TechAiColors.textPrimary,
                  fontSize: 14.5,
                  height: 1.6,
                ),
                
              ),
            ),
            if (item['score'] != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Đánh giá của bạn',
                style: TextStyle(color: TechAiColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < item['score'] ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    if (item['comment'] != null && item['comment'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '📝 "${item['comment']}"',
                        style: const TextStyle(color: TechAiColors.textPrimary, fontStyle: FontStyle.italic),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

