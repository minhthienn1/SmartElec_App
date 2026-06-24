import 'package:flutter/material.dart';

/// Provider quản lý số lượng thông báo chưa đọc trên icon chuông.
/// Các sự kiện FCM (job status) hoặc Socket sẽ gọi [increment],
/// khi khách bấm vào chuông sẽ gọi [clear].
class NotificationBadgeProvider extends ChangeNotifier {
  int _count = 0;

  int get count => _count;
  bool get hasUnread => _count > 0;

  void increment() {
    _count++;
    notifyListeners();
  }

  void clear() {
    if (_count == 0) return;
    _count = 0;
    notifyListeners();
  }
}
