import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import 'add_device_screen.dart';
import 'chat_screen.dart';

// ─── Design Tokens (ĐỒNG BỘ DARK THEME) ───────────────────────────
const _kBg = Color(0xff081125); // Nền tối sâu thẫm
const _kSurface = Color(0xff111B3D); // Thẻ card tối nâng nền
const _kPrimaryCyan = Color(0xff00B0FF); // Xanh dương neon link
const _kPrimaryGreen = Color(0xff00E676); // Xanh ngọc neon accent
const _kTextSub = Color(0xff8E9AA6); // Xám sáng cho sub-text

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

  // ─── Helpers (ĐỒNG BỘ MÀU ICON THEO NỀN TỐI) ───────────────────────

  _DeviceStyle _getDeviceStyle(String category) {
    final c = category.toLowerCase();
    if (c.contains('lạnh') || c.contains('điều hòa')) {
      return const _DeviceStyle(Icons.ac_unit_rounded, _kPrimaryCyan, _kBg);
    }
    if (c.contains('tủ lạnh')) {
      return const _DeviceStyle(Icons.kitchen_rounded, _kPrimaryGreen, _kBg);
    }
    if (c.contains('giặt')) {
      return const _DeviceStyle(
        Icons.local_laundry_service_rounded,
        Color(0xFFCE93D8),
        _kBg,
      );
    }
    if (c.contains('tivi') || c.contains('ti vi')) {
      return const _DeviceStyle(Icons.tv_rounded, Color(0xFFEF9A9A), _kBg);
    }
    if (c.contains('quạt')) {
      return const _DeviceStyle(
        Icons.wind_power_rounded,
        Color(0xFF80DEEA),
        _kBg,
      );
    }
    if (c.contains('bếp') || c.contains('lò')) {
      return const _DeviceStyle(
        Icons.microwave_rounded,
        Colors.orangeAccent,
        _kBg,
      );
    }
    if (c.contains('nước') || c.contains('bình')) {
      return const _DeviceStyle(
        Icons.water_drop_rounded,
        Color(0xFF90CAF9),
        _kBg,
      );
    }
    return const _DeviceStyle(
      Icons.electrical_services_rounded,
      _kTextSub,
      _kBg,
    );
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

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: _kPrimaryGreen,
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kBg,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Kho thiết bị',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: Colors.white,
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
                color: _kSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 20, color: _kPrimaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'Thêm',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _kPrimaryGreen,
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
        child: Divider(height: 1, color: Colors.white.withOpacity(0.05)),
      ),
    );
  }

  Widget _buildList(DeviceProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.fetchDevices,
      color: _kPrimaryGreen,
      backgroundColor: _kSurface,
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

  Widget _buildDeviceCard(dynamic device, DeviceProvider provider) {
    final style = _getDeviceStyle(device.category ?? '');
    final status = _getMaintenance(device.nextMaintenanceDate);
    final isOverdue = status == _MaintenanceStatus.overdue;

    final loc = device.location?.toString().trim() ?? '';
    final showLoc = loc.isNotEmpty && loc.toLowerCase() != 'không xác định';
    final displayName = '${device.brandName ?? ''} ${device.category ?? ''}'
        .trim();

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? Colors.redAccent.withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // TODO: Điều hướng sang màn hình chi tiết thiết bị
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Device Icon ────────────────────────────────────
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: style.bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.02),
                        ),
                      ),
                      child: Icon(style.icon, color: style.iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),

                    // ── Info ───────────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty
                                ? 'Thiết bị chưa đặt tên'
                                : displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showLoc) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: _kTextSub.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _kTextSub,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildStatusBadge(status, device.nextMaintenanceDate),
                        ],
                      ),
                    ),

                    // ── Menu (ĐÃ ĐƯỢC FIX LỖI BACKGROUNDCOLOR QUA POPUPMENUSTYLE) ──
                    Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 22,
                          color: Colors.white30,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Colors.white10,
                            width: 1,
                          ),
                        ),
                        // Fix: Sử dụng `style` thay vì gán trực tiếp thuộc tính ko tồn tại
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(_kSurface),
                        ),
                        onSelected: (value) =>
                            _onMenuSelected(value, device, provider),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  size: 18,
                                  color: Colors.redAccent.withOpacity(0.8),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Xóa thiết bị',
                                  style: TextStyle(
                                    color: Colors.redAccent.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
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

                // ── CTA Area ───────────────────
                if (isOverdue || status == _MaintenanceStatus.soon) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _markAsMaintained(device, provider),
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Đã bảo trì',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _kPrimaryGreen,
                            backgroundColor: _kPrimaryGreen.withOpacity(0.1),
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
                                builder: (_) =>
                                    ChatScreen(initialDevice: displayName),
                              ),
                            );
                          },
                          icon: const Icon(Icons.handyman_rounded, size: 16),
                          label: const Text(
                            'Gọi thợ ngay',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isOverdue
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                            side: BorderSide(
                              color: isOverdue
                                  ? Colors.redAccent.withOpacity(0.5)
                                  : Colors.orangeAccent.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isOverdue
                                ? Colors.redAccent.withOpacity(0.05)
                                : Colors.orangeAccent.withOpacity(0.05),
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

  // ─── Status Badges ─────────────────────────────
  Widget _buildStatusBadge(_MaintenanceStatus status, DateTime? date) {
    switch (status) {
      case _MaintenanceStatus.overdue:
        return _badge(
          'Quá hạn bảo trì',
          const Color(0xFFEF9A9A),
          _kBg,
          const Color(0xFFEF9A9A),
          Icons.error_outline_rounded,
        );
      case _MaintenanceStatus.soon:
        return _badge(
          'Sắp đến hạn',
          Colors.orangeAccent,
          _kBg,
          Colors.orangeAccent,
          Icons.warning_amber_rounded,
        );
      case _MaintenanceStatus.good:
        return _badge(
          'Hoạt động tốt',
          _kPrimaryGreen,
          _kBg,
          _kPrimaryGreen,
          Icons.check_circle_outline_rounded,
        );
      case _MaintenanceStatus.unknown:
        return _badge(
          'Chưa có lịch',
          _kTextSub,
          const Color(0xff1A244D),
          Colors.white10,
          Icons.help_outline_rounded,
        );
    }
  }

  Widget _badge(
    String label,
    Color text,
    Color bg,
    Color border,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.4), width: 1),
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

  // ─── Empty State ─────────────────────────────────────────────────
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
                color: _kSurface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Icon(
                Icons.devices_other_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có thiết bị nào',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hãy thêm thiết bị để SmartElec theo dõi lịch bảo trì và chẩn đoán kịp thời nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kTextSub, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [_kPrimaryGreen, _kPrimaryCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimaryGreen.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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

  // ─── Handlers ────────────────────────────────────────────────────

  Future<void> _onMenuSelected(
    String value,
    dynamic device,
    DeviceProvider provider,
  ) async {
    if (value == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddDeviceScreen(device: device)),
      );
    } else if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          title: const Text(
            'Xóa thiết bị?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: const Text(
            'Thiết bị và các lịch sử liên quan sẽ bị xóa vĩnh viễn khỏi hệ thống.',
            style: TextStyle(color: _kTextSub, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Hủy',
                style: TextStyle(color: _kTextSub, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
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
        Provider.of<DeviceProvider>(
          context,
          listen: false,
        ).deleteDevice(device.id);
      }
    }
  }

  Future<void> _markAsMaintained(
    dynamic device,
    DeviceProvider provider,
  ) async {
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
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã reset! Lần bảo trì tới: ${newDate.day}/${newDate.month}/${newDate.year}',
                    style: const TextStyle(color: Colors.white),
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
            backgroundColor: Colors.redAccent,
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

// ─── Private Models ────────────────────────────────────────────────

class _DeviceStyle {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _DeviceStyle(this.icon, this.iconColor, this.bgColor);
}

enum _MaintenanceStatus { overdue, soon, good, unknown }
