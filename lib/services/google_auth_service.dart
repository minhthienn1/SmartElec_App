import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

class GoogleAuthService {
  // Thay thế bằng Web Client ID lấy từ file google-services.json (client_type: 3)
  static const String _serverClientId =
      '930935404216-cmi1b92m338plcit14c879lm0vul62ba.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _serverClientId,
    scopes: ['email', 'profile'],
  );

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Orchestrate the entire Google Login flow
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      debugPrint("Bắt đầu Google Auth Flow...");

      // 1. Kích hoạt luồng đăng nhập Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("Người dùng đã hủy đăng nhập Google");
      }

      // 2. Lấy thông tin xác thực từ request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception("Không thể lấy token xác thực từ Google");
      }

      // 3. Tạo credential cho Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Đăng nhập vào Firebase bằng credential
      debugPrint("Đăng nhập Firebase Auth...");
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Đăng nhập Firebase thất bại");
      }

      // 5. Lấy ID Token từ Firebase
      debugPrint("Lấy ID Token từ Firebase...");
      final String? idToken = await firebaseUser.getIdToken();

      if (idToken == null) {
        throw Exception("Không lấy được Firebase ID Token");
      }

      // 6. Gửi ID Token lên Backend của chúng ta
      debugPrint("Gửi ID Token lên Backend...");
      final backendResponse = await ApiService.googleLogin(idToken: idToken);

      return backendResponse;
    } catch (e) {
      debugPrint("Lỗi đăng nhập Google: $e");
      // Đăng xuất khỏi Google SignIn nếu có lỗi xảy ra để người dùng có thể thử lại
      await _googleSignIn.signOut();
      throw Exception("Đăng nhập Google thất bại: $e");
    }
  }

  /// Đăng xuất khỏi Google
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
