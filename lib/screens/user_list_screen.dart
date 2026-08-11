import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/user_profile_dialog.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  String _searchQuery = '';
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
        chat.connectWebSocket(auth.token!, auth.currentUser!.username);
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chat = Provider.of<ChatProvider>(context);

    final currentUsername = auth.currentUser?.username.toLowerCase() ?? '';

    final filteredContacts = chat.contacts.where((u) {
      if (u.username.toLowerCase() == currentUsername) {
        return false; // Don't show current user in chat discovery list
      }
      return u.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (u.mobileNumber != null && u.mobileNumber!.contains(_searchQuery));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _loadContacts());
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: auth.currentUser?.profileImage != null && auth.currentUser!.profileImage!.isNotEmpty
                    ? NetworkImage(auth.currentUser!.profileImage!)
                    : null,
                child: (auth.currentUser?.profileImage == null || auth.currentUser!.profileImage!.isEmpty)
                    ? Text(
                        auth.currentUser?.username.isNotEmpty == true
                            ? auth.currentUser!.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('chatting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    auth.currentUser != null ? '@${auth.currentUser!.username}' : '',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadContacts(),
        child: Column(
          children: [
            // Connection Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: chat.isWsConnected ? Colors.green[700] : Colors.orange[800],
              child: Row(
                children: [
                  Icon(
                    chat.isWsConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chat.isWsConnected
                          ? 'WebSocket Connected (Real-Time)'
                          : 'Connecting to WebSocket...',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Error Banner if network or API failed
            if (chat.error != null)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Failed to load contacts: ${chat.error}\nPlease verify Server IP & Port settings.',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadContacts,
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),

            // Search Input
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search contacts by username, email, phone...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Contacts List View
            Expanded(
              child: chat.isLoadingContacts && chat.contacts.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF075E54)))
                  : filteredContacts.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching contacts found for "$_searchQuery".'
                                    : chat.contacts.length <= 1
                                        ? 'No other registered contacts found.\n(Only 1 registered user found on server. Register another account on Device 2).'
                                        : 'No other registered contacts found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _loadContacts,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh Contact List'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF075E54),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: filteredContacts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final contact = filteredContacts[index];
                            final isOnline = contact.status == 'ONLINE';

                            return ListTile(
                              leading: GestureDetector(
                                onTap: () => UserProfileDialog.show(context, contact),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF128C7E),
                                      foregroundColor: Colors.white,
                                      backgroundImage: contact.profileImage != null && contact.profileImage!.isNotEmpty
                                          ? NetworkImage(contact.profileImage!)
                                          : null,
                                      child: (contact.profileImage == null || contact.profileImage!.isEmpty)
                                          ? Text(
                                              contact.username.isNotEmpty
                                                  ? contact.username[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? const Color(0xFF25D366)
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                contact.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                '${contact.email} ${contact.mobileNumber != null ? '• ${contact.mobileNumber}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green[50] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOnline ? Colors.green[800] : Colors.grey[600],
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(contact: contact),
                                  ),
                                );
                              },
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
