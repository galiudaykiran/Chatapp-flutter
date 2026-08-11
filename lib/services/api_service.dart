import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 4);

  static Future<AuthResponse> register({
    required String username,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'mobileNumber': mobileNumber,
          'password': password,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return AuthResponse.fromJson(json);
      } else {
        try {
          final err = jsonDecode(response.body);
          throw Exception(err['message'] ?? 'Registration failed');
        } catch (e) {
          if (e is Exception && e.toString().contains('Registration failed')) rethrow;
          throw Exception('HTTP ${response.statusCode}: Registration failed');
        }
      }
    } on TimeoutException {
      throw Exception('Server connection timed out (${ApiConfig.baseUrl}). Check Server IP in Settings.');
    } on SocketException {
      throw Exception('Unable to reach server (${ApiConfig.baseUrl}). Check Wi-Fi or Server IP.');
    }
  }

  static Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usernameOrEmail': usernameOrEmail,
          'password': password,
          'deviceInfo': 'Flutter Mobile App',
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return AuthResponse.fromJson(json);
      } else {
        try {
          final err = jsonDecode(response.body);
          throw Exception(err['message'] ?? 'Login failed');
        } catch (e) {
          if (e is Exception && e.toString().contains('Login failed')) rethrow;
          throw Exception('HTTP ${response.statusCode}: Login failed');
        }
      }
    } on TimeoutException {
      throw Exception('Server connection timed out (${ApiConfig.baseUrl}). Check Server IP in Settings.');
    } on SocketException {
      throw Exception('Unable to reach server (${ApiConfig.baseUrl}). Check Wi-Fi or Server IP.');
    }
  }

  static Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);
    } catch (_) {}
  }

  static Future<UserModel> getCurrentUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return UserModel.fromJson(json);
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch profile');
      }
    } on TimeoutException {
      throw Exception('Connection timed out connecting to ${ApiConfig.baseUrl}');
    } on SocketException {
      throw Exception('Socket error connecting to ${ApiConfig.baseUrl}');
    }
  }

  static Future<UserModel> updateProfileImage(String token, File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/auth/profile/image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return UserModel.fromJson(json);
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to update profile image');
      }
    } on TimeoutException {
      throw Exception('Upload connection timed out (${ApiConfig.baseUrl}). Check Server IP.');
    } on SocketException {
      throw Exception('Unable to connect to server (${ApiConfig.baseUrl}). Check Server IP.');
    }
  }

  static Future<List<UserModel>> getUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => UserModel.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Session expired or unauthorized (HTTP 401). Please re-login.');
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to load contacts');
      }
    } on TimeoutException {
      throw Exception('Connection timed out (${ApiConfig.baseUrl}). Check Server IP.');
    } on SocketException {
      throw Exception('Unable to reach server (${ApiConfig.baseUrl}). Check Server IP.');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
    String token,
    File file,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadUrl),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to upload file');
      }
    } on TimeoutException {
      throw Exception('Upload timed out (${ApiConfig.baseUrl}). Check Server IP.');
    } on SocketException {
      throw Exception('Unable to reach server (${ApiConfig.baseUrl}). Check Server IP.');
    }
  }
}

