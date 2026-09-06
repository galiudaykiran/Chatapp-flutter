import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/chat_message.dart';
import 'models/group_model.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/call_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';
import 'screens/server_settings_screen.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'widgets/notification_banner.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init exception in main: $e");
  }
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
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'chatting',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            builder: (context, child) {
              return Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const CallScreen(),
                ],
              );
            },
            home: const AuthWrapper(),
          );
        },
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
    if (!mounted) return;

    if (isAuthenticated && auth.token != null && auth.currentUser != null) {
      final callProvider = Provider.of<CallProvider>(context, listen: false);

      // Register In-App Notification Banner callback for incoming messages
      chat.setOnNewMessageNotification((msg) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          String preview = 'New message';
          if (msg.type == MessageType.IMAGE) {
            preview = '📷 Photo attachment';
          } else if (msg.type == MessageType.AUDIO) {
            preview = '🎙️ Voice note';
          } else if (msg.type == MessageType.LOCATION) {
            preview = '📍 Shared location';
          } else if (msg.type == MessageType.FILE) {
            preview = '📄 Document file';
          } else if (msg.content != null && msg.content!.isNotEmpty) {
            preview = msg.content!;
          }

          String title = msg.sender;
          if (msg.recipient.startsWith('group_')) {
            final group = chat.groups.firstWhere(
              (g) => g.groupId == msg.recipient,
              orElse: () => GroupModel(groupId: msg.recipient, name: 'Group', adminUsername: '', members: [], createdAt: 0),
            );
            title = '${group.name} (${msg.sender})';
          }

          NotificationBanner.show(
            context: ctx,
            title: title,
            body: preview,
            senderUsername: msg.recipient.startsWith('group_') ? msg.recipient : msg.sender,
            currentUsername: auth.currentUser?.username ?? '',
          );
        }
      });

      // Initialize FCM Service
      final fcmService = FcmService();
      fcmService.onIncomingCallReceived = (data) {
        callProvider.handleIncomingCall(data);
      };
      await fcmService.initFirebase(getAuthToken: () async => auth.token);

      // Connect WebSocket with call signal callback
      chat.connectWebSocket(
        auth.token!,
        auth.currentUser!.username,
        onCallReceived: (data) {
          final status = data['status']?.toString();
          if (status == 'RINGING') {
            callProvider.handleIncomingCall(data);
          } else {
            callProvider.updateCallFromRemote(data);
          }
        },
      );
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
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryEmerald.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(color: AppTheme.primaryEmerald),
                  const SizedBox(height: 24),
                  Text(
                    'Connecting to server...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimaryLight,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Host: ${settings.serverIp}:${settings.serverPort}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryEmerald),
                    label: Text(
                      'Configure Server IP / Port',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.cardBorderDark
                            : AppTheme.cardBorderLight,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.cardDark
                          : AppTheme.cardLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    return auth.isAuthenticated ? const MainShellScreen() : const LoginScreen();
  }
}


