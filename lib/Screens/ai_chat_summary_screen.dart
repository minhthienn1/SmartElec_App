import 'package:flutter/material.dart';

class AiChatSummaryScreen extends StatelessWidget {
  final String deviceName;  // Tương ứng với deviceType từ NestJS
  final String symptom;     // Tương ứng với symptom từ NestJS
  final String aiSummary;   // Tương ứng với aiSummary từ NestJS

  const AiChatSummaryScreen({
    Key? key,
    required this.deviceName,
    required this.symptom,
    required this.aiSummary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424), // Màu tối đồng bộ với UI của bạn
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chi tiết lịch sử chẩn đoán',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tên thiết bị & Triệu chứng ban đầu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2738),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.developer_board, color: Colors.cyanAccent),
                      const SizedBox(width: 8),
                      Text(
                        deviceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Text(
                    'Vấn đề ghi nhận: $symptom',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Nội dung tóm tắt và phân tích chuyên sâu từ AI
            Text(
              'KẾT LUẬN TỪ AI',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2738),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.analytics_outlined, color: Colors.tealAccent),
                      SizedBox(width: 8),
                      Text(
                        'Phân tích & Hướng xử lý',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Hiển thị nội dung aiSummary từ NestJS
                  Text(
                    aiSummary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.6, // Khoảng cách dòng rộng rãi, dễ đọc
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Nút hành động (Tạo session chat mới thay vì chat đè lên lịch sử cũ)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8), // Tone màu xanh năng động
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Điều hướng quay lại màn hình Chat chính (Ảnh số 2 của bạn)
                  // Để tạo một cuộc trò chuyện hoàn toàn mới
                  Navigator.pop(context); 
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Tạo cuộc tư vấn mới cho thiết bị này',
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}