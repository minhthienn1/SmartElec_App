import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import 'job_detail_screen.dart';

// ─── Constants ────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kDanger = Color(0xFFD32F2F);
const _kBg = Color(0xFFF4F6F9);

// ─── Filter Categories ────────────────────────────────────────────
const List<Map<String, dynamic>> _kFilters = [
  {'label': 'Tất cả', 'icon': Icons.apps_rounded},
  {'label': 'Điện lạnh', 'icon': Icons.ac_unit_rounded},
  {'label': 'Điện nước', 'icon': Icons.plumbing_rounded},
  {'label': 'Gia dụng', 'icon': Icons.kitchen_rounded},
];

class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen>
    with SingleTickerProviderStateMixin {
  int _activeFilter = 0;
  final Set<int> _processingJobs = {};

  // Khởi tạo inline — tránh LateInitializationError khi Flutter gọi build trước initState
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final p = context.read<JobProvider>();
      p.fetchJobs();
      p.initSocket();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String _capitalize(String? s) {
    if (s == null || s.trim().isEmpty) return 'Không rõ';
    final t = s.trim();
    return t[0].toUpperCase() + t.substring(1);
  }

  /// "5 phút trước", "1 giờ trước", v.v.
  String _relativeTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa đăng';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  bool _isUrgent(dynamic job) {
    final s = '${job['aiSummary'] ?? ''} ${job['symptom'] ?? ''}'.toLowerCase();
    return s.contains('nguy hiểm') ||
        s.contains('chập điện') ||
        s.contains('tóe lửa') ||
        s.contains('khẩn cấp') ||
        s.contains('cháy');
  }

  IconData _deviceIcon(String? deviceType) {
    final d = (deviceType ?? '').toLowerCase();
    if (d.contains('lạnh') || d.contains('điều hòa')) {
      return Icons.ac_unit_rounded;
    }
    if (d.contains('nước') || d.contains('ống') || d.contains('vòi')) {
      return Icons.water_drop_rounded;
    }
    if (d.contains('quạt')) return Icons.wind_power_rounded;
    if (d.contains('tủ lạnh')) return Icons.kitchen_rounded;
    if (d.contains('máy giặt')) return Icons.local_laundry_service_rounded;
    if (d.contains('đèn') || d.contains('bóng')) return Icons.lightbulb_rounded;
    if (d.contains('bếp') || d.contains('lò')) return Icons.microwave_rounded;
    if (d.contains('ti vi') || d.contains('tivi')) return Icons.tv_rounded;
    return Icons.electrical_services_rounded;
  }

  // Nhận provider trực tiếp — không dùng context.read bên trong Consumer builder
  List<dynamic> _filteredJobs(List<dynamic> jobs) {
    if (_activeFilter == 0) return jobs;
    final label = _kFilters[_activeFilter]['label'] as String;
    return jobs.where((j) {
      final d = (j['deviceType'] ?? '').toLowerCase();
      if (label == 'Điện lạnh') {
        return d.contains('lạnh') || d.contains('điều hòa');
      }
      if (label == 'Điện nước') return d.contains('nước') || d.contains('ống');
      if (label == 'Gia dụng') {
        return !d.contains('lạnh') && !d.contains('nước');
      }
      return true;
    }).toList();
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đơn sửa chữa mới',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      actions: [
        Consumer<JobProvider>(
          builder: (_, provider, __) => Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (provider.broadcastJobs.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _kDanger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey[200]),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _kFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final active = _activeFilter == i;
            final item = _kFilters[i];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeFilter = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: active ? _kPrimary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? _kPrimary : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 14,
                      color: active ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: active ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<JobProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.broadcastJobs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _kPrimary),
                SizedBox(height: 14),
                Text('Đang tìm đơn...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final jobs = _filteredJobs(provider.broadcastJobs);

        if (jobs.isEmpty) {
          return _buildEmptyState(provider.broadcastJobs.isEmpty);
        }

        return RefreshIndicator(
          onRefresh: provider.fetchJobs,
          color: _kPrimary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: jobs.length,
            itemBuilder: (_, i) => _buildJobCard(jobs[i], provider),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool noJobsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 0.88 + _pulseCtrl.value * 0.12,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.15), 
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kPrimary.withOpacity(0.3), 
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    noJobsAtAll ? Icons.radar : Icons.filter_list_off_rounded,
                    size: 48,
                    color: _kPrimary.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              noJobsAtAll ? 'Chưa có đơn mới' : 'Không có đơn phù hợp',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noJobsAtAll
                  ? 'Đang theo dõi — đơn mới sẽ hiện ngay khi có khách'
                  : 'Thử chọn danh mục khác để xem thêm đơn',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(dynamic job, JobProvider provider) {
    final int jobId = job['id'] ?? 0;
    final bool isProcessing = _processingJobs.contains(jobId);
    final bool urgent = _isUrgent(job);
    final String device = _capitalize(job['deviceType']);
    final String symptom = _capitalize(job['symptom'] ?? job['aiSummary']);
    final String time = _relativeTime(job['createdAt']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JobDetailScreen(jobId: jobId.toString()),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Card Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    // Device icon circle
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: urgent
                            ? _kDanger.withOpacity(0.10)
                            : _kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _deviceIcon(job['deviceType']),
                        size: 22,
                        color: urgent ? _kDanger : _kPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Device name + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Urgency badge
                    if (urgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _kDanger.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kDanger.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '🔥 KHẨN CẤP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _kDanger,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Divider(height: 1, color: Colors.grey[150]),
              ),

              // ── Card Body ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Symptom description
                    Text(
                      symptom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF263238),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (job['address'] != null &&
                                    job['address'].toString().trim().isNotEmpty)
                                ? job['address'].toString()
                                : 'Vị trí chưa xác định',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.circle, size: 6, color: Colors.grey[300]),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          job['user']?['fullName'] ?? 'Khách hàng',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Card Actions ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    // Từ chối
                    OutlinedButton(
                      onPressed: isProcessing
                          ? null
                          : () => _handleDecline(job, provider),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Từ chối',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Nhận đơn
                    Expanded(
                    child: Container(
                      height: 40, 
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        
                        gradient: LinearGradient(
                          colors: isProcessing 
                              ? [Colors.grey[300]!, Colors.grey[300]!] 
                              : urgent
                                  ? [const Color(0xFFEF5350), _kDanger] 
                                  : [_kPrimary, const Color(0xFF0B1B4D)], 
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: isProcessing
                            ? null
                            : () => _handleAccept(job, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, 
                          shadowColor: Colors.transparent,     
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    urgent ? 'NHẬN NGAY' : 'Nhận đơn',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _handleAccept(dynamic job, JobProvider provider) async {
    final int jobId = job['id'] ?? 0;
    if (_processingJobs.contains(jobId)) return;
    HapticFeedback.mediumImpact();
    setState(() => _processingJobs.add(jobId));
    try {
      await provider.acceptJob(job, context);
    } finally {
      if (mounted) setState(() => _processingJobs.remove(jobId));
    }
  }

  void _handleDecline(dynamic job, JobProvider provider) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Bỏ qua đơn này?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Đơn sẽ được chuyển cho thợ khác. Bạn có thể xem lại các đơn đã bỏ qua trong lịch sử.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Không, giữ lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      provider.hideJob(job['id']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Bỏ qua',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
