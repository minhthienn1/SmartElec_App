import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import 'package:smart_elec/providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/chat_socket_service.dart';
import '../services/zalo_auth_service.dart';
import '../services/google_auth_service.dart';



const Color kPrimaryOrange = Color(0xFFFF6600); 
const Color kBackground = Color(0xFFFFFFFF);   
const Color kSurface = Color(0xFFF3F4F6);       
const Color kTextMain = Color(0xFF1F2937); 
const Color kTextMuted = Color(0xFF9CA3AF);    
const Color kBorder = Color(0xFFE5E7EB);        
const Color kErrorRed = Color(0xFFEF4444);      

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

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

        await _secureStorage.saveAccessToken(token);

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
            ChatSocketService().connect(null);
          } catch (e) {
            await _secureStorage
                .clearAll();
            rethrow;
          }
        }

        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await ApiService.updateFcmToken(fcmToken, jwtToken: token);
          }
        } catch (e) {
          debugPrint("Lỗi cập nhật FCM sau login: $e");
        }

        if (!mounted) return;
        _showSnackBar("⚡ ĐÃ KẾT NỐI HỆ THỐNG", kPrimaryOrange);

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

        setState(() => _isLoading = false);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          debugPrint('✅ Nút Đăng nhập được mở khóa sau 3 giây');
        }
      }
      return;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleZaloLogin() async {
    setState(() => _isLoading = true);
    try {
      final result = await ZaloAuthService.loginWithZalo();
      
      if (result['access_token'] != null) {
        String token = result['access_token'];
        await _secureStorage.saveAccessToken(token);
        
        if (mounted) {
          try {
            await Provider.of<UserProvider>(context, listen: false).fetchProfile();
            ChatSocketService().connect(null);
          } catch (e) {
            await _secureStorage.clearAll();
            rethrow;
          }
        }
        
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await ApiService.updateFcmToken(fcmToken, jwtToken: token);
          }
        } catch (e) {
          debugPrint("Lỗi cập nhật FCM sau Zalo login: $e");
        }

        if (!mounted) return;
        _showSnackBar(result['message'] ?? "⚡ ĐÃ KẾT NỐI HỆ THỐNG", kPrimaryOrange);
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (result['needsPassword'] == true) {
             Navigator.pushReplacementNamed(context, '/set_password');
          } else {
             Navigator.pushReplacementNamed(context, '/main');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), kErrorRed);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final result = await GoogleAuthService.loginWithGoogle();
      
      if (result['access_token'] != null) {
        String token = result['access_token'];
        await _secureStorage.saveAccessToken(token);
        
        if (mounted) {
          try {
            await Provider.of<UserProvider>(context, listen: false).fetchProfile();
            ChatSocketService().connect(null);
          } catch (e) {
            await _secureStorage.clearAll();
            rethrow;
          }
        }
        
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await ApiService.updateFcmToken(fcmToken, jwtToken: token);
          }
        } catch (e) {
          debugPrint("Lỗi cập nhật FCM sau Google login: $e");
        }

        if (!mounted) return;
        _showSnackBar(result['message'] ?? "⚡ ĐÃ KẾT NỐI HỆ THỐNG", kPrimaryOrange);
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (result['needsPassword'] == true) {
             Navigator.pushReplacementNamed(context, '/set_password');
          } else {
             Navigator.pushReplacementNamed(context, '/main');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), kErrorRed);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      backgroundColor: kBackground,
      body: SafeArea(
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
                        mainAxisAlignment: MainAxisAlignment.center, // Căn giữa trục dọc để tránh bị dồn ngộp
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          
                          // 1. THAY THẾ LOGO BẰNG TYPOGRAPHY CHUYÊN NGHIỆP
                          _buildTypographicBrand(),
                          
                          const SizedBox(height: 40), 
                          
                          _buildSegmentedToggle(),
                          const SizedBox(height: 24), 
                          
                          _buildRoundedInput(
                            controller: _phoneController,
                            label: "SỐ ĐIỆN THOẠI",
                            icon: Icons.phone_android_rounded,
                            hint: "Nhập số điện thoại...", 
                            validator: (v) =>
                                (v == null || v.isEmpty || v.length < 9)
                                ? "Số điện thoại không hợp lệ"
                                : null,
                          ),
                          const SizedBox(height: 16), 
                          _buildRoundedInput(
                            controller: _passController,
                            label: "MẬT KHẨU",
                            icon: Icons.lock_outline_rounded,
                            hint: "Nhập mật khẩu...",
                            isPass: true,
                            isObscure: _isObscure,
                            onSuffixPressed: () =>
                                setState(() => _isObscure = !_isObscure),
                            validator: (v) => (v == null || v.isEmpty)
                                ? "Vui lòng nhập mật khẩu"
                                : null,
                          ),
                          _buildForgotPassword(),

                          const SizedBox(height: 24), // Thu hẹp khoảng cách hợp lý
                          _buildMainButton("ĐĂNG NHẬP"),

                          const SizedBox(height: 32),
                          _buildSocialLogins(),

                          const SizedBox(height: 48), // Gom phần đăng ký lại gần hơn
                          _buildFooterRegister(),
                          const SizedBox(height: 20), 
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
    );
  }

  // --- UI COMPONENTS (Đã tinh chỉnh thanh thoát hơn) ---

  Widget _buildTypographicBrand() {
    return Column(
      children: [
        const SizedBox(height: 20), // Đẩy chữ xuống một chút để cân bằng
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: "SMART",
                style: TextStyle(
                  fontSize: 44, // Tăng kích thước chữ lên mức to bản
                  fontWeight: FontWeight.w900,
                  color: kTextMain,
                  letterSpacing: 2.5,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: "ELEC\n",
                style: TextStyle(
                  fontSize: 44, 
                  fontWeight: FontWeight.w900,
                  color: kPrimaryOrange,
                  letterSpacing: 2.5,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: "Tư vấn & Hỗ trợ kỹ thuật điện thông minh",
                style: TextStyle(
                  fontSize: 16, // To hơn một chút để dễ đọc
                  color: kTextMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                  height: 2.5, // Tăng khoảng cách dòng để chiếm không gian thanh thoát hơn
                ),
              ),
            ],
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
        color: kPrimaryOrange.withOpacity(0.08), // Nền cam rất nhạt
        borderRadius: BorderRadius.circular(30), // Bo tròn hoàn toàn hai đầu
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
            borderRadius: BorderRadius.circular(26), // Bo cong khớp với viền ngoài
            color: selected ? kPrimaryOrange : Colors.transparent, // Nền cam khi được chọn
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kPrimaryOrange.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : kPrimaryOrange.withOpacity(0.7), // Chữ trắng khi chọn, cam nhạt khi không
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
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
    return TextFormField(
      controller: controller,
      obscureText: isPass ? isObscure : false,
      validator: validator,
      style: const TextStyle(color: kTextMain, fontSize: 15, fontWeight: FontWeight.w500), 
      cursorColor: const Color(0xFFCC5200), // Con trỏ nháy màu cam đậm
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: kTextMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFFCC5200), // Chữ nhãn nhảy lên màu cam đậm khi focus
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: kTextMuted.withOpacity(0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: kPrimaryOrange.withOpacity(0.6), size: 20), // Icon cam nhạt tone-sur-tone
        suffixIcon: isPass
            ? IconButton(
                icon: Icon(
                  isObscure ? Icons.visibility_off : Icons.visibility,
                  color: kPrimaryOrange.withOpacity(0.6),
                  size: 20,
                ),
                onPressed: onSuffixPressed,
              )
            : null,
        filled: true,
        fillColor: Colors.white, // Trả lại nền trắng tinh
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        
        // Trạng thái bình thường: Viền cam nhạt
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: kPrimaryOrange.withOpacity(0.35), width: 1.5),
        ),
        // Trạng thái khi click vào (Focus): Viền cam đậm (Dark Orange)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCC5200), width: 2.0),
        ),
        
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kErrorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kErrorRed, width: 2.0),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: kTextMuted,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            "Quên mật khẩu?",
            style: TextStyle(
              fontSize: 13,
              color: kTextMuted,
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
      height: 52, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Thêm gradient từ cam đậm sang cam sáng
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5500), Color(0xFFFF7700)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimaryOrange.withOpacity(0.3), // Tăng nhẹ shadow để tạo độ nổi
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.transparent, // Bắt buộc transparent để hiện màu gradient của Container
          shadowColor: Colors.transparent, 
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
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
                  letterSpacing: 1.2,
                  fontSize: 16,
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
          style: TextStyle(color: kTextMuted, fontSize: 14),
          children: [
            TextSpan(
              text: "Đăng ký ngay",
              style: TextStyle(
                color: kPrimaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLogins() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: kBorder, thickness: 1)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Hoặc đăng nhập bằng",
                style: TextStyle(color: kTextMuted, fontSize: 12),
              ),
            ),
            const Expanded(child: Divider(color: kBorder, thickness: 1)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircularSocialButton(
              iconPath: 'assets/zalo_icon.png',
              backgroundColor: const Color(0xFF0068FF),
              onTap: _handleZaloLogin,
            ),
            const SizedBox(width: 24), 
            _buildCircularSocialButton(
              iconPath: 'assets/google_icon.png',
              backgroundColor: Colors.white,
              isOutlined: true, 
              onTap: _handleGoogleLogin,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildCircularSocialButton({
    required String iconPath,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(40), 
      child: Container(
        width: 54, // 7. Thu nhỏ icon mạng xã hội
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: isOutlined ? Border.all(color: kBorder, width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03), 
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            iconPath, 
            width: 28, 
            height: 28, 
            errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.account_circle, size: 28)
          ),
        ),
      ),
    );
  }
}
