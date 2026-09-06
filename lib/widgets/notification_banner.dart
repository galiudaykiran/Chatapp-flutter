import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../screens/chat_screen.dart';
import '../theme/app_theme.dart';

class NotificationBanner {
  static OverlayEntry? _currentEntry;

  static void show({
    BuildContext? context,
    required String title,
    required String body,
    String? senderUsername,
    String? senderProfileImage,
    String? currentUsername,
    bool isTaskReminder = false,
  }) {
    final effectiveContext = context ?? navigatorKey.currentContext;
    if (effectiveContext == null) return;

    final sender = senderUsername ?? (isTaskReminder ? 'Task Reminder' : 'System');
    final currentUser = currentUsername ?? '';

    if (!isTaskReminder && currentUser.isNotEmpty && sender.toLowerCase() == currentUser.toLowerCase()) return;

    // Remove any existing active banner
    dismiss();

    try {
      HapticFeedback.heavyImpact();
      FlutterRingtonePlayer().playNotification();
    } catch (_) {}

    final overlayState = Overlay.of(effectiveContext, rootOverlay: true);
    final isDark = Theme.of(effectiveContext).brightness == Brightness.dark;

    final bannerBg = isDark ? const Color(0xFF0F1E26) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                dismiss();
                final contact = UserModel(
                  id: 0,
                  username: sender,
                  email: title,
                  profileImage: senderProfileImage,
                  status: 'ONLINE',
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(contact: contact),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bannerBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isTaskReminder
                            ? const LinearGradient(colors: [Colors.orangeAccent, Colors.amberAccent])
                            : AppTheme.storyRingGradient,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isTaskReminder ? Colors.orange.shade900 : AppTheme.cardDark,
                        backgroundImage: isTaskReminder ? null : AppTheme.getProfileImageProvider(senderProfileImage),
                        child: isTaskReminder
                            ? const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 22)
                            : (AppTheme.getProfileImageProvider(senderProfileImage) == null
                                ? Text(
                                    title.isNotEmpty ? title[0].toUpperCase() : 'N',
                                    style: const TextStyle(
                                      color: AppTheme.primaryEmerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'NOW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_currentEntry!);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      dismiss();
    });
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}
