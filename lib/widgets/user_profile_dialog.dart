import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'full_image_viewer.dart';
import 'task_reminder_dialog.dart';

class UserProfileDialog extends StatelessWidget {
  final UserModel user;

  const UserProfileDialog({super.key, required this.user});

  static void show(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = user.status == 'ONLINE';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.bgLight;
    final cardBorderColor = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: cardBorderColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar (Tap to view full image!)
          GestureDetector(
            onTap: () {
              FullImageViewer.show(
                context,
                imageUrl: user.profileImage,
                title: user.username,
                subtitle: user.status == 'ONLINE' ? 'Online Now • ${user.email}' : 'Offline • ${user.email}',
                onMessageTap: () => Navigator.pop(context),
              );
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.storyRingGradient,
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: cardBg,
                    backgroundImage: AppTheme.getProfileImageProvider(user.profileImage),
                    child: AppTheme.getProfileImageProvider(user.profileImage) == null
                        ? Text(
                            user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryEmerald,
                            ),
                          )
                        : null,
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isOnline ? AppTheme.statusOnline : AppTheme.statusOffline,
                    shape: BoxShape.circle,
                    border: Border.all(color: sheetBg, width: 3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // View Full Picture Chip
          GestureDetector(
            onTap: () {
              FullImageViewer.show(
                context,
                imageUrl: user.profileImage,
                title: user.username,
                subtitle: user.email,
                onMessageTap: () => Navigator.pop(context),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 14, color: AppTheme.primaryEmerald),
                  SizedBox(width: 4),
                  Text(
                    'Tap picture to expand full photo 🔍',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Username
          Text(
            user.username,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isOnline ? AppTheme.primaryEmerald.withValues(alpha: 0.15) : cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOnline ? AppTheme.primaryEmerald.withValues(alpha: 0.4) : cardBorderColor,
              ),
            ),
            child: Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isOnline ? AppTheme.primaryEmerald : textSecondaryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // User Info Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppTheme.primaryEmerald),
                  title: Text('Email Address', style: TextStyle(fontSize: 12, color: textSecondaryColor)),
                  subtitle: Text(
                    user.email,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryColor),
                  ),
                ),
                Divider(height: 1, color: cardBorderColor, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: AppTheme.primaryEmerald),
                  title: Text('Mobile Number', style: TextStyle(fontSize: 12, color: textSecondaryColor)),
                  subtitle: Text(
                    user.mobileNumber != null && user.mobileNumber!.isNotEmpty
                        ? user.mobileNumber!
                        : 'Not provided',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'MESSAGE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      TaskReminderDialog.show(
                        context,
                        targetId: user.username,
                        targetName: user.username,
                        isGroup: false,
                      );
                    },
                    icon: const Icon(Icons.alarm_add_rounded, color: AppTheme.primaryEmerald, size: 18),
                    label: const Text(
                      'TASK ⏰',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryEmerald),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

