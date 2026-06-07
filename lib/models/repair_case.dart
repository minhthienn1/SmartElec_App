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

  // CÁC TRƯỜNG CỦA THỢ
  final String? mechanicName;
  final String? mechanicPhone;
  final double? rating;
  final String? reviewComment;
  final String? agreedPrice;
  final String? chatSummary;

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
    this.mechanicName,
    this.mechanicPhone,
    this.rating,
    this.reviewComment,
    this.agreedPrice,
    this.chatSummary,
  });

  Map<String, dynamic> toMap() {
    // Giữ nguyên như code của bạn
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
      'mechanicName': mechanicName,
      'mechanicPhone': mechanicPhone,
      'rating': rating,
      'reviewComment': reviewComment,
      'agreedPrice': agreedPrice,
      'chatSummary': chatSummary,
    };
  }

  factory RepairCase.fromMap(Map<String, dynamic> map) {
    return RepairCase(
      id: map['id']?.toString() ?? '', 
      
      title: map['title'] ?? map['deviceType'] ?? 'Lịch sử sửa chữa', 
      
      date: map['date'] != null 
          ? DateTime.parse(map['date']).toLocal() 
          : (map['createdAt'] != null ? DateTime.parse(map['createdAt']).toLocal() : DateTime.now()),
          
      // Phục vụ cho giao diện cũ (AI)
      summary: map['summary'] ?? map['aiSummary'] ?? '',
      status: map['status'] ?? 'UNDER_DIAGNOSIS',
      symptom: map['symptom'] ?? '',              
      advice: map['advice'] ?? 'Chưa có lời khuyên cụ thể.',
      dangerLevel: map['dangerLevel'] ?? 'Chưa xác định',
      needMechanic: map['needMechanic'] ?? false,
      
      // Lấy dữ liệu của Thợ
      mechanicName: map['mechanicName'],
      mechanicPhone: map['mechanicPhone'],
      rating: map['rating'] != null ? double.tryParse(map['rating'].toString()) : null,
      reviewComment: map['reviewComment'],
      agreedPrice: map['agreedPrice']?.toString(), // Đảm bảo giá tiền không bị lỗi format
      chatSummary: map['chatSummary'],
    );
  }

  String toJson() => json.encode(toMap());
  factory RepairCase.fromJson(String source) => RepairCase.fromMap(json.decode(source));
}