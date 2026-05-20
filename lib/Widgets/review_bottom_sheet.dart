import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────
// PROVIDER: ReviewState - Quản lý state nội bộ của BottomSheet
// ─────────────────────────────────────────────────────────────────
class ReviewState extends ChangeNotifier {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  int get rating => _rating;
  Set<String> get selectedTags => _selectedTags;
  bool get isSubmitting => _isSubmitting;

  static const List<String> availableTags = [
    'Đúng giờ',
    'Nhiệt tình',
    'Tay nghề cao',
    'Giá hợp lý',
    'Dọn dẹp sạch sẽ',
    'Tư vấn tốt',
  ];

  void setRating(int value) {
    _rating = value;
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────
// WIDGET: ReviewBottomSheet - UI đánh giá thợ
// ─────────────────────────────────────────────────────────────────
class ReviewBottomSheet extends StatefulWidget {
  final int sessionId;
  final String technicianName;
  final String? technicianAvatarUrl;

  const ReviewBottomSheet({
    super.key,
    required this.sessionId,
    required this.technicianName,
    this.technicianAvatarUrl,
  });

  /// Hàm tiện ích để mở BottomSheet từ bất kỳ đâu
  static Future<bool?> show(
    BuildContext context, {
    required int sessionId,
    required String technicianName,
    String? technicianAvatarUrl,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewBottomSheet(
        sessionId: sessionId,
        technicianName: technicianName,
        technicianAvatarUrl: technicianAvatarUrl,
      ),
    );
  }

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _reviewState = ReviewState();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    _reviewState.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reviewState.rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn số sao đánh giá!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _reviewState.setSubmitting(true);
    try {
      await ApiService.submitReview(
        sessionId: widget.sessionId,
        rating: _reviewState.rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        tags: _reviewState.selectedTags.toList(),
      );

      if (mounted) {
        Navigator.pop(context, true); // true = review thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Cảm ơn bạn đã đánh giá! 🌟'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _reviewState.setSubmitting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reviewState,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // ── HEADER: Avatar + Tên thợ ──
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.orange[300]!, Colors.orange[700]!],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: widget.technicianAvatarUrl != null
                              ? NetworkImage(widget.technicianAvatarUrl!)
                              : null,
                          child: widget.technicianAvatarUrl == null
                              ? const Icon(Icons.person, size: 42, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Đánh giá chất lượng dịch vụ',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.technicianName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 16),

                // ── STAR RATING ──
                const Text(
                  'Bạn cảm thấy dịch vụ thế nào?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildStarRating(),
                if (_reviewState.rating > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    _getRatingLabel(_reviewState.rating),
                    style: TextStyle(
                      color: _getRatingColor(_reviewState.rating),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── TAGS ──
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Điều bạn ấn tượng nhất:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                _buildTagChips(),

                const SizedBox(height: 20),

                // ── COMMENT BOX ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Chia sẻ thêm trải nghiệm của bạn... (tùy chọn)',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── SUBMIT BUTTON ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _reviewState.isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.orange[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _reviewState.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'GỬI ĐÁNH GIÁ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Đánh giá sau',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => _reviewState.setRating(starIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Icon(
              starIndex <= _reviewState.rating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: starIndex <= _reviewState.rating ? 46 : 40,
              color: starIndex <= _reviewState.rating
                  ? Colors.amber[600]
                  : Colors.grey[300],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTagChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReviewState.availableTags.map((tag) {
        final isSelected = _reviewState.selectedTags.contains(tag);
        return GestureDetector(
          onTap: () => _reviewState.toggleTag(tag),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange[700] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.orange[700]! : Colors.grey[300]!,
              ),
            ),
            child: Text(
              isSelected ? '✓ $tag' : tag,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1: return 'Rất tệ 😞';
      case 2: return 'Không hài lòng 😕';
      case 3: return 'Bình thường 😐';
      case 4: return 'Hài lòng 😊';
      case 5: return 'Tuyệt vời! 🤩';
      default: return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating <= 2) return Colors.redAccent;
    if (rating == 3) return Colors.orange;
    return Colors.green;
  }
}
