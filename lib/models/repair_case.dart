import 'dart:convert';

class RepairCase {
  final String id;
  final String title;
  final DateTime date;
  final String summary;
  final String status;  
  final String symptom; 
  final String advice;
  final String dangerLevel;
  final bool needMechanic;

  RepairCase({
    required this.id,
    required this.title,
    required this.date,
    required this.summary,
    this.status = 'UNDER_DIAGNOSIS', 
    this.symptom = '',
    this.advice = '',               
    this.dangerLevel = 'Unknown',   
    this.needMechanic = false,      
  });

  // Chuyển Object thành dạng Map chuẩn JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'summary': summary,
      'status': status,  
      'symptom': symptom, 
      'advice': advice,           
      'dangerLevel': dangerLevel,  
      'needMechanic': needMechanic, 
    };
  }

  // Chuyển từ JSON ngược lại thành Object để hiện lên UI
  factory RepairCase.fromMap(Map<String, dynamic> map) {
    return RepairCase(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Chưa rõ thiết bị',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      summary: map['summary'] ?? '',
      status: map['status'] ?? 'UNDER_DIAGNOSIS',
      symptom: map['symptom'] ?? '',              
      advice: map['advice'] ?? 'Chưa có lời khuyên cụ thể.',
      dangerLevel: map['dangerLevel'] ?? 'Chưa xác định',
      needMechanic: map['needMechanic'] ?? false,
    );
  }

  // Tiện ích ép kiểu chuỗi JSON
  String toJson() => json.encode(toMap());
  factory RepairCase.fromJson(String source) =>
      RepairCase.fromMap(json.decode(source));
}