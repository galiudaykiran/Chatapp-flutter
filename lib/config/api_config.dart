import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static String serverIp = 'chatapp-backend-1-q3b9.onrender.com';
  static String serverPort = '443';

  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serverIp = prefs.getString('server_ip') ?? 'chatapp-backend-1-q3b9.onrender.com';
      serverPort = prefs.getString('server_port') ?? '443';
    }
    catch (e) {
      serverIp = 'chatapp-backend-1-q3b9.onrender.com';
      serverPort = '443';
    }
  }

  static Future<void> saveConfig(String ip, String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    await prefs.setString('server_port', port);
    serverIp = ip;
    serverPort = port;
  }

  static String get baseUrl {
    String cleanIp = serverIp.trim();
    if (cleanIp.startsWith('http://') || cleanIp.startsWith('https://')) {
      return cleanIp.endsWith('/') ? cleanIp.substring(0, cleanIp.length - 1) : cleanIp;
    }
    if (cleanIp.contains('onrender.com') || cleanIp.contains('.com') || cleanIp.contains('.io') || serverPort == '443') {
      final portSuffix = (serverPort.isNotEmpty && serverPort != '443' && serverPort != '80') ? ':$serverPort' : '';
      return 'https://$cleanIp$portSuffix';
    }
    return 'http://$cleanIp:$serverPort';
  }

  static String get wsUrl {
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return 'wss://${base.substring(8)}/ws';
    } else if (base.startsWith('http://')) {
      return 'ws://${base.substring(7)}/ws';
    }
    return 'ws://$serverIp:$serverPort/ws';
  }
  static String get uploadUrl => '$baseUrl/api/files/upload';

  static String get startCallUrl => '$baseUrl/api/calls/start';
  static String callTokenUrl(String callId) => '$baseUrl/api/calls/$callId/token';
  static String acceptCallUrl(String callId) => '$baseUrl/api/calls/$callId/accept';
  static String rejectCallUrl(String callId) => '$baseUrl/api/calls/$callId/reject';
  static String endCallUrl(String callId) => '$baseUrl/api/calls/$callId/end';
  static String cancelCallUrl(String callId) => '$baseUrl/api/calls/$callId/cancel';
  static String callStateUrl(String callId) => '$baseUrl/api/calls/$callId';
  static String get fcmTokenUrl => '$baseUrl/api/users/fcm-token';
  static String get callHistoryUrl => '$baseUrl/api/calls/history';
  static String get createGroupUrl => '$baseUrl/api/groups/create';
  static String get myGroupsUrl => '$baseUrl/api/groups/my-groups';

  static String fixUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String fixed = url.trim();

    if (fixed.startsWith('data:') || fixed.startsWith('blob:')) {
      return fixed;
    }

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
