import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_elec/services/api_service.dart'; // Đảm bảo đúng đường dẫn api_service của bạn
import 'package:smart_elec/models/user_model.dart'; // Đảm bảo đúng đường dẫn mô hình user của bạn

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _secureStorage = const FlutterSecureStorage();
  UserModel? _user;
  bool _isLoading = true;

  final Color _bgColor = const Color(0xff081125);
  final Color _cardColor = const Color(0xff111B3D);
  final Color _accentColor = const Color(0xff00E676);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // --- LOGIC API GIỮ NGUYÊN TỪ LOCAL ---
  Future<void> _fetchUserData() async {
    try {
      final data = await ApiService.getProfile();
      setState(() {
        _user = UserModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Lỗi load profile: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> updateData) async {
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
        const SnackBar(
          content: Text("Lỗi cập nhật dữ liệu"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- DIALOG CHỈNH SỬA PROFILE CỦA BẠN ---
  void _showEditDialog() {
    final nameController = TextEditingController(text: _user?.fullName);
    final emailController = TextEditingController(text: _user?.email);
    final addressController = TextEditingController(text: _user?.address);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Chỉnh sửa thông tin",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 25),
            _buildTextField(nameController, "Họ và tên", Icons.person_outline),
            const SizedBox(height: 15),
            _buildTextField(emailController, "Email", Icons.email_outlined),
            const SizedBox(height: 15),
            _buildTextField(
              addressController,
              "Địa chỉ",
              Icons.location_on_outlined,
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [Color(0xff00E676), Color(0xff00B0FF)],
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xff00B0FF)),
        filled: true,
        fillColor: _cardColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff00B0FF)),
        ),
      ),
    );
  }

  // --- LOGIC ĐĂNG XUẤT AN TOÀN TỪ GITHUB ---
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text("Đăng xuất", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bạn có chắc chắn muốn đăng xuất tài khoản?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Đăng xuất",
              style: TextStyle(color: Colors.redAccent),
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
              Center(child: CircularProgressIndicator(color: _accentColor)),
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
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgColor,
        centerTitle: false,
        title: const Text(
          "Hồ sơ cá nhân",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: IconButton(
              icon: Icon(Icons.edit_square, color: _accentColor, size: 22),
              onPressed: _showEditDialog,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
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
                          Icons.history_edu_rounded,
                          "Lịch sử sửa chữa",
                          const Color(0xff00B0FF),
                        ),
                        const SizedBox(height: 12),
                        _buildMenuTile(
                          Icons.lock_reset_rounded,
                          "Đổi mật khẩu",
                          Colors.orangeAccent,
                        ),
                        const SizedBox(height: 35),
                        _buildLogoutButton(context),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
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
              border: Border.all(color: _accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: _cardColor,
              backgroundImage: _user?.avatarUrl != null
                  ? NetworkImage(_user!.avatarUrl!)
                  : null,
              child: _user?.avatarUrl == null
                  ? const Icon(Icons.person, size: 45, color: Colors.white54)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _user?.fullName ?? "Người dùng",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xff00B0FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xff00B0FF).withOpacity(0.3),
              ),
            ),
            child: Text(
              _user?.role ?? "USER",
              style: const TextStyle(
                color: Color(0xff00B0FF),
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.phone_android,
            "Số điện thoại",
            _user?.phoneNumber ?? "",
          ),
          Divider(height: 30, color: Colors.white.withOpacity(0.05)),
          _buildDetailRow(
            Icons.email_outlined,
            "Email",
            _user?.email ?? "Chưa cập nhật",
          ),
          Divider(height: 30, color: Colors.white.withOpacity(0.05)),
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
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xff00B0FF), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xff8E9AA6), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white30,
          size: 16,
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.05),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => _handleLogout(context),
        child: const Text(
          "Đăng xuất",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
