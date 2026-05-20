import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';
import '../models/repair_case.dart';
import 'repair_detail_screen.dart';
import 'repair_history_screen.dart';
import '../providers/device_provider.dart';
import '../providers/user_provider.dart';
import '../Widgets/quick_booking_dialog.dart';
import '../Widgets/booking_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<RepairCase> _recentRepairs = [];
  bool _isLoadingHistory = false;
  bool _isCreatingEmergencySession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DeviceProvider>(context, listen: false).fetchDevices();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadHistory();
    }
  }

  Future<void> loadHistory() async {
    if (_isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);
    try {
      final history = await ApiService.getHistory();
      if (mounted) {
        setState(() {
          _recentRepairs = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải lịch sử: $e");
      if (mounted) {
        setState(() {
          _recentRepairs = [];
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> triggerEmergencyBooking() async {
    showDialog(
      context: context,
      builder: (_) => QuickBookingDialog(
        onConfirm: (device, symptom) async {
          setState(() => _isCreatingEmergencySession = true);
          try {
            // 1. Tạo phiên chẩn đoán "ảo" trên server để lấy sessionId ngay lập tức
            final sessionId = await ApiService.createQuickSession(
              device,
              symptom,
            );

            if (mounted) {
              // 2. Mở thẳng BookingBottomSheet nhập thông tin chi tiết
              showModalBottomSheet(
                context: context, // Sử dụng HomeScreen context không bị shadow
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BookingBottomSheet(
                  sessionId: sessionId,
                  deviceType: device,
                  symptom: symptom,
                  onConfirm: (data) async {
                    await ApiService.bookTechnician(sessionId, data);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "✅ Đã chốt đơn! Hệ thống đang phát sóng tìm thợ quanh khu vực của bạn.",
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ).then((_) => loadHistory());
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Lỗi tạo đơn: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isCreatingEmergencySession = false);
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff081125),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await loadHistory();
            if (context.mounted) {
              await Provider.of<DeviceProvider>(
                context,
                listen: false,
              ).fetchDevices();
            }
          },
          color: const Color(0xff00E676),
          backgroundColor: const Color(0xff111B3D),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent:
                  AlwaysScrollableScrollPhysics(), // Đảm bảo luôn kéo refresh được ngay cả khi ít item
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const HeaderSection(),
                const SizedBox(height: 20),
                const MaintenanceAlertCard(),
                const SizedBox(height: 24),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Chẩn đoán thiết bị",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                CategoryHorizontal(
                  onCategoryTap: (deviceName) {
                    if (deviceName == "Thêm") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RepairHistoryScreen(),
                        ),
                      ).then((_) => loadHistory());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(initialDevice: deviceName),
                        ),
                      ).then((_) => loadHistory());
                    }
                  },
                ),
                const SizedBox(height: 20),
                QuickBookingCard(
                  isLoading: _isCreatingEmergencySession,
                  onTap: triggerEmergencyBooking,
                ),
                const SizedBox(height: 24),

                RecentRepairSection(
                  repairs: _recentRepairs,
                  onRefresh: loadHistory,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe dữ liệu người dùng từ UserProvider toàn cục
    final user = context.watch<UserProvider>().user;
    final fullName = user?.fullName ?? "Bạn";
    final avatarUrl = user?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xff111B3D),
              border: Border.all(color: const Color(0xff00E676), width: 1.5),
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Colors.grey),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.person, color: Colors.white70),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chào $fullName 👋",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Hôm nay thiết bị nhà bạn thế nào?",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff111B3D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceAlertCard extends StatelessWidget {
  const MaintenanceAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        int warningCount = 0;
        final now = DateTime.now();

        for (var device in provider.devices) {
          if (device.nextMaintenanceDate != null) {
            final daysUntil = device.nextMaintenanceDate!
                .difference(now)
                .inDays;
            if (daysUntil <= 15) {
              warningCount++;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: const Color(0xff111B3D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xff1A2B5C)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff00E676), Color(0xff00B0FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xff00E676).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          warningCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: const Color(0xff00E676),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              warningCount > 0
                                  ? "Cảnh báo bảo trì"
                                  : "Tất cả đều ổn!",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              warningCount > 0
                                  ? "Bạn có $warningCount thiết bị sắp đến hạn bảo trì."
                                  : "Các thiết bị trong nhà đang hoạt động ổn định.",
                              style: const TextStyle(
                                color: Color(0xff9EA9C1),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryHorizontal extends StatelessWidget {
  final Function(String) onCategoryTap;
  const CategoryHorizontal({super.key, required this.onCategoryTap});

  static const List<Map<String, dynamic>> items = [
    {"icon": Icons.microwave, "name": "Lò vi sóng"},
    {"icon": Icons.rice_bowl, "name": "Nồi cơm"},
    {"icon": Icons.local_drink, "name": "Ấm đun"},
    {"icon": Icons.kitchen, "name": "Máy xay"},
    {"icon": Icons.kitchen_outlined, "name": "Tủ lạnh"},
    {"icon": Icons.lightbulb_outline, "name": "Đèn"},
    {"icon": Icons.ac_unit, "name": "Máy lạnh"},
    {"icon": Icons.local_laundry_service, "name": "Máy giặt"},
    {"icon": Icons.tv, "name": "Tivi"},
    {"icon": Icons.iron, "name": "Bàn ủi"},
    {"icon": Icons.cleaning_services, "name": "Máy hút bụi"},
    {"icon": Icons.more_horiz, "name": "Thêm"},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 185,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => onCategoryTap(item["name"]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff111B3D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Icon(
                    item["icon"],
                    color: const Color(0xff00E676),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item["name"],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xffE0E0E0),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RecentRepairSection extends StatelessWidget {
  final List<RepairCase> repairs;
  final VoidCallback onRefresh;
  const RecentRepairSection({
    super.key,
    required this.repairs,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff111B3D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ca chẩn đoán gần đây",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RepairHistoryScreen(),
                      ),
                    ).then((_) => onRefresh());
                  },
                  child: const Text(
                    "Xem tất cả →",
                    style: TextStyle(
                      color: Color(0xff00B0FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (repairs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 44,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Chưa có lịch sử chẩn đoán lỗi",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...repairs.take(3).map((item) => _buildRepairItem(item, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildRepairItem(RepairCase item, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepairDetailScreen(repairCase: item),
          ),
        ).then((_) => onRefresh());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xff1A244D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.02)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(item.date),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white30,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class QuickBookingCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const QuickBookingCard({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xff0052D4), Color(0xff0078d4), Color(0xff00b0ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff0078d4).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bạn cần thợ gấp?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Hãy đặt thợ ngay để được hỗ trợ trong 30p",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff0078d4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xff0078d4),
                      ),
                    )
                  : const Text(
                      "ĐẶT NGAY",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
