import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';
import 'screens/server_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChattingApp());
}

class ChattingApp extends StatelessWidget {
  const ChattingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'chatting',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF075E54),
            primary: const Color(0xFF075E54),
            secondary: const Color(0xFF25D366),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF075E54),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    setState(() => _isChecking = true);

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    await settings.loadSettings();
    if (!mounted) return;

    final isAuthenticated = await auth.checkAuthStatus();
    if (isAuthenticated && auth.token != null && auth.currentUser != null) {
      chat.connectWebSocket(auth.token!, auth.currentUser!.username);
      chat.fetchContacts(auth.token!);
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
    );
    if (mounted) {
      _checkAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      final settings = Provider.of<SettingsProvider>(context);

      return Scaffold(
        backgroundColor: const Color(0xFFECE5DD),
        appBar: AppBar(
          title: const Text('chatting'),
          backgroundColor: const Color(0xFF075E54),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Server Settings (IP/Port)',
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF075E54),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFF075E54)),
                const SizedBox(height: 20),
                const Text(
                  'Connecting to server...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF075E54),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Server IP: ${settings.serverIp}:${settings.serverPort}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure Server IP / Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075E54),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    return auth.isAuthenticated ? const MainShellScreen() : const LoginScreen();
  }
}

