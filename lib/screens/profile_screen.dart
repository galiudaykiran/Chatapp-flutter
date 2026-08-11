import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadProfileImage() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    final success = await auth.updateProfileImage(File(pickedFile.path));
    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        if (auth.token != null) chat.fetchContacts(auth.token!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.errorMessage ?? 'Failed to update profile picture')),
        );
      }
    }
  }

  void _handleLogout() async {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    chat.disconnectWebSocket();
    await auth.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('No user profile found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 64,
                          backgroundColor: const Color(0xFF128C7E),
                          backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                              ? NetworkImage(user.profileImage!)
                              : null,
                          child: (user.profileImage == null || user.profileImage!.isEmpty)
                              ? Text(
                                  user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                      fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _isUploading ? null : _pickAndUploadProfileImage,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF25D366),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap camera icon to change profile picture',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person, color: Color(0xFF075E54)),
                          title: const Text('Username', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(user.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email, color: Color(0xFF075E54)),
                          title: const Text('Gmail / Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(user.email, style: const TextStyle(fontSize: 15)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.phone, color: Color(0xFF075E54)),
                          title: const Text('Mobile Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(user.mobileNumber ?? 'Not provided', style: const TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('LOG OUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
