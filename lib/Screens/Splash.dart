import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_elec/services/secure_storage_service.dart';
import 'package:smart_elec/services/storage_service.dart';
import 'package:smart_elec/providers/user_provider.dart';
import 'package:smart_elec/services/chat_socket_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

const Color kPrimaryOrange = Color(0xFFFF6600);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double textOpacity = 0;
  double textScale = 0.8;
  final _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();

    // Kích hoạt hiệu ứng xuất hiện cho CHỮ sau 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        textOpacity = 1.0;
        textScale = 1.0;
      });
    });

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    try {
      await StorageService.migrateOldToken();
    } catch (e) {
      debugPrint('⚠️ Migration error: $e');
    }

    // Giữ màn hình khoảng 2.5 giây để tạo ấn tượng thương hiệu
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final token = await _secureStorage.getAccessToken();

    if (token != null && !JwtDecoder.isExpired(token)) {
      if (mounted) {
        try {
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
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
            return;
          }
          
          debugPrint('✅ Auto-login successful, connecting to socket...');
          ChatSocketService().connect(null);
          
          Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
          String role = decodedToken['role'] ?? 'USER';

          if (role == 'TECHNICIAN') {
            if (mounted) Navigator.pushReplacementNamed(context, '/tech_main');
          } else {
            if (mounted) Navigator.pushReplacementNamed(context, '/main');
          }
        } catch (e) {
          debugPrint('❌ Error during auto-login: $e');
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryOrange,
      body: Center(
        child: AnimatedScale(
          scale: textScale,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack, // Giữ nguyên hiệu ứng nảy nhẹ cực xịn của cậu
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 800),
            opacity: textOpacity,
            // THAY THẾ CỤM RICHTEXT BẰNG SVG TẠI ĐÂY
            child: SvgPicture.asset(
              'assets/logo7.svg',
              width: 240, // Cậu có thể tăng/giảm số này để chỉnh logo to nhỏ cho vừa mắt
              
              // Mẹo nhỏ: Dòng dưới này sẽ ép toàn bộ Logo sang màu trắng tinh 
              // để nổi bần bật trên nền cam, bất kể lúc ở Figma cậu tô màu gì.
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}