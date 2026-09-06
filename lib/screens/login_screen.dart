import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../models/group_model.dart';
import '../services/fcm_service.dart';
import '../widgets/notification_banner.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'main_shell_screen.dart';
import 'register_screen.dart';
import 'server_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final success = await authProvider.login(
      _usernameOrEmailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      if (authProvider.token != null && authProvider.currentUser != null) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);

        // Register In-App Notification Banner callback for incoming messages
        chatProvider.setOnNewMessageNotification((msg) {
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
              final group = chatProvider.groups.firstWhere(
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
              currentUsername: authProvider.currentUser?.username ?? '',
            );
          }
        });

        // Initialize FCM Service
        final fcmService = FcmService();
        fcmService.onIncomingCallReceived = (data) {
          callProvider.handleIncomingCall(data);
        };
        fcmService.initFirebase(getAuthToken: () async => authProvider.token);

        chatProvider.connectWebSocket(
          authProvider.token!,
          authProvider.currentUser!.username,
          onCallReceived: (data) {
            final status = data['status']?.toString();
            if (status == 'RINGING') {
              callProvider.handleIncomingCall(data);
            } else {
              callProvider.updateCallFromRemote(data);
            }
          },
        );
        chatProvider.fetchContacts(authProvider.token!);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
      );
    } else if (mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('chatting'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            tooltip: 'Server Settings (IP/Port)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: AppTheme.storyRingGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryEmerald.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 84,
                            height: 84,
                            color: AppTheme.primaryEmerald,
                            child: const Icon(Icons.chat_bubble_rounded, size: 42, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to your chatting account',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usernameOrEmailController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Username or Gmail',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter username or email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        return null;
                      },
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
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: authProvider.isLoading
                            ? const CircularProgressIndicator(color: AppTheme.bgDark)
                            : const Text(
                                'LOG IN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.bgDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        "Don't have an account? Register Here",
                        style: TextStyle(
                          color: AppTheme.primaryEmerald,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

