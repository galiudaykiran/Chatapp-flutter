import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import 'server_settings_screen.dart';
import 'user_list_screen.dart';
import 'chat_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _selectedIndex;
  bool _isShowingIncomingCall = false;

  final List<Widget> _screens = const [
    UserListScreen(),
    ProfileScreen(),
    ServerSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _checkIncomingCall(BuildContext context, ChatProvider chat) {
    final offer = chat.incomingCallOffer;
    if (offer != null && !_isShowingIncomingCall) {
      _isShowingIncomingCall = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (context) {
            final isVideo = offer.content == 'VIDEO';
            return Container(
              height: 320,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 16),
                      Text(isVideo ? 'Incoming HD Video Call...' : 'Incoming Encrypted Voice Call...', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(offer.sender, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                        onPressed: () {
                          chat.declineCall(offer.sender);
                          _isShowingIncomingCall = false;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.call_end_rounded, color: Colors.white),
                        label: const Text('Decline', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                        onPressed: () {
                          chat.acceptCall(offer.sender);
                          _isShowingIncomingCall = false;
                          Navigator.pop(context);

                          final contact = chat.contacts.firstWhere(
                            (u) => u.username.toLowerCase() == offer.sender.toLowerCase(),
                            orElse: () => UserModel(id: 0, username: offer.sender, email: '', mobileNumber: '', profileImage: null, status: 'ONLINE'),
                          );
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)));
                        },
                        icon: const Icon(Icons.call_rounded, color: Colors.white),
                        label: const Text('Accept', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ).then((_) => _isShowingIncomingCall = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    _checkIncomingCall(context, chatProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navBg = isDark
        ? AppTheme.surfaceDark.withValues(alpha: 0.95)
        : AppTheme.surfaceLight.withValues(alpha: 0.95);

    final navBorder = isDark
        ? AppTheme.cardBorderDark.withValues(alpha: 0.8)
        : AppTheme.cardBorderLight;

    final scaffoldBg = isDark ? AppTheme.bgDark : AppTheme.bgLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        color: Colors.transparent,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: navBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.primaryEmerald.withValues(alpha: 0.05),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                isDark: isDark,
                badgeCount: chatProvider.getTotalUnreadCount(),
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.tune_rounded,
                activeIcon: Icons.tune_rounded,
                label: 'Settings',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    final unselectedIconColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryEmerald.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.3), width: 1)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppTheme.primaryEmerald : unselectedIconColor,
                  size: 22,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -9,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryEmerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

