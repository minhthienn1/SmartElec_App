import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import 'package:smart_elec/services/storage_service.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:smart_elec/services/chat_socket_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // --- ĐỒNG BỘ BẢNG MÀU SCI-FI CHUẨN ---
  static const Color kPrimaryCyan = Color(0xFF0EA5E9);       
  static const Color kSecondaryGreen = Color(0xFF22C55E);   
  static const Color kDeepBlack = Color(0xFF040812); 
  static const Color kMutedGrey = Color(0xFF9CA3AF);         
  static const Color kGlowGreen = Color(0xFF10B981);

  double logoOpacity = 0;
  double logoScale = 0.8;
  bool glow = false;
  final _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();

    // Hiệu ứng logo (GIỮ NGUYÊN)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        logoOpacity = 1;
        logoScale = 1;
      });
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        glow = true;
      });
    });

    // Logic Tự động đăng nhập & Điều hướng (GIỮ NGUYÊN)
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // 1. Dọn dẹp token cũ nếu có (Migration)
    try {
      await StorageService.migrateOldToken();
    } catch (e) {
      debugPrint('⚠️ Migration error: $e');
    }

    // Show splash for 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // 2. Lấy token mới từ Secure Storage
    final token = await _secureStorage.getAccessToken();

    if (token != null && !JwtDecoder.isExpired(token)) {
      // 3. Token hợp lệ -> Nạp Profile vào Provider với timeout
      if (mounted) {
        try {
          // Add timeout to profile fetching
          await Provider.of<UserProvider>(context, listen: false)
              .fetchProfile()
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  debugPrint('⏱️ fetchProfile timeout');
                  throw TimeoutException('Tải hồ sơ quá lâu');
                },
              );
          
          final user = Provider.of<UserProvider>(context, listen: false).user;
          if (user == null) {
            debugPrint('⚠️ User data is null after fetchProfile');
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
            return;
          }
          
          // 🟢 Kết nối Socket ngay sau khi nạp profile auto-login thành công
          debugPrint('✅ Auto-login successful, connecting to socket...');
          ChatSocketService().connect(null);
          
          // 4. Check role để điều hướng
          Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
          String role = decodedToken['role'] ?? 'USER';

          if (role == 'TECHNICIAN') {
            if (mounted) Navigator.pushReplacementNamed(context, '/tech_main');
          } else {
            if (mounted) Navigator.pushReplacementNamed(context, '/main');
          }
        } catch (e) {
          debugPrint('❌ Error during auto-login: $e');
          // Xử lý khi fetchProfile vấp lỗi hoặc timeout
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }
    } else {
      debugPrint('⚠️ No valid token found, redirecting to login');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack, // Đồng bộ nền tối hệ thống
      body: Stack(
        children: [
          _buildBackgroundEffect(),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  /// LOGO PHÁT QUANG ĐỒNG BỘ
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: glow
                          ? [
                              BoxShadow(
                                color: kGlowGreen.withOpacity(0.35),
                                blurRadius: 45,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: logoOpacity,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 600),
                        scale: logoScale,
                        child: Image.asset('assets/logo6.png', fit: BoxFit.cover), // Đồng bộ asset logo6
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  /// BRAND TITLE ĐỒNG BỘ ĐỘC QUYỀN
                  Text(
                    "SMARTELEC",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: [
                        Shadow(
                          color: kPrimaryCyan.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: kSecondaryGreen.withOpacity(0.02),
                      border: Border.all(color: kSecondaryGreen.withOpacity(0.3), width: 1),
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

                  const Spacer(),

                  /// LOADING TEXT TINH CHỈNH HIỆN ĐẠI
                  const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Text(
                      "Đang khởi động hệ thống...",
                      style: TextStyle(
                        color: kMutedGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffect() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.2,
          colors: [
            Color(0xFF0A1324),
            kDeepBlack,
          ],
        ),
      ),
    );
  }
}