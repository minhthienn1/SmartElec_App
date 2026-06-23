import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tech_color.dart'; // Đảm bảo bạn đang import đúng file màu của bạn

class TechJobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> jobData;

  const TechJobDetailScreen({super.key, required this.jobData});

  @override
  Widget build(BuildContext context) {
    final customerName = jobData['user']?['fullName'] ?? jobData['user']?['phoneNumber'] ?? "Khách hàng";
    
    final device = jobData['device']?['name'] ?? jobData['device']?['category'] ?? jobData['deviceType'] ?? "Chưa rõ thiết bị";
    
    final symptom = jobData['symptom'] ?? jobData['aiSummary'] ?? "Không có mô tả chi tiết";
    
    // LẤY DỮ LIỆU BÁO GIÁ
    final quotes = jobData['quotes'];
    Map<String, dynamic>? acceptedQuote;
    if (quotes != null && quotes is List && quotes.isNotEmpty) {
      acceptedQuote = quotes[0] as Map<String, dynamic>;
    }

    final quoteAmount = acceptedQuote != null 
        ? (num.tryParse(acceptedQuote['amount'].toString()) ?? 0) 
        : 0;
        
    final expectedTime = acceptedQuote?['expectedTime']?.toString() ?? "Chưa xác định";

    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    
    // Lấy thông tin review
    final review = jobData['review'];
    // Xử lý trường hợp review trả về là mảng (nếu Prisma cấu hình 1-n) hoặc Object (1-1)
    Map<String, dynamic>? reviewData;
    if (review is List && review.isNotEmpty) {
      reviewData = review[0];
    } else if (review is Map<String, dynamic>) {
      reviewData = review;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text("Chi tiết đơn", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: TechColors.primary),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: "Thông tin sửa chữa",
              icon: Icons.build_circle_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow("Khách hàng:", customerName),
                  const Divider(),
                  _buildRow("Thiết bị:", device),
                  const Divider(),
                  _buildRow("Tình trạng:", symptom, isLongText: true),
                  const Divider(),
                  _buildRow("T.gian dự kiến:", expectedTime),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: "Thanh toán",
              icon: Icons.monetization_on_outlined,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tổng thu:", style: TextStyle(fontSize: 16)),
                  Text(
                    formatCurrency.format(quoteAmount), 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TechColors.primary)
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // HIỂN THỊ ĐÁNH GIÁ (NẾU CÓ)
            if (reviewData != null) ...[
              _buildSection(
                title: "Đánh giá từ khách hàng",
                icon: Icons.star_border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        final rating = num.tryParse(reviewData!['rating'].toString()) ?? 0;
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber, 
                          size: 28,
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TechColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        reviewData['comment'] ?? "Không có bình luận.",
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Khách hàng chưa đánh giá đơn này.", style: TextStyle(color: Colors.grey)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TechColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TechColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120, 
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}