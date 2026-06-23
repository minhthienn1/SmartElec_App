import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tech_color.dart'; 
import 'tech_job_detail_screen.dart'; 
import '../services/technician_service.dart'; // Đã mở comment để gọi Service thật

class TechMyJobsScreen extends StatefulWidget {
  const TechMyJobsScreen({super.key});

  @override
  State<TechMyJobsScreen> createState() => _TechMyJobsScreenState();
}

class _TechMyJobsScreenState extends State<TechMyJobsScreen> {
  bool isLoading = true;
  List<dynamic> completedJobs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // GỌI DỮ LIỆU THẬT TỪ BACKEND
      final data = await TechnicianService().getCompletedJobs();
      
      if (mounted) {
        setState(() {
          completedJobs = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Hàm fomat hiển thị header ngày tháng
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return "Hôm nay, ${DateFormat('dd/MM').format(date)}";
    } else if (dateToCheck == yesterday) {
      return "Hôm qua, ${DateFormat('dd/MM').format(date)}";
    } else if (date.year == now.year) {
      return DateFormat('dd/MM').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Đơn đã hoàn thành", style: TextStyle(color: TechColors.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: TechColors.primary))
          : completedJobs.isEmpty
              ? const Center(child: Text("Chưa có đơn nào hoàn thành", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: completedJobs.length,
                  itemBuilder: (context, index) {
                    final job = completedJobs[index];
                    final String dateString = job['updatedAt']?.toString() ?? DateTime.now().toIso8601String();
                    final date = DateTime.parse(dateString);
                    
                    // Logic để hiện Header ngày tháng (chỉ hiện khi qua ngày mới trong list)
                    bool showHeader = true;
                    if (index > 0) {
                      final prevJobDateStr = completedJobs[index - 1]['updatedAt']?.toString() ?? DateTime.now().toIso8601String();
                      final prevJobDate = DateTime.parse(prevJobDateStr);
                      if (prevJobDate.year == date.year && prevJobDate.month == date.month && prevJobDate.day == date.day) {
                        showHeader = false;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatDateHeader(date),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            ),
                          ),
                        _buildJobCard(job),
                      ],
                    );
                  },
                ),
    );
  }

 Widget _buildJobCard(Map<String, dynamic> job) {
    // 1. Quét tên khách hàng
    final customerName = job['user']?['fullName'] 
        ?? job['user']?['phoneNumber'] 
        ?? job['contactName'] 
        ?? "Khách hàng";

    // 2. Quét tên thiết bị
    // Phải quét job['device']?['name'] hoặc category tùy vào Prisma schema của bạn
    final device = job['device']?['name'] 
        ?? job['device']?['category'] 
        ?? job['deviceType'] 
        ?? job['symptom'] 
        ?? "Sửa chữa thiết bị";

    // 3. Tìm báo giá (Quote)
    num quoteAmount = 0;
    final quotes = job['quotes'];
    if (quotes != null && quotes is List && quotes.isNotEmpty) {
      final acceptedQuote = quotes[0];
      if (acceptedQuote is Map && acceptedQuote['amount'] != null) {
        quoteAmount = num.tryParse(acceptedQuote['amount'].toString()) ?? 0;
      }
    }

    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.build_circle, color: Colors.blue),
        ),
        title: Text(device, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("Khách: $customerName"),
            const SizedBox(height: 4),
            if (quoteAmount > 0)
              Text(
                "Giá: ${formatCurrency.format(quoteAmount)}", 
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
              )
            else
              const Text("Chưa có thông tin giá", style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TechJobDetailScreen(jobData: job)),
          );
        },
      ),
    );
  }
}