import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../screens/chat_screen.dart';
import '../theme/app_theme.dart';
import 'notification_banner.dart';

class TaskReminderAlertDialog {
  static final Set<int> _triggeredTaskIds = <int>{};
  static final Map<int, Timer> _scheduledTimers = <int, Timer>{};

  /// Schedule a client-side local timer as a reliable fallback
  static void scheduleLocalReminder({
    required int id,
    required String title,
    String? description,
    required String targetId,
    required bool isGroup,
    required String creatorUsername,
    required int scheduledTimestamp,
  }) {
    if (_triggeredTaskIds.contains(id)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final delayMs = scheduledTimestamp - now;

    // Cancel any existing timer for this ID
    _scheduledTimers[id]?.cancel();

    if (delayMs <= 0) {
      // Due immediately or slightly in the past (within last 2 minutes)
      if (delayMs > -120000) {
        triggerAlert({
          'id': id,
          'title': title,
          'description': description ?? '',
          'targetId': targetId,
          'isGroup': isGroup,
          'creatorUsername': creatorUsername,
          'scheduledTimestamp': scheduledTimestamp,
        });
      }
      return;
    }

    _scheduledTimers[id] = Timer(Duration(milliseconds: delayMs), () {
      triggerAlert({
        'id': id,
        'title': title,
        'description': description ?? '',
        'targetId': targetId,
        'isGroup': isGroup,
        'creatorUsername': creatorUsername,
        'scheduledTimestamp': scheduledTimestamp,
      });
      _scheduledTimers.remove(id);
    });
  }

  /// Fire sound, haptic feedback, notification banner, and modal popup
  static void triggerAlert(Map<String, dynamic> payload) {
    final rawId = payload['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;

    if (id > 0 && _triggeredTaskIds.contains(id)) {
      return; // Deduplicate
    }
    if (id > 0) {
      _triggeredTaskIds.add(id);
      _scheduledTimers[id]?.cancel();
      _scheduledTimers.remove(id);
    }

    final title = payload['title']?.toString() ?? 'Task Reminder';
    final description = payload['description']?.toString() ?? '';
    final targetId = payload['targetId']?.toString() ?? '';
    final isGroup = payload['isGroup'] == true || payload['isGroup']?.toString() == 'true';
    final creator = payload['creatorUsername']?.toString() ?? 'You';
    final scheduledTimestamp = payload['scheduledTimestamp'] is int
        ? payload['scheduledTimestamp']
        : int.tryParse(payload['scheduledTimestamp']?.toString() ?? '0') ?? 0;

    // 1. Play real device notification ringtone sound & haptics
    try {
      FlutterRingtonePlayer().playNotification();
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 600), () => HapticFeedback.heavyImpact());
    } catch (_) {}

    // 2. Display Floating Top Notification Banner
    NotificationBanner.show(
      title: '⏰ REMINDER: $title',
      body: description.isNotEmpty ? description : 'Scheduled task reminder time!',
      isTaskReminder: true,
    );

    // 3. Display High-Priority Alert Modal Dialog
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF14242C) : Colors.white;
        final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
        final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
        final cardBorder = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;

        final timeFormatted = scheduledTimestamp > 0
            ? DateFormat('hh:mm a, MMM dd').format(DateTime.fromMillisecondsSinceEpoch(scheduledTimestamp))
            : DateFormat('hh:mm a').format(DateTime.now());

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Colors.orangeAccent, width: 2),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Alarm Icon Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.orangeAccent, Colors.amberAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orangeAccent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'TASK REMINDER ALERT',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1B22) : const Color(0xFFF4F8F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryEmerald),
                  const SizedBox(width: 6),
                  Text(
                    timeFormatted,
                    style: const TextStyle(
                      color: AppTheme.primaryEmerald,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (creator.isNotEmpty && creator != 'You') ...[
                const SizedBox(height: 6),
                Text(
                  isGroup ? 'Group:  • By ' : 'From: ',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'DISMISS',
                      style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (targetId.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryEmerald,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final contact = UserModel(
                          id: 0,
                          username: targetId,
                          email: targetId,
                          status: 'ONLINE',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(contact: contact),
                          ),
                        );
                      },
                      child: const Text(
                        'OPEN CHAT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
