class ChatSession {
  final int id;
  final String? deviceType;
  final String? symptom;
  final String? aiSummary;
  final String status;
  final bool isDangerous;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SessionUser? customer;
  final SessionUser? technician;
  final Map<String, dynamic>? review;
  final List<SessionMessage> messages;
  final String? contactName;
  final String? contactPhone;
  final String? address;
  final double? latitude;
  final double? longitude;

  ChatSession({
    required this.id,
    this.deviceType,
    this.symptom,
    this.aiSummary,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.technician,
    this.review,
    this.isDangerous = false,
    required this.messages,
    this.contactName,
    this.contactPhone,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      deviceType: json['deviceType'],
      symptom: json['symptom'],
      aiSummary: json['aiSummary'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt']).toLocal(),
      customer: json['user'] != null ? SessionUser.fromJson(json['user']) : null,
      technician: json['technician'] != null
          ? SessionUser.fromJson(json['technician'])
          : null,
      review: json['review'],
      isDangerous: json['isDangerous'] ?? false,
      messages: (json['messages'] as List?)
              ?.map((m) => SessionMessage.fromJson(m))
              .toList() ??
          [],
      contactName: json['contactName'],
      contactPhone: json['contactPhone'],
      address: json['address'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceType': deviceType,
      'symptom': symptom,
      'aiSummary': aiSummary,
      'status': status,
      'isDangerous': isDangerous,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'contactName': contactName,
      'contactPhone': contactPhone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class SessionUser {
  final int id;
  final String? fullName;
  final String? avatarUrl;
  final String role;
  final String? phoneNumber;
  final double? averageRating;
  final int? totalReviews;

  SessionUser({
    required this.id,
    this.fullName,
    this.avatarUrl,
    required this.role,
    this.phoneNumber,
    this.averageRating,
    this.totalReviews,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'],
      fullName: json['fullName'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'USER',
      phoneNumber: json['phoneNumber'],
      averageRating: json['averageRating'] != null ? double.tryParse(json['averageRating'].toString()) : null,
      totalReviews: json['totalReviews'] != null ? int.tryParse(json['totalReviews'].toString()) : null,
    );
  }
}

class SessionMessage {
  final int id;
  final String type;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final String? senderName;

  SessionMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    this.metadata,
    this.senderName,
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    return SessionMessage(
      id: json['id'],
      type: json['type'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      metadata: json['metadata'],
      senderName: json['sender']?['fullName'],
    );
  }
}
