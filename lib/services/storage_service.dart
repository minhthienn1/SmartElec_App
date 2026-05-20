import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repair_case.dart'; // Đảm bảo đường dẫn import này đúng với cấu trúc của bạn

class StorageService {
  // Từ khóa bí mật để tìm đúng ngăn kéo chứa lịch sử
  static const String _storageKey = 'repair_history';

  /// Hàm 1: Cất dữ liệu (Lưu ca sửa chữa mới)
  Future<void> saveRepairCase(RepairCase repairCase) async {
    final prefs = await SharedPreferences.getInstance();

    // Mở ngăn kéo lấy danh sách cũ ra (nếu chưa có gì thì tạo danh sách rỗng [])
    List<String> historyStrings = prefs.getStringList(_storageKey) ?? [];

    // Thêm ca mới vào ĐẦU danh sách (Index 0) để nó luôn hiện lên trên cùng ở Home
    historyStrings.insert(0, repairCase.toJson());

    // Đóng ngăn kéo, cất lại vào bộ nhớ
    await prefs.setStringList(_storageKey, historyStrings);
  }

  /// Hàm 2: Lấy dữ liệu (Đọc lịch sử để hiển thị ở Home)
  Future<List<RepairCase>> getRecentRepairs() async {
    final prefs = await SharedPreferences.getInstance();

    // Mở ngăn kéo lấy danh sách chuỗi JSON ra
    List<String> historyStrings = prefs.getStringList(_storageKey) ?? [];

    // Dịch các chuỗi JSON đó ngược lại thành các Object RepairCase
    return historyStrings
        .map((jsonStr) => RepairCase.fromJson(jsonStr))
        .toList();
  }

  /// Hàm 3: Dọn dẹp Token cũ ở SharedPreferences (Migrate sang SecureStorage)
  static Future<void> migrateOldToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Kiểm tra các key cũ mà bác có thể đã dùng (jwt_token, access_token, token...)
    const legacyKeys = ['jwt_token', 'access_token', 'token'];
    
    bool foundLegacy = false;
    for (String key in legacyKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
        foundLegacy = true;
      }
    }

    if (foundLegacy) {
      debugPrint('🧹 [Migration] Đã dọn dẹp Token cũ từ SharedPreferences.');
    }
  }
}
