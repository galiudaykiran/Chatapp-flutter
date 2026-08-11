import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static String serverIp = '10.71.50.226';
  static String serverPort = '8080';

  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serverIp = prefs.getString('server_ip') ?? '10.71.50.226';
      serverPort = prefs.getString('server_port') ?? '8080';
    }
    catch (e) {
      serverIp = '10.71.50.226';
      serverPort = '8080';
    }
  }

  static Future<void> saveConfig(String ip, String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('server_port', port);
    serverIp = ip;
    serverPort = port;
  }

  static String get baseUrl => 'http://$serverIp:$serverPort';
  static String get wsUrl => 'ws://$serverIp:$serverPort/ws';
  static String get uploadUrl => '$baseUrl/api/files/upload';

  static String fixUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String fixed = url.trim();

    if (fixed.startsWith('/')) {
      return '$baseUrl$fixed';
    }

    try {
      Uri? parsed = Uri.tryParse(fixed);
      if (parsed != null && parsed.hasAuthority) {
        if (parsed.host == 'localhost' || parsed.host == '127.0.0.1' || parsed.host == '10.0.2.2') {
          final portNum = int.tryParse(serverPort) ?? 8080;
          return parsed.replace(host: serverIp, port: portNum).toString();
        }
      }
    } catch (_) {}

    return fixed;
  }
}
