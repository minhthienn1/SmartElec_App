class AuthResponse {
  final String? accessToken;
  final String? message;
  final Map<String, dynamic>? user;

  AuthResponse({this.accessToken, this.message, this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      message: json['message'],
      user: json['user'],
    );
  }
}
