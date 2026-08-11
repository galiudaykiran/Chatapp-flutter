import 'package:flutter/material.dart';
import '../models/user_model.dart';

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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: const Color(0xFF128C7E),
                backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                    ? NetworkImage(user.profileImage!)
                    : null,
                child: (user.profileImage == null || user.profileImage!.isEmpty)
                    ? Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: const TextStyle(
                            fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : null,
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF25D366) : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Username
          Text(
            user.username,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isOnline ? Colors.green[800] : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // User Info Card
          Card(
            elevation: 0,
            color: Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Color(0xFF075E54)),
                  title: const Text('Email Address', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(user.email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: Color(0xFF075E54)),
                  title: const Text('Mobile Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                    user.mobileNumber != null && user.mobileNumber!.isNotEmpty
                        ? user.mobileNumber!
                        : 'Not provided',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text('MESSAGE ${user.username.toUpperCase()}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
