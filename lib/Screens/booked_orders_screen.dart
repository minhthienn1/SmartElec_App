import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_elec/services/api_service.dart'; 
import 'package:smart_elec/services/chat_socket_service.dart'; 

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

class BookedOrdersScreen extends StatefulWidget {
  const BookedOrdersScreen({super.key});

  @override
  State<BookedOrdersScreen> createState() => _BookedOrdersScreenState();
}

class _BookedOrdersScreenState extends State<BookedOrdersScreen> {
  Timer? _timer;
  bool _isLoading = true;
  List<Map<String, dynamic>> _liveOrders = []; // Đổi từ mock sang live data

  @override
  void initState() {
    super.initState();
    _fetchOrders();

    // Lắng nghe sự kiện từ Socket (Khi thợ nhận đơn hoặc trạng thái thay đổi)
    _setupSocketListeners();

    // Timer chỉ còn nhiệm vụ duy nhất là làm tươi giao diện mỗi 60s để dòng text "Đã đặt X phút trước" nhảy số.
    // Việc hủy đơn do Timeout giờ đã được Backend (Cronjob) lo và bắn Socket về.
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _removeSocketListeners();
    super.dispose();
  }

  // --- KẾT NỐI API VÀ MAP DỮ LIỆU ---
  Future<void> _fetchOrders() async {
    try {
      final List<dynamic> rawData = await ApiService.getActiveRunningSessions();
      
      if (!mounted) return;

      setState(() {
        _liveOrders = rawData.map((item) {
          // Map trạng thái Prisma sang UI
          String uiStatus = "pending"; // Mặc định là BROADCASTING
          if (['MATCHED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS'].contains(item['status'])) {
            uiStatus = "accepted";
          } else if (item['status'] == 'CANCELLED') {
            uiStatus = "cancelled";
          }

          // Lấy tên thiết bị (Ưu tiên từ bảng Device, nếu không có thì lấy chuỗi thiết bị nhập tay)
          String deviceName = item['device'] != null ? item['device']['category'] : (item['deviceType'] ?? "Thiết bị không xác định");

          return {
            "id": "ORD-${item['id']}", // Hiển thị mã đẹp
            "realId": item['id'], // Giữ ID thật để gọi API tương tác
            "device": deviceName,
            "issue": item['symptom'] ?? item['aiSummary'] ?? "Chưa rõ vấn đề",
            "createdAt": DateTime.parse(item['createdAt']).toLocal(),
            "severity": item['isDangerous'] == true ? "high" : "medium",
            "status": uiStatus,
            "hasShownPopup": false,
          };
        }).toList();
        
        _isLoading = false;
      });
      
      // Chạy check lại xem có đơn khẩn cấp nào vượt 10p không để hiện popup (dự phòng)
      _checkEmergencyPopup();

    } catch (e) {
      debugPrint("Lỗi tải đơn hàng: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LẮNG NGHE SOCKET THỜI GIAN THỰC ---
  void _setupSocketListeners() {
    final socket = ChatSocketService().socket;
    if (socket == null) return;

    socket.on('job_status_changed', _onSocketEvent);
    socket.on('job_accepted', _onSocketEvent);
  }

  void _removeSocketListeners() {
    final socket = ChatSocketService().socket;
    if (socket == null) return;
    socket.off('job_status_changed', _onSocketEvent);
    socket.off('job_accepted', _onSocketEvent);
  }

  void _onSocketEvent(dynamic data) {
    // Khi có biến động, gọi lại API để lấy dữ liệu mới nhất cho an toàn và đồng bộ
    debugPrint("Nhận sự kiện Socket, tải lại danh sách đơn...");
    _fetchOrders();
  }

  // --- LOGIC POPUP KHẨN CẤP DỰ PHÒNG ---
  void _checkEmergencyPopup() {
    bool needsUpdate = false;
    for (var order in _liveOrders) {
      if (order["status"] == "pending" && order["severity"] == "high") {
        final elapsedMins = DateTime.now().difference(order["createdAt"]).inMinutes;
        if (elapsedMins >= 10 && order["hasShownPopup"] == false) {
          order["hasShownPopup"] = true;
          needsUpdate = true;
          Future.delayed(Duration.zero, () {
            if (mounted) _showEmergencyHotlinePopup(order["device"]);
          });
        }
      }
    }
    if (needsUpdate && mounted) setState(() {});
  }

  void _showEmergencyHotlinePopup(String deviceName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.kBackground,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.kErrorRed, size: 28),
            SizedBox(width: 10),
            Text("Quá tải thợ khu vực!", style: TextStyle(color: AppColors.kErrorRed, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Hệ thống hiện không có thợ nhận đơn sửa khẩn cấp cho '$deviceName'. Để đảm bảo an toàn điện, vui lòng liên hệ ngay Hotline để chúng tôi điều phối khẩn cấp.",
          style: const TextStyle(color: AppColors.kTextPrimary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Đóng", style: TextStyle(color: AppColors.kMutedGrey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kErrorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.call, color: Colors.white, size: 18),
            label: const Text("Gọi 1900-xxxx", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  String _getElapsedTime(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return "Vừa xong";
    if (difference.inMinutes < 60) return "Đã đặt ${difference.inMinutes} phút trước";
    if (difference.inHours < 24) return "Đã đặt ${difference.inHours} giờ ${difference.inMinutes % 60} phút trước";
    return "Đã đặt ${difference.inDays} ngày trước";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.kTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Đơn đã đặt hiện tại",
          style: TextStyle(
            color: AppColors.kTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.kPrimaryOrange))
          : _liveOrders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.kPrimaryOrange,
                  onRefresh: _fetchOrders, // Kéo xuống để tải lại thủ công
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _liveOrders.length,
                    itemBuilder: (context, index) {
                      final order = _liveOrders[index];
                      return _buildOrderCard(order);
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
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: AppColors.kMutedGrey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            "Không có đơn hàng nào đang xử lý",
            style: TextStyle(color: AppColors.kTextSecondary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final bool isHighSeverity = order["severity"] == "high";
    final String status = order["status"] ?? "pending";
    
    final Color badgeBgColor = isHighSeverity ? AppColors.kErrorRed.withOpacity(0.1) : AppColors.kLightOrange;
    final Color badgeTextColor = isHighSeverity ? AppColors.kErrorRed : AppColors.kPrimaryOrange;
    final String badgeText = isHighSeverity ? "Khẩn cấp" : "Sửa thường";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.kInputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == "cancelled" 
              ? AppColors.kErrorRed.withOpacity(0.3) 
              : AppColors.kIdleBorder.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        key: ValueKey(order["id"]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order["id"],
                  style: const TextStyle(
                    color: AppColors.kMutedGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: status == "cancelled" ? AppColors.kMutedGrey.withOpacity(0.1) : AppColors.kLightOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.electrical_services_rounded, 
                    color: status == "cancelled" ? AppColors.kMutedGrey : AppColors.kPrimaryOrange, 
                    size: 20
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order["device"],
                    style: TextStyle(
                      color: status == "cancelled" ? AppColors.kMutedGrey : AppColors.kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: status == "cancelled" ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: AppColors.kTextSecondary),
                children: [
                  const TextSpan(text: "Vấn đề: ", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.kTextPrimary)),
                  TextSpan(text: order["issue"]),
                ],
              ),
            ),
            
            const Divider(height: 24, thickness: 0.8),

            _buildStatusFooter(status, order),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFooter(String status, Map<String, dynamic> order) {
    if (status == "accepted") {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_rounded, color: AppColors.kPrimaryOrange, size: 18),
              const SizedBox(width: 6),
              const Text(
                "Đang tiến hành",
                style: TextStyle(
                  color: AppColors.kPrimaryOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kLightOrange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.kPrimaryOrange, size: 16),
            label: const Text(
              "Chat ngay",
              style: TextStyle(color: AppColors.kPrimaryOrange, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              // Bắt sự kiện bấm chat bằng ID thật
              debugPrint("Mở chat cho đơn ID thật: ${order["realId"]}");
              // TODO: Điều hướng sang màn hình chat 
              // Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(sessionId: order["realId"])));
            },
          ),
        ],
      );
    } else if (status == "cancelled") {
      return Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.kErrorRed, size: 16),
          const SizedBox(width: 6),
          const Text(
            "Đã hủy - Hệ thống quá tải",
            style: TextStyle(
              color: AppColors.kErrorRed,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
               // Có thể gọi lại API redispatchJob hoặc về trang chủ
               Navigator.pop(context);
            },
            child: const Text("Đặt lại", style: TextStyle(color: AppColors.kPrimaryOrange, fontSize: 13)),
          )
        ],
      );
    } else {
      return Row(
        children: [
          const Icon(Icons.access_time_rounded, color: AppColors.kMutedGrey, size: 16),
          const SizedBox(width: 6),
          Text(
            _getElapsedTime(order["createdAt"]),
            style: const TextStyle(
              color: AppColors.kTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            "Đang kết nối thợ...",
            style: TextStyle(
              color: AppColors.kDarkOrange.withOpacity(0.8),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          )
        ],
      );
    }
  }
}