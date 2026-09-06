import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class StarredMessagesScreen extends StatefulWidget {
  final String? filterContactUsername;

  const StarredMessagesScreen({super.key, this.filterContactUsername});

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  String _activeFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppTheme.bgDark : AppTheme.bgLight;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final cardBorder = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currentUsername = auth.currentUser?.username.toLowerCase() ?? '';

    List<ChatMessage> starredList = [];
    if (widget.filterContactUsername != null && widget.filterContactUsername!.isNotEmpty) {
      starredList = chat.getMessagesFor(widget.filterContactUsername!).where((m) => m.isStarred).toList();
    } else {
      for (var c in chat.contacts) {
        starredList.addAll(chat.getMessagesFor(c.username).where((m) => m.isStarred));
      }
      for (var g in chat.groups) {
        starredList.addAll(chat.getMessagesFor(g.groupId).where((m) => m.isStarred));
      }
    }

    starredList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (_activeFilter == 'MEDIA') {
      starredList = starredList.where((m) => m.type == MessageType.IMAGE || m.type == MessageType.AUDIO).toList();
    } else if (_activeFilter == 'DOCS') {
      starredList = starredList.where((m) => m.type == MessageType.FILE).toList();
    } else if (_activeFilter == 'TEXT') {
      starredList = starredList.where((m) => m.type == MessageType.TEXT || m.type == MessageType.EDIT).toList();
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.filterContactUsername != null
                  ? 'Starred in Chat'
                  : 'Starred Messages',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Starred', Icons.star_rounded, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('TEXT', 'Messages', Icons.chat_bubble_outline_rounded, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('MEDIA', 'Photos & Audio', Icons.photo_camera_back_rounded, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('DOCS', 'Documents', Icons.insert_drive_file_outlined, isDark),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: starredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_outline_rounded,
                            size: 56,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No starred messages found',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Star important messages to find them quickly here',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: starredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final msg = starredList[index];
                      final isMe = msg.sender.toLowerCase() == currentUsername;
                      final otherUser = isMe ? msg.recipient : msg.sender;
                      final dateStr = DateFormat('MMM d, hh:mm a').format(
                        DateTime.fromMillisecondsSinceEpoch(msg.timestamp),
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  UserAvatar(
                                    username: otherUser,
                                    radius: 14,
                                    isGroup: otherUser.startsWith('group_'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isMe ? 'You ➔ $otherUser' : msg.sender,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isMe ? AppTheme.accentCyan : AppTheme.primaryEmerald,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontSize: 10, color: textSecondary),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                    tooltip: 'Unstar',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      chat.toggleStarred(msg);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Message unstarred ⭐')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildMessageSnippet(msg, textPrimary, textSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, bool isDark) {
    final isSelected = _activeFilter == key;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = key),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      selectedColor: AppTheme.primaryEmerald,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildMessageSnippet(ChatMessage msg, Color primary, Color secondary) {
    switch (msg.type) {
      case MessageType.IMAGE:
        return Row(
          children: [
            const Icon(Icons.photo_rounded, color: AppTheme.accentCyan, size: 18),
            const SizedBox(width: 6),
            Text('Photo attachment', style: TextStyle(color: primary, fontWeight: FontWeight.w500)),
          ],
        );
      case MessageType.FILE:
        return Row(
          children: [
            const Icon(Icons.insert_drive_file_rounded, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                msg.fileName ?? 'Document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: primary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      case MessageType.AUDIO:
        return Row(
          children: [
            const Icon(Icons.mic_rounded, color: AppTheme.primaryEmerald, size: 18),
            const SizedBox(width: 6),
            Text('Voice note (0:${(msg.duration ?? 5).toString().padLeft(2, '0')})', style: TextStyle(color: primary, fontWeight: FontWeight.w500)),
          ],
        );
      case MessageType.LOCATION:
        return Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 6),
            Text('Shared GPS Location', style: TextStyle(color: primary, fontWeight: FontWeight.w500)),
          ],
        );
      default:
        return Text(
          msg.content ?? '',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: primary),
        );
    }
  }
}
