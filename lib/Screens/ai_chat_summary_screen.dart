import 'package:flutter/material.dart';

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

class AiChatSummaryScreen extends StatelessWidget {
  final String deviceName;  
  final String symptom;     
  final String aiSummary;   

  const AiChatSummaryScreen({
    Key? key,
    required this.deviceName,
    required this.symptom,
    required this.aiSummary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground, // Nền sáng xám nhẹ chuẩn Light Mode
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.kIdleBorder.withOpacity(0.5), height: 1), // Viền mỏng dưới AppBar
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.kTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chi tiết lịch sử chẩn đoán',
          style: TextStyle(
            color: AppColors.kTextPrimary, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tên thiết bị & Triệu chứng ban đầu (Card Trắng)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.5)),
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
                    children: [
                      const Icon(Icons.developer_board_rounded, color: AppColors.kPrimaryOrange), // Đổi sang màu cam thương hiệu
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          deviceName,
                          style: const TextStyle(
                            color: AppColors.kTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: AppColors.kIdleBorder, height: 1),
                  ),
                  Text(
                    'Vấn đề ghi nhận: $symptom',
                    style: const TextStyle(
                      color: AppColors.kTextSecondary, 
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Tiêu đề mục Kết luận từ AI
            Text(
              'KẾT LUẬN TỪ AI',
              style: TextStyle(
                color: AppColors.kMutedGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // Nội dung tóm tắt phân tích từ AI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.kPrimaryOrange.withOpacity(0.2)), // Viền cam nhạt tạo điểm nhấn AI
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kPrimaryOrange.withOpacity(0.01),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.analytics_outlined, color: AppColors.kPrimaryOrange),
                      SizedBox(width: 10),
                      Text(
                        'Phân tích & Hướng xử lý',
                        style: TextStyle(
                          color: AppColors.kPrimaryOrange,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    aiSummary,
                    style: const TextStyle(
                      color: AppColors.kTextPrimary, // Chữ màu tối dễ đọc trên nền trắng
                      fontSize: 14,
                      height: 1.6, 
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Nút hành động: Tạo cuộc tư vấn mới (Đồng bộ tone Cam thương hiệu)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPrimaryOrange, // Chuyển sang màu cam đồng bộ app
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); 
                },
                icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Tạo cuộc tư vấn mới cho thiết bị này',
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold, 
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