import '../config/api_config.dart';

class UserModel {
  final int? id;
  final String username;
  final String email;
  final String? mobileNumber;
  final String? profileImage;
  final String status;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    this.mobileNumber,
    this.profileImage,
    this.status = 'OFFLINE',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? rawImg = json['profileImage'];
    String? fixedImg = rawImg != null ? ApiConfig.fixUrl(rawImg) : null;

    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobileNumber'],
      profileImage: fixedImg != null && fixedImg.isNotEmpty ? fixedImg : null,
      status: json['status'] ?? 'OFFLINE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'mobileNumber': mobileNumber,
      'profileImage': profileImage,
      'status': status,
    };
  }
}
