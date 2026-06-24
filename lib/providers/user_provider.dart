import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../services/chat_socket_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profileData = await ApiService.getProfile();
      _user = UserModel.fromJson(profileData);
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔐 LOGOUT HOÀN CHỈNH: Xóa sạch Socket, Storage, và State
  Future<void> logout() async {
    try {
      debugPrint('🔐 [UserProvider] Bắt đầu quá trình đăng xuất...');

      // 1️⃣ NGẮT SOCKET: Đóng hoàn toàn kết nối Socket.io toàn hệ thống
      debugPrint('1️⃣ [UserProvider] Ngắt kết nối Socket...');
      try {
        ChatSocketService().disconnect();
        debugPrint('✅ [UserProvider] Socket đã ngắt kết nối');
      } catch (e) {
        debugPrint('⚠️ [UserProvider] Lỗi ngắt socket: $e');
      }

      // 1.5️⃣ XÓA FCM TOKEN TRÊN SERVER: Để không nhận thông báo cũ nữa
      debugPrint('1.5️⃣ [UserProvider] Xóa FCM Token trên server...');
      try {
        await ApiService.updateFcmToken('');
        debugPrint('✅ [UserProvider] Đã xóa FCM Token trên server');
      } catch (e) {
        debugPrint('⚠️ [UserProvider] Lỗi xóa FCM Token: $e');
      }

      // 2️⃣ XÓA STORAGE: Xóa sạch JWT Token và thông tin đăng nhập trong SecureStorage
      debugPrint('2️⃣ [UserProvider] Xóa dữ liệu SecureStorage...');
      try {
        await SecureStorageService().clearAll();
        debugPrint('✅ [UserProvider] SecureStorage đã xóa sạch');
      } catch (e) {
        debugPrint('⚠️ [UserProvider] Lỗi xóa SecureStorage: $e');
      }

      // 3️⃣ RESET STATE: Gán user = null để reset toàn bộ dữ liệu người dùng
      debugPrint('3️⃣ [UserProvider] Reset dữ liệu người dùng...');
      _user = null;
      _isLoading = false;

      // 4️⃣ NOTIFY: Thông báo cho UI vẽ lại giao diện
      debugPrint('4️⃣ [UserProvider] Thông báo UI vẽ lại...');
      notifyListeners();

      debugPrint('✅ [UserProvider] Đăng xuất hoàn tất thành công!');
    } catch (e) {
      debugPrint('❌ [UserProvider] LOGOUT THẤT BẠI: $e');
      // Vẫn đảm bảo reset state ngay cả khi có lỗi
      _user = null;
      _isLoading = false;
      notifyListeners();
    }
  }
}
