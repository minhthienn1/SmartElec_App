import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/job_provider.dart';
import '../models/chat_session.dart';
import '../Widgets/custom_loading_button.dart';
import 'tech_color.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isLoading = true;
  bool _isAccepting = false;
  String? _errorMessage;
  ChatSession? _session;

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  Future<void> _loadJobDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final id = int.parse(widget.jobId);
      final session = await ApiService.getSessionById(id);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải chi tiết đơn: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptJob() async {
    final session = _session;
    if (session == null || _isAccepting) return;

    setState(() => _isAccepting = true);
    HapticFeedback.mediumImpact();

    try {
      final jobMap = {
        'id': session.id,
        'sessionId': session.id,
        'version': 1, // Mặc định khóa lạc quan
        'deviceType': session.deviceType,
        'symptom': session.symptom,
        'user': {
          'id': session.customer?.id ?? 0,
          'fullName': session.customer?.fullName ?? 'Khách hàng',
          'avatarUrl': session.customer?.avatarUrl,
        }
      };

      await context.read<JobProvider>().acceptJob(jobMap, context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Không thể nhận đơn: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: TechColors.background,
    appBar: AppBar(
      title: const Text(
        'Chi tiết đơn sửa chữa',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
      backgroundColor: TechColors.navy,
      foregroundColor: Colors.white,
    ),
    body: _buildBody(TechColors.navy), // Cập nhật biến truyền vào
  );
  }

  Widget _buildBody(Color themeColor) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xff0B1B4D)),
            SizedBox(height: 16),
            Text('Đang tải thông tin chi tiết...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Lỗi: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadJobDetails,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return const Center(child: Text('Không tìm thấy dữ liệu đơn hàng.'));
    }

    final isBroadcasting = session.status == 'BROADCASTING';
    final formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(session.createdAt);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Banner nguy hiểm (Nếu AI phân tích có nguy hiểm)
          if (session.isDangerous) _buildDangerBanner(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thẻ thông tin chính (Thiết bị)
                _buildMainDeviceCard(session),
                const SizedBox(height: 16),

                // Thẻ tóm tắt chẩn đoán AI
                _buildAiDiagnosisCard(session),
                const SizedBox(height: 16),

                // Thẻ liên hệ khách hàng
                _buildCustomerCard(session),
                const SizedBox(height: 16),

                // Thẻ thời gian và trạng thái
                _buildStatusTimeCard(session, formattedDate),
                const SizedBox(height: 32),

                // Nút hành động
                if (isBroadcasting)
                  CustomLoadingButton(
                    text: 'NHẬN ĐƠN NGAY',
                    isLoading: _isAccepting,
                    onPressed: _acceptJob,
                    height: 55,
                    borderRadius: 12,
                    gradientColors: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'ĐƠN NÀY ĐÃ ĐƯỢC NHẬN HOẶC ĐÃ HỦY',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '⚠️ AI CẢNH BÁO NGUY HIỂM: Thiết bị có khả năng bị rò rỉ điện hoặc có nguy cơ cháy nổ cao. Hãy mang đồ bảo hộ!',
              style: TextStyle(
                color: Colors.red[900],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDeviceCard(ChatSession session) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xff0B1B4D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.electrical_services_rounded,
                size: 28,
                color: Color(0xff0B1B4D),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.deviceType ?? 'Thiết bị chưa rõ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0B1B4D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'SmartElec Repair Ticket',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiDiagnosisCard(ChatSession session) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: TechColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tóm tắt lỗi từ AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              session.symptom ?? 'Không có mô tả triệu chứng lỗi.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            if (session.aiSummary != null && session.aiSummary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TechColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TechColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  session.aiSummary!,
                  style: TextStyle(
                    fontSize: 13,
                    color: TechColors.navy,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(ChatSession session) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Thông tin khách hàng & Vị trí',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.person_outline_rounded,
              'Tên liên hệ',
              session.contactName ?? session.customer?.fullName ?? 'Khách hàng',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.phone_iphone_rounded,
              'Số điện thoại',
              session.contactPhone ?? session.customer?.phoneNumber ?? 'Chưa cung cấp',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.location_on_rounded,
              'Địa chỉ sửa chữa',
              session.address ?? 'Đang xác định vị trí...',
              isAddress: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeCard(ChatSession session, String dateStr) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trạng thái đơn', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.status == 'BROADCASTING' ? Colors.green[50] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    session.status == 'BROADCASTING' ? '📡 Đang tìm thợ' : 'Đã được xử lý',
                    style: TextStyle(
                      color: session.status == 'BROADCASTING' ? Colors.green[800] : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Thời gian tạo', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, {bool isAddress = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
