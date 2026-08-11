import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> checkAuthStatus() async {
    try {
      final savedToken = await _storage.read(key: 'jwt_token');
      final username = await _storage.read(key: 'username');
      final email = await _storage.read(key: 'email');

      if (savedToken != null) {
        _token = savedToken;
        try {
          final realUser = await ApiService.getCurrentUser(savedToken);
          _currentUser = realUser;
        } catch (_) {
          _currentUser = UserModel(
            username: username ?? '',
            email: email ?? '',
            status: 'ONLINE',
          );
        }
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      _token = response.token;
      _currentUser = response.user;

      await _storage.write(key: 'jwt_token', value: response.token);
      await _storage.write(key: 'username', value: response.user.username);
      await _storage.write(key: 'email', value: response.user.email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        username: username,
        email: email,
        mobileNumber: mobileNumber,
        password: password,
      );

      _token = response.token;
      _currentUser = response.user;

      await _storage.write(key: 'jwt_token', value: response.token);
      await _storage.write(key: 'username', value: response.user.username);
      await _storage.write(key: 'email', value: response.user.email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfileImage(File file) async {
    if (_token == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = await ApiService.updateProfileImage(_token!, file);
      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (_token != null) {
      await ApiService.logout(_token!);
    }
    _token = null;
    _currentUser = null;
    await _storage.deleteAll();
    notifyListeners();
  }
}
