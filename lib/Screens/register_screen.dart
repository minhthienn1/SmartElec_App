import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- ĐỒNG BỘ BẢNG MÀU SCI-FI CHUẨN HỆ THỐNG ---
  static const Color kPrimaryOrange = Color(0xFFFF7A00); // Màu cam chủ đạo
  static const Color kBackground = Colors.white; // Nền trắng
  static const Color kInputBackground = Colors.white;
  static const Color kTextPrimary = Color(0xFF1F2937); // Đen xám cho chữ chính
  static const Color kTextSecondary = Color(0xFF6B7280); // Xám cho chữ phụ
  static const Color kMutedGrey = Color(0xFF9CA3AF);
  static const Color kErrorRed = Color(0xFFEF4444);
  static const Color kIdleBorder = Color(0xFFD1D5DB); // Xám nhạt cho viền ô nhập

  // GIỮ NGUYÊN HOÀN TOÀN LOGIC BIẾN VÀ VALIDATE
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _addressController = TextEditingController();
  final _avatarController = TextEditingController();

  String _selectedGender = "Nam";
  bool _isLoading = false;
  bool _isObscure = true;

  final _nameRegExp = RegExp(r"^[a-zA-ZÀ-ỹ\s]{1,30}$");
  final _phoneRegExp = RegExp(r"^0[0-9]{9}$");

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _addressController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  // LOGIC XỬ LÝ ĐĂNG KÝ (GIỮ NGUYÊN 100%)
  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final result = await ApiService.register({
          "fullName": _fullNameController.text.trim(),
          "email": _emailController.text.trim(),
          "phoneNumber": _phoneController.text.trim(),
          "password": _passController.text,
          "gender": _selectedGender == "Nam"
              ? "MALE"
              : (_selectedGender == "Nữ" ? "FEMALE" : "OTHER"),
          "address": _addressController.text.isEmpty
              ? null
              : _addressController.text,
          "avatarUrl": _avatarController.text.isEmpty
              ? null
              : _avatarController.text,
        });

        if (result['userId'] != null || result['id'] != null) {
          if (!mounted) return;
          _showSnackBar("Đăng ký thành công!, hãy đăng nhập", kPrimaryOrange);
          Navigator.pop(context);
        }
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), kErrorRed);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        backgroundColor: color.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground, // Đổi sang nền trắng
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: kTextPrimary, // Nút back màu đen xám
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 24),

                /// HEADER CHUẨN LIGHT MODE
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Tham gia\nSmartElec",
                      style: TextStyle(
                        color: kTextPrimary, // Chữ tiêu đề màu đen
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: kPrimaryOrange, // Tia sét màu cam
                        size: 38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Giải pháp AI tối ưu thiết bị điện",
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 40),

                _buildSectionLabel("THÔNG TIN CƠ BẢN"),
                _buildField(
                  _fullNameController,
                  "Họ và tên",
                  Icons.person_rounded,
                  (v) => (v == null || !_nameRegExp.hasMatch(v))
                      ? "Tên không hợp lệ"
                      : null,
                ),

                _buildField(
                  _emailController,
                  "Email",
                  Icons.alternate_email_rounded,
                  (v) => (v == null || !v.contains("@"))
                      ? "Email không hợp lệ"
                      : null,
                  keyboard: TextInputType.emailAddress,
                ),

                _buildField(
                  _phoneController,
                  "Số điện thoại",
                  Icons.phone_android_rounded,
                  (v) => (v == null || !_phoneRegExp.hasMatch(v))
                      ? "SĐT phải 10 số, bắt đầu bằng 0"
                      : null,
                  keyboard: TextInputType.phone,
                ),

                const SizedBox(height: 8),
                _buildGenderSelector(),

                const SizedBox(height: 32),
                _buildSectionLabel("BẢO MẬT & ĐỊA CHỈ"),
                _buildField(
                  _passController,
                  "Mật khẩu",
                  Icons.lock_outline_rounded,
                  (v) => v!.length < 6 ? "Tối thiểu 6 ký tự" : null,
                  isPass: true,
                ),
                _buildField(
                  _confirmPassController,
                  "Xác nhận mật khẩu",
                  Icons.shield_outlined,
                  (v) => v != _passController.text
                      ? "Mật khẩu không khớp"
                      : null,
                  isPass: true,
                ),

                _buildField(
                  _addressController,
                  "Địa chỉ",
                  Icons.location_on_outlined,
                  null,
                ),

                const SizedBox(height: 40),

                _buildMainButton("ĐĂNG KÝ TÀI KHOẢN"),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: kMutedGrey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    String? Function(String?)? validator, {
    bool isPass = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPass ? _isObscure : false,
        keyboardType: keyboard,
        validator: validator,
        style: const TextStyle(color: kTextPrimary, fontSize: 15), // Chữ gõ vào màu đen
        cursorColor: kPrimaryOrange, // Con trỏ màu cam
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: kTextSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: kPrimaryOrange, size: 21), // Icon màu cam
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                    color: kTextSecondary.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                )
              : null,
          filled: true,
          fillColor: kInputBackground,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kIdleBorder, width: 1.2), // Viền xám nhạt
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimaryOrange, width: 1.5), // Focus viền cam
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kErrorRed, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kErrorRed, width: 1.5),
          ),
          errorStyle: const TextStyle(
            color: kErrorRed,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kIdleBorder), // Viền xám
      ),
      child: Row(
        children: ["Nam", "Nữ", "Khác"].map((g) {
          bool isSelected = _selectedGender == g;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedGender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected ? kPrimaryOrange : Colors.transparent, // Nền cam nếu chọn
                ),
                child: Text(
                  g,
                  style: TextStyle(
                    color: isSelected ? Colors.white : kTextSecondary, // Chữ trắng nếu chọn, xám nếu chưa
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainButton(String text) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryOrange, // Nút cam nguyên khối giống hệt Đăng nhập
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }

}
