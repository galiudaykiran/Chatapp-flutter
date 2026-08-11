import 'package:flutter/material.dart';
import '../config/api_config.dart';

class SettingsProvider extends ChangeNotifier {
  String _serverIp = ApiConfig.serverIp;
  String _serverPort = ApiConfig.serverPort;

  String get serverIp => _serverIp;
  String get serverPort => _serverPort;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    await ApiConfig.loadConfig();
    _serverIp = ApiConfig.serverIp;
    _serverPort = ApiConfig.serverPort;
    notifyListeners();
  }

  Future<void> updateSettings(String ip, String port) async {
    await ApiConfig.saveConfig(ip, port);
    _serverIp = ip;
    _serverPort = port;
    notifyListeners();
  }
}
