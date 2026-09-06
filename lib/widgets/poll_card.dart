import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';

class PollCard extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final bool isMe;

  const PollCard({
    super.key,
    required this.message,
    required this.isDark,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final currentUsername = Provider.of<AuthProvider>(context, listen: false).currentUser?.username ?? '';
    Map<String, dynamic> pollMap = {};
    try {
      if (message.pollData != null && message.pollData!.isNotEmpty) {
        pollMap = jsonDecode(message.pollData!);
      }
    } catch (_) {}

    final question = pollMap['question']?.toString() ?? message.content ?? 'Poll';
    final List<dynamic> rawOptions = pollMap['options'] is List ? pollMap['options'] : [];
    final bool allowMultiple = pollMap['allowMultiple'] == true;
    final Map<String, dynamic> rawVotes = pollMap['votes'] is Map ? pollMap['votes'] : {};

    // Calculate total votes
    int totalVotes = 0;
    for (var optVotes in rawVotes.values) {
      if (optVotes is List) {
        totalVotes += optVotes.length;
      }
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minWidth: 260),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.poll_rounded, color: AppTheme.primaryEmerald, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            allowMultiple ? 'Select one or more options' : 'Select one option',
            style: TextStyle(fontSize: 11, color: textSecondary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),

          // Options List
          ...rawOptions.asMap().entries.map((entry) {
            final int index = entry.key;
            final String optionText = entry.value?.toString() ?? '';
            final String optionKey = index.toString();
            final List<dynamic> voters = rawVotes[optionKey] is List ? rawVotes[optionKey] : [];
            final int voteCount = voters.length;
            final double percentage = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
            final bool hasUserVoted = voters.contains(currentUsername);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _toggleVote(context, currentUsername, optionKey, allowMultiple, pollMap);
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasUserVoted ? AppTheme.primaryEmerald : borderColor,
                      width: hasUserVoted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Progress fill
                      FractionallySizedBox(
                        widthFactor: percentage.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryEmerald.withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                      // Content inside option bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              hasUserVoted
                                  ? (allowMultiple ? Icons.check_box_rounded : Icons.radio_button_checked_rounded)
                                  : (allowMultiple ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked_rounded),
                              size: 18,
                              color: hasUserVoted ? AppTheme.primaryEmerald : textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: hasUserVoted ? FontWeight.bold : FontWeight.w500,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (totalVotes > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${(percentage * 100).round()}% ($voteCount)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: hasUserVoted ? AppTheme.primaryEmerald : textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.bold),
              ),
              if (totalVotes > 0)
                Text(
                  'Live updates',
                  style: TextStyle(fontSize: 10, color: AppTheme.primaryEmerald, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleVote(
    BuildContext context,
    String username,
    String optionKey,
    bool allowMultiple,
    Map<String, dynamic> pollMap,
  ) {
    if (username.isEmpty) return;

    final chat = Provider.of<ChatProvider>(context, listen: false);
    Map<String, dynamic> updatedPoll = Map<String, dynamic>.from(pollMap);
    Map<String, dynamic> votes = {};
    if (updatedPoll['votes'] is Map) {
      votes = Map<String, dynamic>.from(updatedPoll['votes']);
    }

    if (!allowMultiple) {
      for (var key in votes.keys) {
        if (votes[key] is List) {
          final list = List<dynamic>.from(votes[key]);
          list.remove(username);
          votes[key] = list;
        }
      }
    }

    List<dynamic> targetList = votes[optionKey] is List ? List<dynamic>.from(votes[optionKey]) : [];
    if (targetList.contains(username)) {
      targetList.remove(username);
    } else {
      targetList.add(username);
    }
    votes[optionKey] = targetList;
    updatedPoll['votes'] = votes;

    final updatedMessage = message.copyWith(
      type: MessageType.POLL,
      pollData: jsonEncode(updatedPoll),
    );

    chat.sendChatMessage(updatedMessage);
  }
}
