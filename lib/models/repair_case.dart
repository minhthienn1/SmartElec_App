import 'dart:convert';

class RepairCase {
  final String id;
  final String title;
  final DateTime date;
  final String summary;

  RepairCase({
    required this.id,
    required this.title,
    required this.date,
    required this.summary,
  });

  // Chuyển Object thành dạng Map chuẩn JSON (Sẵn sàng cho cả SharedPreferences và Firebase sau này)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'summary': summary,
    };
  }

  // Chuyển từ JSON ngược lại thành Object để hiện lên UI
  factory RepairCase.fromMap(Map<String, dynamic> map) {
    return RepairCase(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Chưa rõ thiết bị',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      summary: map['summary'] ?? '',
    );
  }

  // Tiện ích ép kiểu chuỗi JSON (Dùng cho SharedPreferences)
  String toJson() => json.encode(toMap());
  factory RepairCase.fromJson(String source) =>
      RepairCase.fromMap(json.decode(source));
}
