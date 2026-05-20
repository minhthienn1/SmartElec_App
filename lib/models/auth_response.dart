class AuthResponse {
  final String accessToken;
  final UserData user;

  AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      user: UserData.fromJson(json['user']),
    );
  }
}

class UserData {
  final String id;
  final String phoneNumber;
  final String? fullName;

  UserData({required this.id, required this.phoneNumber, this.fullName});

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      fullName: json['fullName'],
    );
  }
}
