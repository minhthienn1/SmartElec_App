import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import 'package:smart_elec/providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/chat_socket_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // --- BẢNG MÀU FUTURISTIC SCI-FI CAO CẤP (ĐÃ TINH CHỈNH ĐỘ TƯƠNG PHẢN) ---
  static const Color kPrimaryCyan = Color(0xFF0EA5E9);
  static const Color kSecondaryGreen = Color(0xFF22C55E);
  static const Color kDeepBlack = Color(0xFF040812);
  static const Color kInputBackground = Color(0xFF0F172A);
  static const Color kMutedGrey = Color(0xFF9CA3AF);
  static const Color kTextSecondary = Color(0xFFA0AEC0);
  static const Color kErrorRed = Color(0xFFEF4444);
  static const Color kGlowGreen = Color(0xFF10B981);
  static const Color kIdleBorder = Color(0xFF1E293B);

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _secureStorage = SecureStorageService();

  bool _isLoading = false;
  bool _isTechnicianLogin = false;
  bool _isObscure = true;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // --- LOGIC INPUT VALIDATION ---
  bool _validateInputs(String phone, String password) {
    // 📱 Check Phone Format (9-11 digits, must be numeric)
    if (phone.isEmpty) {
      _showSnackBar('Vui lòng nhập số điện thoại', kErrorRed);
      return false;
    }
    if (!RegExp(
      r'^\d{9,11}$',
    ).hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''))) {
      _showSnackBar('Số điện thoại phải từ 9-11 chữ số', kErrorRed);
      return false;
    }

    // 🔐 Check Password Length (minimum 6 characters)
    if (password.isEmpty) {
      _showSnackBar('Vui lòng nhập mật khẩu', kErrorRed);
      return false;
    }
    if (password.length < 6) {
      _showSnackBar('Mật khẩu phải tối thiểu 6 ký tự', kErrorRed);
      return false;
    }

    return true;
  }

  // --- LOGIC XỬ LÝ ĐỒNG BỘ NÂNG CAO ---
  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // 🔒 Validate Inputs (Phone + Password Format)
    final phone = _phoneController.text.trim();
    final password = _passController.text;
    if (!_validateInputs(phone, password)) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(phone, password);

      if (result['access_token'] != null) {
        String role = (result['role'] ?? 'USER').toString().toUpperCase();
        String token = result['access_token'];

        if (_isTechnicianLogin && role == 'USER') {
          throw Exception("Truy cập bị từ chối: Quyền Kỹ thuật viên yêu cầu.");
        }
        if (!_isTechnicianLogin && role == 'TECHNICIAN') {
          throw Exception("Vui lòng đăng nhập cổng Kỹ thuật viên.");
        }

        // Vượt qua kiểm tra -> Tiến hành lưu Token bằng hàm chuẩn mới
        await _secureStorage.saveAccessToken(token);

        // 🟢 Nạp Profile vào Provider ngay sau khi login
        if (mounted) {
          try {
            await Provider.of<UserProvider>(
              context,
              listen: false,
            ).fetchProfile();
            final user = Provider.of<UserProvider>(context, listen: false).user;
            if (user == null) {
              throw Exception(
                "Không thể tải hồ sơ người dùng. Vui lòng kiểm tra kết nối mạng.",
              );
            }
            // 🟢 Kết nối Socket ngay sau khi nạp profile thành công
            ChatSocketService().connect(null);
          } catch (e) {
            await _secureStorage
                .clearAll(); // Xóa dữ liệu lưu tạm nếu load profile thất bại
            rethrow;
          }
        }

        // Cập nhật hệ thống định danh Firebase Cloud Messaging (FCM)
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await ApiService.updateFcmToken(fcmToken, jwtToken: token);
          }
        } catch (e) {
          debugPrint("Lỗi cập nhật FCM sau login: $e");
        }

        if (!mounted) return;
        _showSnackBar("⚡ ĐÃ KẾT NỐI HỆ THỐNG", kPrimaryCyan);

        // 🔐 XÓA DỮ LIỆU NHẠY CẢM: Clear password controller ngay sau thành công
        _passController.clear();

        Future.delayed(const Duration(milliseconds: 800), () {
          if (role == 'ADMIN') {
            Navigator.pushReplacementNamed(context, '/admin_dashboard');
          } else if (role == 'TECHNICIAN') {
            Navigator.pushReplacementNamed(context, '/tech_main');
          } else {
            Navigator.pushReplacementNamed(context, '/main');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), kErrorRed);

        // ⏳ CHỐNG SPAM: Disable nút 3 giây trước khi cho phép click lại
        setState(() => _isLoading = false);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          debugPrint('✅ Nút Đăng nhập được mở khóa sau 3 giây');
        }
      }
      return;
    }
    // Đảm bảo set _isLoading = false cho trường hợp thành công
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color.withOpacity(0.95),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      body: Stack(
        children: [
          _buildBackgroundEffect(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              _buildOrbitLogo(),
                              const SizedBox(height: 28),
                              _buildBrandTitle(),
                              const SizedBox(height: 40),
                              _buildSegmentedToggle(),
                              const SizedBox(height: 36),
                              _buildRoundedInput(
                                controller: _phoneController,
                                label: "SỐ ĐIỆN THOẠI",
                                icon: Icons.phone_android_rounded,
                                hint: "0xxx xxx xxx",
                                validator: (v) =>
                                    (v == null || v.isEmpty || v.length < 10)
                                    ? "Số điện thoại không hợp lệ"
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              _buildRoundedInput(
                                controller: _passController,
                                label: "MẬT KHẨU",
                                icon: Icons.lock_outline_rounded,
                                hint: "Nhập mật khẩu",
                                isPass: true,
                                isObscure: _isObscure,
                                onSuffixPressed: () =>
                                    setState(() => _isObscure = !_isObscure),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? "Vui lòng nhập mật khẩu"
                                    : null,
                              ),
                              _buildForgotPassword(),

                              const SizedBox(height: 54),
                              _buildMainButton("ĐĂNG NHẬP"),

                              const Spacer(),

                              const SizedBox(height: 24),
                              _buildFooterRegister(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildBackgroundEffect() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.4),
          radius: 1.2,
          colors: [Color(0xFF0A1324), kDeepBlack],
        ),
      ),
    );
  }

  Widget _buildOrbitLogo() {
    final Animation<double> glowOpacity = Tween<double>(begin: 0.15, end: 0.45)
        .animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );
    final Animation<double> glowRadius = Tween<double>(begin: 20.0, end: 45.0)
        .animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kGlowGreen.withOpacity(glowOpacity.value),
                blurRadius: glowRadius.value,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset('assets/logo6.png', fit: BoxFit.cover),
        );
      },
    );
  }

  Widget _buildBrandTitle() {
    return Column(
      children: [
        Text(
          "SMARTELEC",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 6,
            shadows: [
              Shadow(color: kPrimaryCyan.withOpacity(0.3), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: kSecondaryGreen.withOpacity(0.02),
            border: Border.all(
              color: kSecondaryGreen.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            "AI DIAGNOSTIC SYSTEM",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: kSecondaryGreen,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF020611),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          _buildSegmentTab(false, "KHÁCH HÀNG"),
          _buildSegmentTab(true, "KỸ THUẬT VIÊN"),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(bool isTech, String label) {
    bool selected = _isTechnicianLogin == isTech;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isTechnicianLogin = isTech),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: selected
                ? const LinearGradient(
                    colors: [kSecondaryGreen, kPrimaryCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : kTextSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundedInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPass = false,
    bool isObscure = false,
    VoidCallback? onSuffixPressed,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: kMutedGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPass ? isObscure : false,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: kPrimaryCyan,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: kSecondaryGreen, size: 21),
            suffixIcon: isPass
                ? IconButton(
                    icon: Icon(
                      isObscure ? Icons.visibility_off : Icons.visibility,
                      color: kTextSecondary.withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: onSuffixPressed,
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
              borderSide: const BorderSide(color: kIdleBorder, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kPrimaryCyan, width: 1.5),
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
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 2),
        child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: kTextSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            "Quên mật khẩu?",
            style: TextStyle(
              fontSize: 13,
              color: kTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(String text) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kPrimaryCyan.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [kSecondaryGreen, kPrimaryCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
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
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterRegister() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/register'),
      behavior: HitTestBehavior.opaque,
      child: RichText(
        text: const TextSpan(
          text: "Chưa có tài khoản? ",
          style: TextStyle(color: kMutedGrey, fontSize: 14),
          children: [
            TextSpan(
              text: "Đăng ký ngay",
              style: TextStyle(
                color: kSecondaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
