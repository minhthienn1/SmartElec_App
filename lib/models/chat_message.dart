enum MessageType { TEXT, IMAGE, VIDEO, QUOTE_CARD }

class User {
  final int id;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final String? phoneNumber;
  final double? averageRating;
  final int? totalReviews;

  User({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.phoneNumber,
    this.averageRating,
    this.totalReviews,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id'].toString()) ?? 0,
      fullName: json['fullName'] ?? 'Người dùng',
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'USER',
      phoneNumber: json['phoneNumber'],
      averageRating: json['averageRating'] != null ? double.tryParse(json['averageRating'].toString()) : null,
      totalReviews: json['totalReviews'] != null ? int.tryParse(json['totalReviews'].toString()) : null,
    );
  }
}

class ChatMessage {
  final int id;
  final int sessionId;
  final int senderId;
  final MessageType type;
  final String content;
  Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;
  final User? sender;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.type,
    required this.content,
    this.metadata,
    required this.isRead,
    required this.createdAt,
    this.sender,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // ✅ PRODUCTION: Đảm bảo senderId luôn là int
    final senderId = int.tryParse(json['senderId'].toString()) ?? 0;
    
    // Parser string to enum
    MessageType parsedType = MessageType.TEXT;
    if (json['type'] == 'IMAGE') parsedType = MessageType.IMAGE;
    if (json['type'] == 'VIDEO') parsedType = MessageType.VIDEO;
    if (json['type'] == 'QUOTE_CARD') parsedType = MessageType.QUOTE_CARD;

    return ChatMessage(
      id: int.tryParse(json['id'].toString()) ?? 0,
      sessionId: int.tryParse(json['sessionId'].toString()) ?? 0,
      senderId: senderId,
      type: parsedType,
      content: json['content'] ?? '',
      metadata: json['metadata'],
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }
}
