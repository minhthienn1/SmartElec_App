import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_elec/services/api_service.dart'; 
import 'package:smart_elec/models/user_model.dart'; 
import 'repair_history_screen.dart';
import 'booked_orders_screen.dart';

// --- BẢNG MÀU ĐÃ CUNG CẤP ---
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _secureStorage = const FlutterSecureStorage();
  UserModel? _user;
  bool _isLoading = true;

  // Sử dụng màu nền mới
  final Color _bgColor = AppColors.kBackground; 
  // Thẻ thông tin nền sáng
  final Color _cardColor = AppColors.kInputBackground; 
  // Màu cam chủ đạo
  final Color _accentColor = AppColors.kPrimaryOrange; 

  // Tạo FocusNode để quản lý trạng thái focus của textField
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  
    // Lắng nghe sự thay đổi focus để cập nhật màu icon (đẹp hơn)
    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _addressFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Giải phóng FocusNode
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  // --- LOGIC API GIỮ NGUYÊN ---
  Future<void> _fetchUserData() async {
    try {
      final data = await ApiService.getProfile();
      if (!mounted) return;
      setState(() {
        _user = UserModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Lỗi load profile: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> updateData) async {
    // Không thay đổi logic, chỉ cập nhật SnackBar colors
    setState(() => _isLoading = true);
    try {
      await ApiService.updateProfile(updateData);
      await _fetchUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cập nhật thành công!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lỗi cập nhật dữ liệu"),
          backgroundColor: AppColors.kErrorRed, // Sử dụng màu lỗi của bảng màu
        ),
      );
    }
  }

  // --- DIALOG CHỈNH SỬA PROFILE - CẬP NHẬT GIAO DIỆN ---
  void _showEditDialog() {
    final nameController = TextEditingController(text: _user?.fullName);
    final emailController = TextEditingController(text: _user?.email);
    final addressController = TextEditingController(text: _user?.address);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder( // Thêm StatefulBuilder để update focus
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.kBackground, // Màu nền trắng mới
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              // Viền mỏng cho tinh tế
              border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.3)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 15,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dấu kéo thanh lịch hơn
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.kMutedGrey, 
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Chỉnh sửa thông tin",
                  style: TextStyle(
                    fontSize: 20, // Tăng nhẹ kích thước
                    fontWeight: FontWeight.bold,
                    color: AppColors.kTextPrimary, // Màu văn bản chính mới
                  ),
                ),
                const SizedBox(height: 25),
                _buildTextField(nameController, "Họ và tên", Icons.person_outline, _nameFocusNode),
                const SizedBox(height: 15),
                _buildTextField(emailController, "Email", Icons.email_outlined, _emailFocusNode),
                const SizedBox(height: 15),
                _buildTextField(
                  addressController,
                  "Địa chỉ",
                  Icons.location_on_outlined,
                  _addressFocusNode,
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    // Gradient cam đẹp mắt
                    gradient: const LinearGradient(
                      colors: [AppColors.kPrimaryOrange, AppColors.kDarkOrange],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      _updateProfile({
                        "fullName": nameController.text,
                        "email": emailController.text,
                        "address": addressController.text,
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Lưu thay đổi",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Cập nhật hàm trợ giúp TextField với FocusNode và màu sắc
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    FocusNode focusNode,
  ) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: AppColors.kTextPrimary), // Màu văn bản mới
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.kTextSecondary), // Màu label mới
        // Icon đổi màu dựa trên focus
        prefixIcon: Icon(icon, color: focusNode.hasFocus ? AppColors.kPrimaryOrange : AppColors.kMutedGrey), 
        filled: true,
        fillColor: AppColors.kInputBackground, // Màu nền trường nhập liệu mới
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.kIdleBorder.withOpacity(0.5)), // Viền nhẹ
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.kPrimaryOrange), // Viền cam khi focus
        ),
      ),
    );
  }

  // --- LOGIC ĐĂNG XUẤT AN TOÀN GIỮ NGUYÊN, CẬP NHẬT MÀU DIALOG ---
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.kBackground, // Màu nền sáng mới
        title: const Text("Đăng xuất", style: TextStyle(color: AppColors.kTextPrimary)), 
        content: const Text(
          "Bạn có chắc chắn muốn đăng xuất tài khoản?",
          style: TextStyle(color: AppColors.kTextSecondary), // Màu văn bản mới
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: AppColors.kMutedGrey)), // Màu grey mới
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Đăng xuất",
              style: TextStyle(color: AppColors.kErrorRed), // Màu đỏ lỗi mới
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Hiển thị loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) =>
              Center(child: CircularProgressIndicator(color: AppColors.kPrimaryOrange)), // Màu Loading cam mới
        );
      }

      // 🔐 LOGOUT HOÀN CHỈNH: Gọi UserProvider.logout() để dọn dẹp toàn hệ thống
      if (context.mounted) {
        await Provider.of<UserProvider>(context, listen: false).logout();
      }

      // Đóng loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // ✅ ĐIỀU HƯỚNG AN TOÀN: Xóa toàn bộ stack navigator để tránh quay lại
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }

      debugPrint('✅ [ProfileScreen] Đăng xuất thành công!');
    } catch (e) {
      debugPrint('❌ [ProfileScreen] Lỗi đăng xuất: $e');

      // Đóng loading dialog nếu còn mở
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Hiển thị thông báo lỗi
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lỗi đăng xuất. Vui lòng thử lại!'),
            backgroundColor: AppColors.kErrorRed, 
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground, // Nền sáng mới
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kBackground, // Nền AppBar sáng liền mạch
        centerTitle: false,
        title: const Text(
          "Hồ sơ cá nhân",
          style: TextStyle(
            color: AppColors.kTextPrimary, // Màu văn bản chính mới
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.kInputBackground, 
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.3)), // Viền nhẹ
            ),
            child: IconButton(
              icon: const Icon(Icons.edit_square, color: AppColors.kPrimaryOrange, size: 22), // Icon cam mới
              onPressed: _showEditDialog,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.kPrimaryOrange)) 
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 20),
                        _buildMenuTile(
                          Icons.chat_bubble_outline,
                          "Lịch sử chat với thợ",
                          AppColors.kMutedGrey, 
                          () { 
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RepairHistoryScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        _buildMenuTile(
                          Icons.assignment_outlined, 
                          "Đơn đã đặt",
                          AppColors.kPrimaryOrange, 
                          () { 
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BookedOrdersScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12), 

                        _buildMenuTile(
                          Icons.lock_reset_rounded,
                          "Đổi mật khẩu",
                          AppColors.kPrimaryOrange, 
                          () { 
                            debugPrint("Bấm đổi mật khẩu");
                          },
                        ),
                        const SizedBox(height: 35),
                        _buildLogoutButton(context),
                        const SizedBox(height: 60), 
                      ],
                    ),
                  ),

                  
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.developer_mode, color: AppColors.kMutedGrey, size: 14),
                        const SizedBox(width: 4),
                        const Text("SmartElec v1.0", style: TextStyle(color: AppColors.kMutedGrey, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Viền cam mới cho Avatar
              border: Border.all(color: AppColors.kPrimaryOrange, width: 2),
              boxShadow: [
                BoxShadow(
                  // Bóng cam nhạt
                  color: AppColors.kPrimaryOrange.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Colors.white, // Nền Avatar trắng trên nền sáng
              backgroundImage: _user?.avatarUrl != null
                  ? NetworkImage(_user!.avatarUrl!)
                  : null,
              child: _user?.avatarUrl == null
                  ? const Icon(Icons.person, size: 45, color: AppColors.kMutedGrey) // Icon màu Grey mới
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _user?.fullName ?? "Người dùng",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.kTextPrimary, // Màu văn bản chính mới
            ),
          ),
          const SizedBox(height: 8),
          // Cập nhật tag Role "USER" thành màu Cam nhạt
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.kLightOrange, // Nền cam nhạt
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.kPrimaryOrange.withOpacity(0.3), // Viền cam nhẹ
              ),
            ),
            child: const Text(
              "USER", // Thay đổi cứng Role để test, hoặc dùng _user?.role
              style: TextStyle(
                color: AppColors.kPrimaryOrange, // Văn bản màu cam mới
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CẬP NHẬT GIAO DIỆN THẺ THÔNG TIN ---
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kInputBackground, // Thẻ trắng trên nền xám nhạt
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.3)), // Viền nhẹ
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.phone_android,
            "Số điện thoại",
            _user?.phoneNumber ?? "Chưa cập nhật",
          ),
          Divider(height: 30, color: AppColors.kIdleBorder.withOpacity(0.3)), // Phân cách mới
          _buildDetailRow(
            Icons.email_outlined,
            "Email",
            _user?.email ?? "Chưa cập nhật",
          ),
          Divider(height: 30, color: AppColors.kIdleBorder.withOpacity(0.3)), // Phân cách mới
          _buildDetailRow(
            Icons.location_on_outlined,
            "Địa chỉ",
            _user?.address ?? "Chưa cập nhật",
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.kLightOrange, // Nền icon cam nhạt mới
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.kPrimaryOrange, size: 20), // Icon cam mới
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.kTextSecondary, fontSize: 12), // Màu văn bản thứ cấp mới
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.kTextPrimary, // Màu văn bản chính mới
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- CẬP NHẬT GIAO DIỆN CÁC DÒNG MENU ---
  Widget _buildMenuTile(IconData icon, String title, Color iconColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kInputBackground, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.kIdleBorder.withOpacity(0.3)), // Viền nhẹ
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.kLightOrange, // Nền icon cam nhạt đồng bộ
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor), // Giữ màu icon để phân biệt
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.kTextPrimary, // Màu văn bản chính mới
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.kMutedGrey, // Icon màu Grey mới
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  // --- CẬP NHẬT NÚT ĐĂNG XUẤT ---
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.kErrorRed.withOpacity(0.05), // Nền đỏ lỗi nhạt mới
          side: BorderSide(color: AppColors.kErrorRed.withOpacity(0.3)), // Viền đỏ nhẹ mới
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => _handleLogout(context),
        child: const Text(
          "Đăng xuất",
          style: TextStyle(
            color: AppColors.kErrorRed, // Văn bản màu đỏ lỗi mới
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}