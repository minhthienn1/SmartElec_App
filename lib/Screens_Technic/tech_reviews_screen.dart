import 'package:flutter/material.dart';
import 'tech_color.dart';
import '../services/technician_service.dart';
import 'package:intl/intl.dart';

class TechReviewsScreen extends StatefulWidget {
  const TechReviewsScreen({super.key});

  @override
  State<TechReviewsScreen> createState() => _TechReviewsScreenState();
}

class _TechReviewsScreenState extends State<TechReviewsScreen> {
  final TechnicianService _service = TechnicianService();
  bool isLoading = true;
  List<dynamic> reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _service.getReviews();
      setState(() {
        reviews = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Thống kê đánh giá", style: TextStyle(color: TechColors.primary)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: TechColors.primary),
        elevation: 0.5,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: TechColors.primary))
          : reviews.isEmpty
              ? const Center(child: Text("Chưa có đánh giá nào", style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    final customerName = review['user']?['fullName'] ?? "Khách hàng";
                    final rating = num.tryParse(review['rating'].toString()) ?? 0;
                    final comment = review['comment'] ?? "Không có bình luận";
                    final date = DateTime.parse(review['createdAt']).toLocal();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 18,
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(comment, style: const TextStyle(color: Colors.black87)),
                      ],
                    );
                  },
                ),
    );
  }
}