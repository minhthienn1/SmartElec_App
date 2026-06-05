import 'dart:convert';

class RepairCase {
  final String id;
  final String title;
  final DateTime date;
  final String summary;
  // ➕ Thêm 2 thuộc tính mới để làm "Sổ khám bệnh"
  final String status;  
  final String symptom; 

  RepairCase({
    required this.id,
    required this.title,
    required this.date,
    required this.summary,
    this.status = 'UNDER_DIAGNOSIS', // Giá trị mặc định phòng khi bị null
    this.symptom = '',
  });

  // Chuyển Object thành dạng Map chuẩn JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'summary': summary,
      'status': status,  // ➕ Thêm vào toMap
      'symptom': symptom, // ➕ Thêm vào toMap
    };
  }

  // Chuyển từ JSON ngược lại thành Object để hiện lên UI
  factory RepairCase.fromMap(Map<String, dynamic> map) {
    return RepairCase(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Chưa rõ thiết bị',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      summary: map['summary'] ?? '',
      status: map['status'] ?? 'UNDER_DIAGNOSIS', // ➕ Map trường status từ server
      symptom: map['symptom'] ?? '',              // ➕ Map trường symptom từ server
    );
  }

  // Tiện ích ép kiểu chuỗi JSON
  String toJson() => json.encode(toMap());
  factory RepairCase.fromJson(String source) =>
      RepairCase.fromMap(json.decode(source));
}