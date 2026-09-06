import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedUsernames = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUsernames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 group member')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() => _isCreating = true);

    try {
      final newGroup = await chat.createGroup(
        token: auth.token!,
        name: name,
        description: _descriptionController.text.trim(),
        members: _selectedUsernames.toList(),
      );

      if (mounted) {
        setState(() => _isCreating = false);
        if (newGroup != null) {
          final groupContact = UserModel(
            id: 0,
            username: newGroup.groupId,
            email: newGroup.name,
            mobileNumber: newGroup.description ?? 'Group Chat',
            profileImage: newGroup.groupImage,
            status: 'ONLINE',
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(contact: groupContact),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create group. Try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currentUsername = auth.currentUser?.username.toLowerCase() ?? '';

    final availableContacts = chat.contacts
        .where((c) => c.username.toLowerCase() != currentUsername)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('New Group Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Icon & Name Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_add_rounded, color: AppTheme.primaryEmerald, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          style: TextStyle(color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                          decoration: InputDecoration(
                            hintText: 'Group Subject / Name *',
                            hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                        Divider(color: isDark ? AppTheme.cardBorderDark : Colors.grey.shade300, height: 1),
                        TextField(
                          controller: _descriptionController,
                          style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                          decoration: InputDecoration(
                            hintText: 'Group Description (Optional)',
                            hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Members (${_selectedUsernames.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                if (_selectedUsernames.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedUsernames.clear()),
                    child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Members Selection List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableContacts.length,
              itemBuilder: (context, index) {
                final contact = availableContacts[index];
                final isSelected = _selectedUsernames.contains(contact.username);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryEmerald : (isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: CheckboxListTile(
                    activeColor: AppTheme.primaryEmerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    value: isSelected,
                    onChanged: (bool? val) {
                      setState(() {
                        if (val == true) {
                          _selectedUsernames.add(contact.username);
                        } else {
                          _selectedUsernames.remove(contact.username);
                        }
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: AppTheme.primaryEmerald.withValues(alpha: 0.2),
                      child: Text(
                        contact.username.isNotEmpty ? contact.username[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                      ),
                    ),
                    title: Text(
                      contact.username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      contact.email,
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),

            // Create Group Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _handleCreateGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Create Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
