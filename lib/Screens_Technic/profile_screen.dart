import 'package:flutter/material.dart';
import 'tech_color.dart';
import 'tech_my_jobs_screen.dart'; 
import 'tech_reviews_screen.dart'; 
import '../services/technician_service.dart';
import '../services/secure_storage_service.dart';
import '../Screens/login_screen.dart';

class TechProfileScreen extends StatefulWidget {
  const TechProfileScreen({super.key});

  @override
  State<TechProfileScreen> createState() => _TechProfileScreenState();
}

class _TechProfileScreenState extends State<TechProfileScreen> {
  final TechnicianService _service = TechnicianService();
  final SecureStorageService _secureStorage = SecureStorageService();
  
  bool isLoading = true;
  bool isEditing = false;   // Trạng thái bật/tắt chế độ sửa
  bool isSaving = false;    // Trạng thái đợi khi bấm lưu lên server
  
  Map<String, dynamic>? profileData;

  // Khai báo các Controller để điều khiển việc nhập liệu
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoading = true);
    try {
      final data = await _service.getProfile();
      setState(() {
        profileData = data;
        // Đổ dữ liệu cũ từ Database vào ô nhập liệu
        _nameController.text = data['fullName'] ?? "";
        _phoneController.text = data['phoneNumber'] ?? "";
        _emailController.text = data['email'] ?? "";
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // Hàm xử lý khi nhấn nút Xác nhận Lưu (Dấu tick)
  Future<void> _saveProfile() async {
    // 1. Thêm kiểm tra _nameController để không bị lưu tên rỗng
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng không để trống thông tin"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await _service.updateProfile(
        _nameController.text.trim(), 
        _phoneController.text.trim(), 
        _emailController.text.trim()
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cập nhật thông tin thành công!"), backgroundColor: Colors.green)
      );
      
      setState(() {
        // Cập nhật trực tiếp vào biến map chứa dữ liệu gốc của màn hình
        if (profileData != null) {
          profileData!['fullName'] = _nameController.text.trim();
          profileData!['phoneNumber'] = _phoneController.text.trim(); 
          profileData!['email'] = _emailController.text.trim();
        }

        isEditing = false;
        isSaving = false;
      });

      // 3. (Tùy chọn) Thêm chữ await để đợi load xong ngầm, 
      // nhưng UI thì đã được cập nhật ở bước 2 rồi nên không sợ bị giật cục
      await _loadProfile(); 
      
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.red)
      );
    }
  }
  void _showChangePasswordDialog() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Đổi mật khẩu", style: TextStyle(color: TechColors.primary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPwController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Mật khẩu hiện tại"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPwController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Mật khẩu mới"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: TechColors.primary),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (oldPwController.text.isEmpty || newPwController.text.isEmpty) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _service.changePassword(oldPwController.text, newPwController.text);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Đổi mật khẩu thành công!"), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Xác nhận"),
              ),
            ],
          );
        }
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Xác nhận đăng xuất", style: TextStyle(color: TechColors.primary, fontWeight: FontWeight.bold)),
          content: const Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context); 
                final secureStorage = SecureStorageService();
                await secureStorage.deleteAccessToken();
                
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text("Đăng xuất", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: TechColors.primary)));
    if (profileData == null) return const Scaffold(backgroundColor: Colors.white, body: Center(child: Text("Lỗi tải dữ liệu")));

    final fullName = profileData!['fullName'] ?? "Chưa cập nhật tên";
    final phone = profileData!['phoneNumber'] ?? "Chưa cập nhật";
    final email = profileData!['email'] ?? "Chưa cập nhật";
    final completedCount = profileData!['completedJobsCount'] ?? 0;
    
    final double avgRating = (profileData!['averageRating'] != null) 
        ? double.tryParse(profileData!['averageRating'].toString()) ?? 0.0 
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân", style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // NÚT CHUYỂN ĐỔI: BÚT CHÌ <-> DẤU TICK XÁC NHẬN
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: isEditing ? Colors.green.withOpacity(0.1) : TechColors.primary.withOpacity(0.1),
              radius: 20,
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                  : IconButton(
                      icon: Icon(
                        isEditing ? Icons.check : Icons.edit, // Đổi icon linh hoạt
                        color: isEditing ? Colors.green : TechColors.primary, 
                        size: 20
                      ),
                      onPressed: () {
                        if (isEditing) {
                          _saveProfile(); // Đang bật chế độ sửa mà ấn vào thì tiến hành Lưu
                        } else {
                          setState(() => isEditing = true); // Đang tắt chế độ sửa mà ấn vào thì Bật lên
                        }
                      },
                    ),
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: TechColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Ảnh đại diện & Tên
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TechColors.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        fullName.substring(0, 1).toUpperCase(), 
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.grey)
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: TechColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              isEditing
                  ? SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Nhập họ tên",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TechColors.primary.withOpacity(0.5))),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: TechColors.primary, width: 2)),
                        ),
                      ),
                    )
                  : Text(
                      fullName, 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)
                    ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: TechColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TechColors.primary.withOpacity(0.3)),
                ),
                child: const Text("TECHNICIAN", style: TextStyle(color: TechColors.primary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              ),
              const SizedBox(height: 24),

              // 2. Thẻ Thông tin liên hệ (Có khả năng Inline Edit)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.phone_android, "Số điện thoại", phone, controller: _phoneController),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 1)),
                    _buildInfoRow(Icons.email_outlined, "Email", email, controller: _emailController),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Các thẻ chức năng rời rạc
              _buildActionCard(
                Icons.task_alt, 
                "Đơn hoàn thành", 
                trailingText: "$completedCount đơn",
                onTap: isEditing ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TechMyJobsScreen())) // Khóa bấm khi đang edit
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                Icons.star_outline, 
                "Đánh giá", 
                trailingText: avgRating > 0 ? "$avgRating⭐" : "Chưa có", 
                onTap: isEditing ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TechReviewsScreen()))
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                Icons.lock_outline, 
                "Đổi mật khẩu", 
                onTap: isEditing ? null : _showChangePasswordDialog
              ),
              const SizedBox(height: 32),

              // 4. Nút Đăng xuất
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isEditing ? null : _handleLogout,
                  child: const Text("Đăng xuất", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- HÀM HỖ TRỢ VẼ DÒNG THÔNG TIN (XỬ LÝ ĐỔI TRẠNG THÁI HIỂN THỊ THÀNH TEXTFIELD) ---
  Widget _buildInfoRow(IconData icon, String label, String value, {required TextEditingController controller}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: TechColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: TechColors.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              // Nếu đang ở trạng thái Edit thì đổi sang TextField, ngược lại giữ nguyên Text thông thường
              isEditing 
                ? TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TechColors.primary.withOpacity(0.5))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: TechColors.primary, width: 1.5)),
                    ),
                  )
                : Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, {String? trailingText, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0, // Làm mờ nhẹ khi các thẻ bị khóa lúc đang edit
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: TechColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: TechColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87))),
              if (trailingText != null) 
                Text(trailingText, style: TextStyle(color: TechColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              if (trailingText != null) const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}