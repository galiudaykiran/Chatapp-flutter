import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../screens/chat_screen.dart';
import 'full_image_viewer.dart';
import 'task_reminder_dialog.dart';

class GroupInfoDialog extends StatefulWidget {
  final GroupModel group;

  const GroupInfoDialog({super.key, required this.group});

  static void show(BuildContext context, GroupModel group) {
    showDialog(
      context: context,
      builder: (_) => GroupInfoDialog(group: group),
    );
  }

  @override
  State<GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<GroupInfoDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final surfaceBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final cardBorder = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;

    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final callProvider = Provider.of<CallProvider>(context);

    // Map group member usernames to contact models
    final allContacts = chat.contacts;
    final memberUsernames = widget.group.members;

    final filteredMembers = memberUsernames.where((m) {
      return m.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 450),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.storyRingGradient,
                            ),
                            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.group.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                '${widget.group.members.length} Members',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryEmerald,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  if (widget.group.description != null && widget.group.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        widget.group.description!,
                        style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Group Call, Tasks & Exit Row Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            callProvider.startCall(
                              receiverId: 0,
                              receiverName: widget.group.name,
                              receiverProfileImage: widget.group.groupImage,
                              getAuthToken: () async => auth.token,
                            );
                          },
                          icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 16),
                          label: const Text('Voice Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryEmerald,
                            minimumSize: const Size.fromHeight(40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            TaskReminderDialog.show(
                              context,
                              targetId: widget.group.groupId,
                              targetName: widget.group.name,
                              isGroup: true,
                            );
                          },
                          icon: const Icon(Icons.alarm_rounded, color: AppTheme.primaryEmerald, size: 16),
                          label: const Text('Tasks ⏰', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            side: const BorderSide(color: AppTheme.primaryEmerald),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Row(
                              children: [
                                Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Exit Group', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Text(
                              'Are you sure you want to exit "${widget.group.name}"? You will no longer receive messages or tasks from this group.',
                              style: TextStyle(color: textPrimary, fontSize: 13),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () async {
                                  Navigator.pop(ctx); // pop confirm dialog
                                  Navigator.pop(context); // pop group info sheet
                                  if (auth.token != null) {
                                    final success = await chat.leaveGroup(widget.group.groupId, auth.token!);
                                    if (success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Left group "${widget.group.name}" 🚪')),
                                      );
                                    }
                                  }
                                },
                                child: const Text('EXIT GROUP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 16),
                      label: const Text('EXIT / LEAVE GROUP 🚪', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Members List Search Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search group members...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  fillColor: surfaceBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                ),
              ),
            ),

            // Members List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: filteredMembers.length,
                itemBuilder: (context, index) {
                  final username = filteredMembers[index];
                  final isGroupAdmin = username.toLowerCase() == widget.group.adminUsername.toLowerCase();
                  final isMe = username.toLowerCase() == auth.currentUser?.username.toLowerCase();

                  // Find matching user model from contact list if present
                  final matchedUser = allContacts.firstWhere(
                    (u) => u.username.toLowerCase() == username.toLowerCase(),
                    orElse: () => UserModel(
                      id: index + 100,
                      username: username,
                      email: '$username@chatapp.com',
                      status: 'OFFLINE',
                    ),
                  );

                  final isOnline = matchedUser.status == 'ONLINE';

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder, width: 0.8),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: GestureDetector(
                        onTap: () {
                          FullImageViewer.show(
                            context,
                            imageUrl: matchedUser.profileImage,
                            title: matchedUser.username,
                            subtitle: 'Group Member • ${matchedUser.email}',
                          );
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                              backgroundImage: AppTheme.getProfileImageProvider(matchedUser.profileImage),
                              child: AppTheme.getProfileImageProvider(matchedUser.profileImage) == null
                                  ? Text(
                                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        color: AppTheme.primaryEmerald,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isOnline ? AppTheme.statusOnline : AppTheme.statusOffline,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardBg, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              username + (isMe ? ' (You)' : ''),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isGroupAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.accentCyan, width: 0.8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOnline ? AppTheme.statusOnline : textSecondary,
                        ),
                      ),
                      trailing: isMe
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryEmerald, size: 20),
                              tooltip: 'Direct Message',
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(contact: matchedUser),
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
