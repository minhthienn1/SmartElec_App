class UserModel {
  final int id;
  final String phoneNumber;
  final String fullName;
  final String? email;
  final String role;
  final String? avatarUrl;
  final String? address;
  final String? gender;
  final bool needsPassword;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.email,
    required this.role,
    this.avatarUrl,
    this.address,
    this.gender,
    this.needsPassword = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      fullName: json['fullName'],
      email: json['email'],
      role: json['role'],
      avatarUrl: json['avatarUrl'],
      address: json['address'],
      gender: json['gender'],
      needsPassword: json['needsPassword'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'email': email,
      'role': role,
      'avatarUrl': avatarUrl,
      'address': address,
      'gender': gender,
      'needsPassword': needsPassword,
    };
  }
}
