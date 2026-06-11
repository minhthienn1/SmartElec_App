import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import 'add_device_screen.dart';
import 'chat_screen.dart';

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

class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({super.key});

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceProvider>(context, listen: false).fetchDevices();
    });
  }

  // ─── Helpers: Định dạng phong cách Icon theo chuẩn Nền Sáng ─────────────────
  _DeviceStyle _getDeviceStyle(String category) {
    final c = category.toLowerCase();
    if (c.contains('lạnh') || c.contains('điều hòa')) {
      return const _DeviceStyle(Icons.ac_unit_rounded, Color(0xFF0288D1));
    }
    if (c.contains('tủ lạnh')) {
      return const _DeviceStyle(Icons.kitchen_rounded, Color(0xFF2E7D32));
    }
    if (c.contains('giặt')) {
      return const _DeviceStyle(Icons.local_laundry_service_rounded, Color(0xFF7B1FA2));
    }
    if (c.contains('tivi') || c.contains('ti vi')) {
      return const _DeviceStyle(Icons.tv_rounded, Color(0xFFC62828));
    }
    if (c.contains('quạt')) {
      return const _DeviceStyle(Icons.wind_power_rounded, Color(0xFF00838F));
    }
    if (c.contains('bếp') || c.contains('lò')) {
      return const _DeviceStyle(Icons.microwave_rounded, AppColors.kPrimaryOrange);
    }
    if (c.contains('nước') || c.contains('bình')) {
      return const _DeviceStyle(Icons.water_drop_rounded, Color(0xFF1565C0));
    }
    return const _DeviceStyle(Icons.electrical_services_rounded, AppColors.kTextSecondary);
  }

  _MaintenanceStatus _getMaintenance(DateTime? date) {
    if (date == null) return _MaintenanceStatus.unknown;
    final diff = date.difference(DateTime.now()).inDays;
    if (diff < 0) return _MaintenanceStatus.overdue;
    if (diff <= 7) return _MaintenanceStatus.soon;
    return _MaintenanceStatus.good;
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
  }

  // ─── Build Giao Diện Gốc ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: _buildAppBar(),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.kPrimaryOrange,
                strokeWidth: 3,
              ),
            );
          }
          if (provider.devices.isEmpty) return _buildEmptyState();
          return _buildList(provider);
        },
      ),
    );
  }

  // ─── Thanh AppBar Nền Sáng Chữ Tối ────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.kBackground,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Kho thiết bị',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: AppColors.kTextPrimary,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            onTap: _navigateToAdd,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.kLightOrange,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.kPrimaryOrange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 20, color: AppColors.kDarkOrange),
                  SizedBox(width: 6),
                  Text(
                    'Thêm',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.kDarkOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.kIdleBorder.withOpacity(0.4)),
      ),
    );
  }

  // ─── Danh Sách Cuộn Làm Mới ────────────────────────────────────────────────
  Widget _buildList(DeviceProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.fetchDevices,
      color: AppColors.kPrimaryOrange,
      backgroundColor: Colors.white,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        itemCount: provider.devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _buildDeviceCard(provider.devices[index], provider);
        },
      ),
    );
  }

  // ─── Thẻ Thiết Bị Màu Trắng Tinh Tế (Device Card) ──────────────────────────
  Widget _buildDeviceCard(dynamic device, DeviceProvider provider) {
    final style = _getDeviceStyle(device.category ?? '');
    final status = _getMaintenance(device.nextMaintenanceDate);
    final isOverdue = status == _MaintenanceStatus.overdue;

    final loc = device.location?.toString().trim() ?? '';
    final showLoc = loc.isNotEmpty && loc.toLowerCase() != 'không xác định';
    final displayName = '${device.brandName ?? ''} ${device.category ?? ''}'.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.kInputBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? AppColors.kErrorRed.withOpacity(0.5)
              : AppColors.kIdleBorder.withOpacity(0.5),
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // TODO: Điều hướng sang màn hình chi tiết thiết bị nếu cần
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon thiết bị với nền nhạt đồng điệu theo màu icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: style.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(style.icon, color: style.iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),

                    // Thông tin tên và vị trí thiết bị
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty ? 'Thiết bị chưa đặt tên' : displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.kTextPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showLoc) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: AppColors.kMutedGrey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.kTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildStatusBadge(status),
                        ],
                      ),
                    ),

                    // Nút Thao Tác Thêm (Popup Menu chuẩn Nền Sáng)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 22,
                        color: AppColors.kMutedGrey,
                      ),
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.kIdleBorder, width: 0.5),
                      ),
                      onSelected: (value) => _onMenuSelected(value, device, provider),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18, color: AppColors.kTextSecondary),
                              SizedBox(width: 12),
                              Text(
                                'Chỉnh sửa',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: AppColors.kErrorRed.withOpacity(0.9)),
                              SizedBox(width: 12),
                              Text(
                                'Xóa thiết bị',
                                style: TextStyle(
                                  color: AppColors.kErrorRed.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Vùng nút CTA phản hồi nhanh khi thiết bị cần chú ý bảo trì
                if (isOverdue || status == _MaintenanceStatus.soon) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AppColors.kIdleBorder.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _markAsMaintained(device, provider),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text(
                            'Đã bảo trì',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green[700],
                            backgroundColor: Colors.green[50],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(initialDevice: displayName),
                              ),
                            );
                          },
                          icon: const Icon(Icons.handyman_rounded, size: 16),
                          label: const Text(
                            'Gọi thợ ngay',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isOverdue ? AppColors.kErrorRed : AppColors.kPrimaryOrange,
                            side: BorderSide(
                              color: isOverdue
                                  ? AppColors.kErrorRed.withOpacity(0.4)
                                  : AppColors.kPrimaryOrange.withOpacity(0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isOverdue
                                ? AppColors.kErrorRed.withOpacity(0.05)
                                : AppColors.kLightOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Nhãn Trạng Thái Đồng Bộ Hệ Nền Sáng (Status Badges) ────────────────────
  Widget _buildStatusBadge(_MaintenanceStatus status) {
    switch (status) {
      case _MaintenanceStatus.overdue:
        return _badge(
          'Quá hạn bảo trì',
          AppColors.kErrorRed,
          AppColors.kErrorRed.withOpacity(0.08),
          AppColors.kErrorRed.withOpacity(0.3),
          Icons.error_outline_rounded,
        );
      case _MaintenanceStatus.soon:
        return _badge(
          'Sắp đến hạn',
          AppColors.kPrimaryOrange,
          AppColors.kLightOrange,
          AppColors.kPrimaryOrange.withOpacity(0.3),
          Icons.warning_amber_rounded,
        );
      case _MaintenanceStatus.good:
        return _badge(
          'Hoạt động tốt',
          Colors.green[700]!,
          Colors.green[50]!,
          Colors.green[200]!,
          Icons.check_circle_outline_rounded,
        );
      case _MaintenanceStatus.unknown:
        return _badge(
          'Chưa có lịch',
          AppColors.kTextSecondary,
          Colors.grey[100]!,
          AppColors.kIdleBorder.withOpacity(0.5),
          Icons.help_outline_rounded,
        );
    }
  }

  Widget _badge(String label, Color text, Color bg, Color border, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Màn Hình Trống Tinh Khôi Điểm Nhấn Cam (Empty State) ─────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.kLightOrange,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.kPrimaryOrange.withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.devices_other_rounded,
                size: 64,
                color: AppColors.kPrimaryOrange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có thiết bị nào',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hãy thêm thiết bị để SmartElec theo dõi lịch bảo trì và chẩn đoán kịp thời nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, 
                color: AppColors.kTextSecondary, 
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.kPrimaryOrange, AppColors.kDarkOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kPrimaryOrange.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                label: const Text(
                  'Thêm thiết bị đầu tiên',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Xử Lý Xóa Thiết Bị (Xác nhận qua Alert Dialog sáng sủa) ─────────────
  Future<void> _onMenuSelected(String value, dynamic device, DeviceProvider provider) async {
    if (value == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddDeviceScreen(device: device)),
      );
    } else if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.kIdleBorder, width: 0.5),
          ),
          title: const Text(
            'Xóa thiết bị?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
          ),
          content: const Text(
            'Thiết bị và các lịch sử liên quan sẽ bị xóa vĩnh viễn khỏi hệ thống.',
            style: TextStyle(color: AppColors.kTextSecondary, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.kTextSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kErrorRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Xóa thiết bị',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        Provider.of<DeviceProvider>(context, listen: false).deleteDevice(device.id);
      }
    }
  }

  // ─── Xử Lý Đã Bảo Trì Thiết Bị (Update thành công & hiện SnackBar) ──────────
  Future<void> _markAsMaintained(dynamic device, DeviceProvider provider) async {
    HapticFeedback.mediumImpact();
    final int cycle = device.maintenanceCycleMonths ?? 6;
    final newDate = DateTime.now().add(Duration(days: 30 * cycle));

    try {
      await provider.updateDevice(device.id, {
        'nextMaintenanceDate': newDate.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã cập nhật! Lần bảo trì tới: ${newDate.day}/${newDate.month}/${newDate.year}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã xảy ra lỗi: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.kErrorRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

// ─── Private Models ──────────────────────────────────────────────────────────

class _DeviceStyle {
  final IconData icon;
  final Color iconColor;
  const _DeviceStyle(this.icon, this.iconColor);
}

enum _MaintenanceStatus { overdue, soon, good, unknown }