import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/repair_case.dart';

class RepairDetailScreen extends StatelessWidget {
  final RepairCase repairCase;

  const RepairDetailScreen({super.key, required this.repairCase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 105, 37, 0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Chi tiết giao dịch",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMechanicInfoCard(),
            const SizedBox(height: 16),
            _buildTransactionSummaryCard(),
            const SizedBox(height: 16),
            _buildReviewCard(),
            const SizedBox(height: 32),
            _buildContactAgainButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE65100).withOpacity(0.1), // Nền icon cam nhạt
            child: const Icon(Icons.person, color: Color(0xFFE65100), size: 28), // Icon cam đậm
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repairCase.mechanicName ?? "Thợ sửa chữa",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "SĐT: ${repairCase.mechanicPhone ?? 'Chưa cập nhật'}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  repairCase.rating?.toStringAsFixed(1) ?? "5.0",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tóm tắt thỏa thuận",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100)),
          ),
          const Divider(height: 24),
          _buildInfoRow("Ngày chốt:", DateFormat('dd/MM/yyyy - HH:mm').format(repairCase.date)),
          const SizedBox(height: 12),
          _buildInfoRow("Chi phí chốt:", repairCase.agreedPrice ?? "Chưa chốt giá", isHighlight: true),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              repairCase.chatSummary ?? "Không có tóm tắt giao dịch.",
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Đánh giá của bạn",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100)),
          ),
          const SizedBox(height: 12),
          Text(
            repairCase.reviewComment ?? "Bạn chưa để lại đánh giá cho giao dịch này.",
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 16 : 14,
            color: isHighlight ? Colors.green[700] : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildContactAgainButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Điều hướng lại màn hình chat room của Thợ dựa vào repairCase.id hoặc id thợ nếu cần
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 120, 42, 0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            "Nhắn tin lại cho thợ này",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}