import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SettingsProvider extends ChangeNotifier {
  String _serverIp = ApiConfig.serverIp;
  String _serverPort = ApiConfig.serverPort;
  ThemeMode _themeMode = ThemeMode.light;

  String get serverIp => _serverIp;
  String get serverPort => _serverPort;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    await ApiConfig.loadConfig();
    _serverIp = ApiConfig.serverIp;
    _serverPort = ApiConfig.serverPort;

    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('theme_mode') ?? 'dark';
      if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    } catch (_) {
      _themeMode = ThemeMode.dark;
    }

    notifyListeners();
  }

  Future<void> updateSettings(String ip, String port) async {
    await ApiConfig.saveConfig(ip, port);
    _serverIp = ip;
    _serverPort = port;
    notifyListeners();
  }

  Future<void> toggleThemeMode() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
  }
}

