import '../models/chat_message.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/group_info_dialog.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';
import 'server_settings_screen.dart';

enum ContactFilter { all, online }
enum MainTab { directChats, groups }

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  String _searchQuery = '';
  ContactFilter _selectedFilter = ContactFilter.all;
  MainTab _activeTab = MainTab.directChats;
  Timer? _statusRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
      // Periodically refresh contact list and online status every 8 seconds
      _statusRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted) _loadContactsQuietly();
      });
    });
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadContacts() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    if (auth.token != null && auth.token!.isNotEmpty) {
      chat.fetchContacts(auth.token!);
      if (!chat.isWsConnected && auth.currentUser != null) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
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
      }
    }
  }

  void _loadContactsQuietly() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    if (auth.token != null && auth.token!.isNotEmpty) {
      chat.fetchContacts(auth.token!);
    }
  }

  String _formatWhatsAppDate(int timestamp) {
    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(messageDate.year, messageDate.month, messageDate.day);
    final diffDays = today.difference(msgDay).inDays;

    if (diffDays == 0) {
      return DateFormat('hh:mm a').format(messageDate).toLowerCase();
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays > 1 && diffDays < 7) {
      return DateFormat('EEEE').format(messageDate);
    } else {
      return DateFormat('dd/MM/yy').format(messageDate);
    }
  }

  String _getLastMessageSnippet(ChatMessage msg) {
    if (msg.deleted) return 'This message was deleted';
    if (msg.isViewOnce) return 'Photo';
    if (msg.type == MessageType.IMAGE) return 'Photo';
    if (msg.type == MessageType.AUDIO) return 'Voice message';
    if (msg.type == MessageType.FILE) return msg.fileName ?? 'Document';
    if (msg.type == MessageType.LOCATION) return 'Location';
    if (msg.type == MessageType.POLL) {
      return msg.content != null && msg.content!.isNotEmpty ? 'Poll: ${msg.content}' : 'Poll';
    }
    return msg.content ?? '';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chat = Provider.of<ChatProvider>(context);

    final currentUser = auth.currentUser;
    final currentUsername = currentUser?.username.toLowerCase() ?? '';

    // Sorted contacts: sequential order by recent message timestamp (WhatsApp style)
    final allContacts = chat.getSortedContacts();

    final onlineContacts = allContacts.where((u) => u.status == 'ONLINE').toList();

    final filteredContacts = allContacts.where((u) {
      if (_selectedFilter == ContactFilter.online && u.status != 'ONLINE') {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          (u.mobileNumber != null && u.mobileNumber!.contains(query));
    }).toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark ? AppTheme.bgDark : AppTheme.bgLight;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final surfaceBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final cardBorderColor = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryEmerald,
          backgroundColor: surfaceBg,
          onRefresh: () async => _loadContacts(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              ).then((_) => _loadContacts());
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.storyRingGradient,
                              ),
                              child: UserAvatar(
                                username: currentUser?.username ?? 'U',
                                profileImage: currentUser?.profileImage,
                                radius: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentUser != null ? '@${currentUser.username}' : 'chatting',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Consumer<SettingsProvider>(
                            builder: (context, settings, _) {
                              return IconButton(
                                onPressed: () => settings.toggleThemeMode(),
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cardBorderColor),
                                  ),
                                  child: Icon(
                                    settings.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                    color: settings.isDarkMode ? Colors.amber : AppTheme.primaryEmerald,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
                              );
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: textSecondaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Network Error Banner (if any)
              if (chat.error != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Network Error: ${chat.error}\nPlease check server connection.',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadContacts,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('RETRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Search Bar Section (Placed TOP of Online Contacts!)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: textPrimaryColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search contacts by name, email or phone...',
                      hintStyle: TextStyle(color: textSecondaryColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondaryColor),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: cardBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppTheme.primaryEmerald, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Segmented Tab Bar (Direct Chats vs Groups)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = MainTab.directChats),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == MainTab.directChats ? AppTheme.primaryEmerald : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_rounded,
                                    size: 18,
                                    color: _activeTab == MainTab.directChats ? Colors.white : textSecondaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Direct Chats (${allContacts.length})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _activeTab == MainTab.directChats ? Colors.white : textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = MainTab.groups),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeTab == MainTab.groups ? AppTheme.primaryEmerald : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    size: 18,
                                    color: _activeTab == MainTab.groups ? Colors.white : textSecondaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Groups (${chat.groups.length})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _activeTab == MainTab.groups ? Colors.white : textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Filter Chips Row (Only for Direct Chats tab)
              if (_activeTab == MainTab.directChats) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All Contacts (${allContacts.length})',
                          isSelected: _selectedFilter == ContactFilter.all,
                          onTap: () => setState(() => _selectedFilter = ContactFilter.all),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Online Now (${onlineContacts.length})',
                          isSelected: _selectedFilter == ContactFilter.online,
                          onTap: () => setState(() => _selectedFilter = ContactFilter.online),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],

              // Main List View (Direct Chats vs Groups)
              if (_activeTab == MainTab.groups) ...[
                chat.groups.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardBorderColor),
                                ),
                                child: Icon(
                                  Icons.group_add_rounded,
                                  size: 56,
                                  color: textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No groups joined yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a new group chat with your contacts to get started!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                                  );
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Create New Group', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryEmerald,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final sortedGroups = chat.getSortedGroups();
                              final group = sortedGroups[index];
                              final lastMsg = chat.getLastMessageFor(group.groupId);
                              final unreadCount = chat.getUnreadCountFor(group.groupId);
                              final hasUnread = unreadCount > 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: hasUnread
                                        ? AppTheme.primaryEmerald.withValues(alpha: 0.4)
                                        : cardBorderColor,
                                    width: hasUnread ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppTheme.storyRingGradient,
                                      ),
                                      child: UserAvatar(
                                        username: group.name,
                                        radius: 25,
                                        isGroup: true,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            group.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: textPrimaryColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${group.members.length} Members',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryEmerald,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: lastMsg != null
                                          ? Row(
                                              children: [
                                                if (lastMsg.type == MessageType.IMAGE) ...[
                                                  Icon(Icons.camera_alt_rounded, size: 14, color: textSecondaryColor),
                                                  const SizedBox(width: 4),
                                                ] else if (lastMsg.type == MessageType.AUDIO) ...[
                                                  Icon(Icons.mic_rounded, size: 14, color: textSecondaryColor),
                                                  const SizedBox(width: 4),
                                                ] else if (lastMsg.type == MessageType.POLL) ...[
                                                  Icon(Icons.poll_rounded, size: 14, color: textSecondaryColor),
                                                  const SizedBox(width: 4),
                                                ] else if (lastMsg.isViewOnce) ...[
                                                  Icon(Icons.looks_one_rounded, size: 14, color: textSecondaryColor),
                                                  const SizedBox(width: 4),
                                                ] else if (lastMsg.type == MessageType.FILE) ...[
                                                  Icon(Icons.insert_drive_file_rounded, size: 14, color: textSecondaryColor),
                                                  const SizedBox(width: 4),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    '${lastMsg.sender.toLowerCase() == currentUsername ? 'You' : lastMsg.sender}: ${_getLastMessageSnippet(lastMsg)}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: hasUnread ? textPrimaryColor : textSecondaryColor,
                                                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              group.description != null && group.description!.isNotEmpty
                                                  ? group.description!
                                                  : 'Tap to chat with ${group.members.length} members',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: textSecondaryColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (lastMsg != null)
                                          Text(
                                            _formatWhatsAppDate(lastMsg.timestamp),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                              color: hasUnread ? const Color(0xFF25D366) : textSecondaryColor,
                                            ),
                                          )
                                        else
                                          Text(
                                            '${group.members.length}m',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textSecondaryColor,
                                            ),
                                          ),
                                        const SizedBox(height: 5),
                                        if (hasUnread)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF25D366),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                unreadCount > 99 ? '99+' : '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onTap: () => GroupInfoDialog.show(context, group),
                                            child: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryEmerald, size: 20),
                                          ),
                                      ],
                                    ),
                                    onTap: () {
                                      chat.setActiveConversation(group.groupId);
                                      final groupContact = UserModel(
                                        id: 0,
                                        username: group.groupId,
                                        email: group.name,
                                        status: 'ONLINE',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(contact: groupContact),
                                        ),
                                      ).then((_) {
                                        chat.setActiveConversation(null);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            childCount: chat.getSortedGroups().length,
                          ),
                        ),
                      ),
              ] else ...[
                // Main Direct Contacts List View
                chat.isLoadingContacts && chat.contacts.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryEmerald),
                        ),
                      )
                    : filteredContacts.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: Icon(
                                      Icons.people_outline_rounded,
                                      size: 56,
                                      color: textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No contacts matching "$_searchQuery"'
                                        : _selectedFilter == ContactFilter.online
                                            ? 'No contacts are currently online.'
                                            : 'No other registered contacts found.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textSecondaryColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _loadContacts,
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Refresh List'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryEmerald,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final contact = filteredContacts[index];
                                  final isOnline = contact.status == 'ONLINE';
                                  final lastMsg = chat.getLastMessageFor(contact.username);
                                  final unreadCount = chat.getUnreadCountFor(contact.username);
                                  final hasUnread = unreadCount > 0;

                                  return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: hasUnread
                                          ? AppTheme.primaryEmerald.withValues(alpha: 0.4)
                                          : cardBorderColor,
                                      width: hasUnread ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      leading: GestureDetector(
                                        onTap: () => UserProfileDialog.show(context, contact),
                                        child: Stack(
                                          children: [
                                            UserAvatar(
                                              username: contact.username,
                                              profileImage: contact.profileImage,
                                              radius: 25,
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: isOnline
                                                      ? AppTheme.statusOnline
                                                      : AppTheme.statusOffline,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: cardBg,
                                                    width: 2.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      title: Text(
                                        contact.username,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: textPrimaryColor,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: lastMsg != null
                                            ? Row(
                                                children: [
                                                  if (lastMsg.sender.toLowerCase() == currentUsername) ...[
                                                    Icon(
                                                      lastMsg.isRead || lastMsg.status == 'READ' || lastMsg.status == 'SEEN'
                                                          ? Icons.done_all_rounded
                                                          : Icons.done_rounded,
                                                      size: 15,
                                                      color: lastMsg.isRead || lastMsg.status == 'READ' || lastMsg.status == 'SEEN'
                                                          ? const Color(0xFF53BDEB)
                                                          : textSecondaryColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  if (lastMsg.type == MessageType.IMAGE) ...[
                                                    Icon(Icons.camera_alt_rounded, size: 14, color: textSecondaryColor),
                                                    const SizedBox(width: 4),
                                                  ] else if (lastMsg.type == MessageType.AUDIO) ...[
                                                    Icon(Icons.mic_rounded, size: 14, color: textSecondaryColor),
                                                    const SizedBox(width: 4),
                                                  ] else if (lastMsg.type == MessageType.POLL) ...[
                                                    Icon(Icons.poll_rounded, size: 14, color: textSecondaryColor),
                                                    const SizedBox(width: 4),
                                                  ] else if (lastMsg.isViewOnce) ...[
                                                    Icon(Icons.looks_one_rounded, size: 14, color: textSecondaryColor),
                                                    const SizedBox(width: 4),
                                                  ] else if (lastMsg.type == MessageType.FILE) ...[
                                                    Icon(Icons.insert_drive_file_rounded, size: 14, color: textSecondaryColor),
                                                    const SizedBox(width: 4),
                                                  ] else if (lastMsg.type == MessageType.LOCATION) ...[
                                                    Icon(Icons.location_on_rounded, size: 14, color: textSecondaryColor),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      _getLastMessageSnippet(lastMsg),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: hasUnread ? textPrimaryColor : textSecondaryColor,
                                                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                '${contact.email} ${contact.mobileNumber != null ? '• ${contact.mobileNumber}' : ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textSecondaryColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (lastMsg != null)
                                            Text(
                                              _formatWhatsAppDate(lastMsg.timestamp),
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                                color: hasUnread ? const Color(0xFF25D366) : textSecondaryColor,
                                              ),
                                            )
                                          else if (isOnline)
                                            const Text(
                                              'Online',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF25D366),
                                              ),
                                            ),
                                          const SizedBox(height: 5),
                                          if (hasUnread)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF25D366),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else if (isOnline)
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.phone_rounded, color: AppTheme.primaryEmerald, size: 19),
                                              tooltip: 'Voice Call',
                                              onPressed: () {
                                                final callProvider = Provider.of<CallProvider>(context, listen: false);
                                                callProvider.startCall(
                                                  receiverId: contact.id ?? 0,
                                                  receiverName: contact.username,
                                                  receiverProfileImage: contact.profileImage,
                                                  getAuthToken: () async => auth.token,
                                                );
                                              },
                                            )
                                          else
                                            const SizedBox(height: 12),
                                        ],
                                      ),
                                      onTap: () {
                                        chat.setActiveConversation(contact.username);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(contact: contact),
                                          ),
                                        ).then((_) {
                                          chat.setActiveConversation(null);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredContacts.length,
                            ),
                          ),
                        ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
        },
        backgroundColor: AppTheme.primaryEmerald,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final cardBorderColor = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryEmerald.withValues(alpha: 0.18) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryEmerald : cardBorderColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryEmerald : textSecondaryColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

