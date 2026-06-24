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
import '../providers/notification_badge_provider.dart';
import '../Widgets/quick_booking_dialog.dart';
import '../Widgets/booking_bottom_sheet.dart';
import 'ai_history_screen.dart';
import 'dart:async';
import 'ai_chat_summary_screen.dart';
import 'booked_orders_screen.dart';


// --- ĐỊNH NGHĨA BẢNG MÀU CHUẨN ---
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<RepairCase> _recentRepairs = [];
  bool _isLoadingHistory = false;
  bool _isCreatingEmergencySession = false;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scrollController = ScrollController();
    
    // Lắng nghe sự kiện cuộn để xử lý Bottom Nav sau này
    scrollController.addListener(() {
      // Logic ẩn hiện sẽ được kết nối với file MainScreen của bạn
    });

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
            final sessionId = await ApiService.createQuickSession(device, symptom);

            if (mounted) {
              showModalBottomSheet(
                context: context,
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
                            "Đã chốt đơn! Hệ thống đang tìm thợ quanh khu vực của bạn.",
                          ),
                          backgroundColor: AppColors.kPrimaryOrange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ).then((_) {
                // Đợi một nhịp nhỏ để animation đóng mảng xám hoàn tất rồi mới load lại data
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) loadHistory();
                });
              });
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Lỗi tạo đơn: $e"),
                  backgroundColor: AppColors.kErrorRed,
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
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await loadHistory();
            if (context.mounted) {
              await Provider.of<DeviceProvider>(context, listen: false).fetchDevices();
            }
          },
          color: AppColors.kPrimaryOrange,
          backgroundColor: Colors.white,
          // ĐỔI SANG CUSTOM SCROLL VIEW
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ĐIỂM 2 & 3: HEADER SLIVER
             SliverAppBar(
                backgroundColor: const Color.fromARGB(255, 255, 255, 255), 
                floating: true, 
                elevation: 0,
                toolbarHeight: 80,
                titleSpacing: 0,
                title: const HeaderSectionSliver(),
              ),
              // NỘI DUNG CHÍNH
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const MaintenanceAlertCard(),
                    
                    const SizedBox(height: 20),
                    // ĐIỂM 1: BANNER QUẢNG CÁO NẰM DƯỚI TRẠNG THÁI
                    const PromoBannerCarousel(),
                    
                    const SizedBox(height: 24),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Dịch vụ sửa chữa",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.kTextPrimary,
                            ),
                          ),
                          Icon(Icons.tune, size: 22, color: AppColors.kTextSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    CategoryHorizontal(
                      onCategoryTap: (deviceName) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(initialDevice: deviceName),
                          ),
                        ).then((_) => loadHistory());
                      },
                    ),
                    const SizedBox(height: 28),
                    
                    QuickBookingCard(
                      isLoading: _isCreatingEmergencySession,
                      onTap: triggerEmergencyBooking,
                    ),
                    const SizedBox(height: 28),

                    RecentRepairSection(
                      repairs: _recentRepairs,
                      onRefresh: loadHistory,
                    ),
                    const SizedBox(height: 24), // Padding đáy cho Bottom Nav
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderSectionSliver extends StatelessWidget {
  const HeaderSectionSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final fullName = user?.fullName ?? "Bạn";
    final avatarUrl = user?.avatarUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.kLightOrange, // Nền cam nhạt lót phía dưới ảnh
              border: Border.all(color: AppColors.kPrimaryOrange, width: 2), // Viền cam thương hiệu
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: AppColors.kPrimaryOrange,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.person, 
                        color: AppColors.kMutedGrey,
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.person, color: AppColors.kMutedGrey),
                  ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "👋 $fullName",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.kTextPrimary, // Màu chữ đen chính
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Cần sửa?, để AI lo!",
                  style: TextStyle(
                    color: AppColors.kTextSecondary, // Màu chữ xám phụ
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // --- NÚT THÔNG BÁO VỚI BADGE ĐỜM Đỏ (CONSUMER) ---
          Consumer<NotificationBadgeProvider>(
            builder: (context, badge, _) {
              return InkWell(
                onTap: () {
                  // Xóa badge khi khách bấm vào
                  badge.clear();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookedOrdersScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(50),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.6)),
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        size: 24,
                        color: AppColors.kTextPrimary,
                      ),
                    ),
                    // Chấm đỏ badge (chỉ hiện khi có thông báo mới chưa đọc)
                    if (badge.hasUnread)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.kErrorRed,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badge.count > 9 ? '9+' : '${badge.count}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// BANNER QUẢNG CÁO (ĐIỂM 1)
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  late PageController _pageController;
  int _realIndex = 0; // Lưu index thật (0, 1, 2)
  Timer? _timer;

  final List<Map<String, dynamic>> banners = [
    {"image": "assets/baoduongmaylanh.png"},
    {"image": "assets/giam15%.jpg"},
    {"image": "assets/vesinhmaygiat.jpg"},
  ];

  @override
  void initState() {
    super.initState();
    // Đặt initialPage là một số rất lớn chia hết cho số lượng banner
    // Để khi vừa vào app, người dùng có thể quẹt trái (lùi lại) thoải mái
    int initialPage = banners.length * 100; 
    _pageController = PageController(initialPage: initialPage, viewportFraction: 0.9);
    _realIndex = initialPage % banners.length;

    // Thiết lập Timer tự động chạy mỗi 3.5 giây
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (Timer timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hủy timer khi rời khỏi màn hình để tránh leak memory
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 125,
          child: PageView.builder(
            controller: _pageController,
            // Không set itemCount để PageView có thể cuộn vô hạn
            onPageChanged: (index) {
              setState(() {
                // Tính toán index thật sự dựa trên phép chia lấy dư
                _realIndex = index % banners.length; 
              });
            },
            itemBuilder: (context, index) {
              // Lấy data banner dựa trên index thật
              final banner = banners[index % banners.length]; 
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    banner["image"],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              // So sánh với _realIndex để sáng đúng chấm tròn
              width: _realIndex == index ? 16 : 6,
              decoration: BoxDecoration(
                color: _realIndex == index ? AppColors.kPrimaryOrange : AppColors.kIdleBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}



class MaintenanceAlertCard extends StatelessWidget {
  const MaintenanceAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        if (provider.devices.isEmpty) {
          return const SizedBox.shrink();
        }
        int warningCount = 0;
        final now = DateTime.now();

        for (var device in provider.devices) {
          if (device.nextMaintenanceDate != null) {
            final daysUntil = device.nextMaintenanceDate!.difference(now).inDays;
            if (daysUntil <= 15) warningCount++;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: warningCount > 0 
                          ? AppColors.kErrorRed 
                          : const Color(0xFF10B981),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (warningCount > 0 ? AppColors.kErrorRed : const Color(0xFF10B981)).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          warningCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: warningCount > 0 ? AppColors.kErrorRed : const Color(0xFF10B981),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              warningCount > 0 ? "Cảnh báo bảo trì" : "Tất cả đều ổn!",
                              style: const TextStyle(
                                color: AppColors.kTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              warningCount > 0
                                  ? "Bạn có $warningCount thiết bị sắp đến hạn bảo trì."
                                  : "Các thiết bị trong nhà đang hoạt động ổn định.",
                              style: const TextStyle(
                                color: AppColors.kTextSecondary,
                                fontSize: 13,
                                height: 1.4,
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

// --- CẬP NHẬT ĐIỂM 2: NÂNG KÍCH THƯỚC ICON & CONTAINER CATEGORY ---
class CategoryHorizontal extends StatelessWidget {
  final Function(String) onCategoryTap;

  const CategoryHorizontal({super.key, required this.onCategoryTap});

  // Các item chính ở ngoài màn hình (9 cái + 1 nút Tất cả)
  static const List<Map<String, dynamic>> primaryItems = [
    {"icon": Icons.ac_unit, "name": "Máy lạnh"},
    {"icon": Icons.local_laundry_service, "name": "Máy giặt"},
    {"icon": Icons.kitchen_outlined, "name": "Tủ lạnh"},
    {"icon": Icons.tv, "name": "Tivi"},
    {"icon": Icons.microwave, "name": "Lò vi sóng"},
    {"icon": Icons.lightbulb_outline, "name": "Đèn"},
    {"icon": Icons.rice_bowl, "name": "Nồi cơm"},
    {"icon": Icons.water_drop, "name": "Máy bơm"},
    {"icon": Icons.mode_fan_off, "name": "Quạt máy"},
    {"icon": Icons.apps, "name": "Tất cả"},
  ];

  // Các item phụ (Đã lọc lại đúng chuẩn điện lạnh/gia dụng)
  static const List<Map<String, dynamic>> extraItems = [
    {"icon": Icons.local_drink, "name": "Ấm đun"},
    {"icon": Icons.blender, "name": "Máy xay"},
    {"icon": Icons.iron, "name": "Bàn ủi"},
    {"icon": Icons.cleaning_services, "name": "Máy hút bụi"},
    {"icon": Icons.hot_tub, "name": "Bình nóng lạnh"},
    {"icon": Icons.water_drop_outlined, "name": "Máy lọc nước"},
    {"icon": Icons.air, "name": "Máy sấy"},
    {"icon": Icons.soup_kitchen, "name": "Bếp điện"},
    {"icon": Icons.heat_pump, "name": "Máy hút mùi"},
    {"icon": Icons.coffee_maker, "name": "Máy pha cafe"},
  ];

  // Hàm gộp danh sách cho Modal "Tất cả"
  List<Map<String, dynamic>> get allItems {
    // Lấy danh sách chính (bỏ nút "Tất cả") + danh sách phụ
    final mainList = primaryItems.where((item) => item["name"] != "Tất cả").toList();
    return [...mainList, ...extraItems];
  }

  // --- WIDGET CARD: TỐI ƯU SIZE & THÊM HIỆU ỨNG NHẤN ---
  Widget _buildCategoryItem(Map<String, dynamic> item, VoidCallback onTap) {
    return Container(
      width: 76, // Thu nhỏ một chút cho thanh thoát
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.kPrimaryOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      // Dùng Material & InkWell để tạo hiệu ứng sóng (ripple) khi nhấn
      child: Material(
        color: AppColors.kLightOrange.withOpacity(0.6), // Background ánh cam
        borderRadius: BorderRadius.circular(15), // Bo góc khớp với Container (trừ đi viền)
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: AppColors.kPrimaryOrange.withOpacity(0.2), // Màu hiệu ứng nhấn
          highlightColor: AppColors.kPrimaryOrange.withOpacity(0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item["icon"],
                color: AppColors.kPrimaryOrange, // Icon cam đậm
                size: 26, // Thu nhỏ icon 
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item["name"],
                  style: const TextStyle(
                    color: AppColors.kTextPrimary, // Chữ đen
                    fontSize: 11, // Thu nhỏ chữ một chút
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllDevicesModal(BuildContext context) {
    final list = allItems; // Dùng danh sách đã gộp
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, // Tăng nhẹ chiều cao modal
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.kIdleBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text("Tất cả thiết bị", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildCategoryItem(list[index], () {
                    Navigator.pop(context);
                    onCategoryTap(list[index]["name"]);
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final row1 = primaryItems.sublist(0, 5);
    final row2 = primaryItems.sublist(5, 10);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: row1.map((item) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildCategoryItem(item, () => onCategoryTap(item["name"])),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: row2.map((item) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildCategoryItem(item, () {
                if (item["name"] == "Tất cả") {
                  _showAllDevicesModal(context);
                } else {
                  onCategoryTap(item["name"]);
                }
              }),
            )).toList(),
          ),
        ],
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.kPrimaryOrange.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.kPrimaryOrange.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.kLightOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flash_on_rounded, 
                color: AppColors.kPrimaryOrange, 
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Cần thợ gấp?",
                    style: TextStyle(
                      color: AppColors.kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Có mặt trong 30 phút",
                    style: TextStyle(
                      color: AppColors.kTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 4,
                shadowColor: AppColors.kPrimaryOrange.withOpacity(0.4),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                    )
                  : const Text(
                      "ĐẶT NGAY", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)
                    ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Lịch sử chat AI",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.kTextPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AiHistoryScreen(),
                      ),
                    ).then((_) => onRefresh());
                  },
                  child: const Text(
                    "Xem thêm →",
                    style: TextStyle(
                      color: AppColors.kPrimaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (repairs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 48,
                        color: AppColors.kMutedGrey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Chưa có lịch sử chẩn đoán lỗi",
                        style: TextStyle(
                          color: AppColors.kTextSecondary,
                          fontSize: 14,
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
    String statusText = "Đang tư vấn";
    Color statusColor = const Color(0xFF2563EB); 
    
    if (item.status == "PENDING_TECHNICIAN") {
      statusText = "Chưa đặt thợ";
      statusColor = AppColors.kPrimaryOrange; 
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiChatSummaryScreen(
              deviceName: item.title, 
              symptom: item.symptom.isNotEmpty ? item.symptom : 'Chưa xác định', 
              aiSummary: item.summary ?? 'Không có tóm tắt phân tích từ AI.', 
            ),
          ),
        ).then((_) => onRefresh());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // Đổi sang nền trắng đồng bộ với Light Mode
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.title, 
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.kTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08), // Giảm nhẹ opacity nhìn cho thanh thoát
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Vấn đề: ${item.symptom.isNotEmpty ? item.symptom : 'Chưa xác định'}", 
              style: const TextStyle(
                color: AppColors.kTextSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.kIdleBorder, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.kMutedGrey, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(item.date),
                      style: const TextStyle(color: AppColors.kMutedGrey, fontSize: 13),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.kPrimaryOrange, 
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}