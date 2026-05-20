/// Tập trung toàn bộ Magic Strings trạng thái đơn hàng.
/// Mọi file trong dự án PHẢI import và sử dụng class này
/// thay vì gõ tay chuỗi trạng thái.
///
/// Ví dụ:  if (status == JobStatus.matched) { ... }
class JobStatus {
  JobStatus._(); // Ngăn khởi tạo instance

  static const String aiConsulting = 'AI_CONSULTING';
  static const String broadcasting = 'BROADCASTING';
  static const String matched       = 'MATCHED';
  static const String enRoute       = 'EN_ROUTE';
  static const String arrived       = 'ARRIVED';
  static const String inProgress    = 'IN_PROGRESS';
  static const String completed     = 'COMPLETED';
  static const String cancelled     = 'CANCELLED';

  /// Danh sách tất cả trạng thái hợp lệ (dùng cho validation)
  static const List<String> all = [
    aiConsulting,
    broadcasting,
    matched,
    enRoute,
    arrived,
    inProgress,
    completed,
    cancelled,
  ];

  /// Nhãn hiển thị tiếng Việt tương ứng
  static String label(String status) {
    switch (status) {
      case aiConsulting: return 'Tư vấn AI';
      case broadcasting: return 'Tìm thợ...';
      case matched:      return 'Chờ thợ đi';
      case enRoute:      return 'Thợ đang đến';
      case arrived:      return 'Thợ đã đến';
      case inProgress:   return 'Đang sửa';
      case completed:    return 'Hoàn thành';
      case cancelled:    return 'Đã hủy';
      default:           return 'Đang xử lý';
    }
  }
}
