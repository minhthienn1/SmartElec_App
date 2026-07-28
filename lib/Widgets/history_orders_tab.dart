import 'package:flutter/material.dart';
import 'package:smart_elec/services/api_service.dart';
import 'package:smart_elec/Screens/booked_orders_screen.dart'; // Để dùng AppColors

class HistoryOrdersTab extends StatefulWidget {
  const HistoryOrdersTab({super.key});

  @override
  State<HistoryOrdersTab> createState() => _HistoryOrdersTabState();
}

class _HistoryOrdersTabState extends State<HistoryOrdersTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _historyOrders = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedFilter = 'ALL';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchHistory(isRefresh: true);
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        if (_hasMore && !_isLoadingMore && !_isLoading) {
          _fetchHistory(isRefresh: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory({required bool isRefresh}) async {
    if (isRefresh) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _historyOrders.clear();
        _hasMore = true;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiService.getPaginatedHistoryOrders(
        page: _currentPage,
        limit: 10,
        status: _selectedFilter,
      );

      final List<dynamic> data = response['data'];
      final Map<String, dynamic> meta = response['meta'];

      if (!mounted) return;
      setState(() {
        for (var item in data) {
          _historyOrders.add(item);
        }
        _currentPage++;
        _hasMore = _currentPage <= meta['totalPages'];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint("Lỗi tải lịch sử đơn: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
    _fetchHistory(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.kPrimaryOrange))
            : _historyOrders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.kPrimaryOrange,
                  onRefresh: () => _fetchHistory(isRefresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _historyOrders.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _historyOrders.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(color: AppColors.kPrimaryOrange)),
                        );
                      }
                      return _buildHistoryCard(_historyOrders[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.kBackground,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFilterChip("Tất cả", "ALL"),
          _buildFilterChip("Hoàn thành", "COMPLETED"),
          _buildFilterChip("Đã hủy", "CANCELLED"),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          _onFilterChanged(value);
        }
      },
      selectedColor: AppColors.kPrimaryOrange.withOpacity(0.15),
      backgroundColor: AppColors.kInputBackground,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.kPrimaryOrange : AppColors.kTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.kPrimaryOrange : AppColors.kIdleBorder,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: AppColors.kMutedGrey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            "Chưa có đơn hàng nào",
            style: TextStyle(color: AppColors.kTextSecondary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> order) {
    final String status = order["status"] ?? "";
    final bool isCancelled = status == "CANCELLED";
    final Color statusColor = isCancelled ? AppColors.kErrorRed : Colors.green;
    final String statusText = isCancelled ? "Đã hủy" : "Hoàn thành";
    final IconData statusIcon = isCancelled ? Icons.cancel_rounded : Icons.check_circle_rounded;

    // Backend đang trả về: id, title, date, chatSummary, mechanicName...
    final String id = "ORD-${order['id']}";
    final String device = order['title'] ?? "Thiết bị không xác định";
    final String issue = order['chatSummary'] ?? "Không có mô tả";
    // Định dạng ngày (có thể cài thêm intl package để format đẹp hơn, tạm thời parse tay)
    DateTime date = DateTime.now();
    try {
      date = DateTime.parse(order['date']).toLocal();
    } catch (_) {}
    
    final String dateString = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.kInputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    color: AppColors.kMutedGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              device,
              style: TextStyle(
                color: isCancelled ? AppColors.kMutedGrey : AppColors.kTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              "Vấn đề: $issue",
              style: const TextStyle(color: AppColors.kTextSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.kMutedGrey, size: 16),
                const SizedBox(width: 6),
                Text(
                  dateString,
                  style: const TextStyle(
                    color: AppColors.kTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (!isCancelled && order['agreedPrice'] != null)
                  Text(
                    order['agreedPrice'],
                    style: const TextStyle(
                      color: AppColors.kPrimaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}
