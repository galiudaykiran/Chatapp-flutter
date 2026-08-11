import 'user_model.dart';

class AuthResponse {
  final String token;
  final String tokenType;
  final UserModel user;

  AuthResponse({
    required this.token,
    this.tokenType = 'Bearer',
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? json['accessToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      user: json['user'] != null
          ? UserModel.fromJson(json['user'])
          : UserModel(
              username: json['username'] ?? '',
              email: json['email'] ?? '',
              mobileNumber: json['mobileNumber'],
              profileImage: json['profileImage'],
            ),
    );
  }
}
