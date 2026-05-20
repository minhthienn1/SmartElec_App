class UserModel {
  final int id;
  final String phoneNumber;
  final String? fullName;
  final String gender; // Nó sẽ trả về "MALE", "FEMALE" hoặc "OTHER"
  final String? email;
  final String? avatarUrl;
  final String? address;
  final String role;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.fullName,
    required this.gender,
    this.email,
    this.avatarUrl,
    this.address,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      fullName: json['fullName'],
      gender: json['gender'] ?? 'OTHER',
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      address: json['address'],
      role: json['role'],
    );
  }

  // Hàm phụ để hiển thị tiếng Việt
  String get genderText {
    switch (gender) {
      case 'MALE': return 'Nam';
      case 'FEMALE': return 'Nữ';
      default: return 'Khác';
    }
  }
}