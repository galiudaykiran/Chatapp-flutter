import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _ipController.text = settings.serverIp;
    _portController.text = settings.serverPort;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid IP address and Port')),
      );
      return;
    }

    Provider.of<SettingsProvider>(context, listen: false).updateSettings(ip, port);

    // Reconnect WebSocket & refresh contacts with the new IP if logged in
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.token != null && auth.currentUser != null) {
      chat.disconnectWebSocket();
      chat.connectWebSocket(auth.token!, auth.currentUser!.username);
      chat.fetchContacts(auth.token!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend URL set to http://$ip:$port')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final cardBorderColor = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.dns_rounded, color: AppTheme.primaryEmerald, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backend Connection',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                              Text(
                                'Configure Spring Boot server host IP & port.',
                                style: TextStyle(fontSize: 12, color: textSecondaryColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ipController,
                      style: TextStyle(color: textPrimaryColor),
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address or Render URL',
                        hintText: 'e.g. chatapp-backend.onrender.com or 192.168.1.5',
                        prefixIcon: Icon(Icons.cloud_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Render Quick Helper Chip
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.cloud_queue_rounded, size: 16, color: AppTheme.primaryEmerald),
                          label: const Text('Render Cloud URL Format', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: cardBg,
                          side: BorderSide(color: cardBorderColor),
                          onPressed: () {
                            _ipController.text = 'chatapp-backend-1-q3b9.onrender.com';
                            _portController.text = '443';
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _portController,
                      style: TextStyle(color: textPrimaryColor),
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Server Port (Leave 443 for Render / HTTPS)',
                        hintText: 'e.g. 8080 or 443',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryEmerald.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save_rounded, color: Colors.white),
                        label: const Text(
                          'SAVE CONFIGURATION',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

