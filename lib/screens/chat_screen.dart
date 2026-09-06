import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/user_avatar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/task_reminder_model.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/group_info_dialog.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/task_reminder_dialog.dart';
import 'starred_messages_screen.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' hide MessageType;
import '../services/webrtc_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel contact;

  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatProvider? _chatProvider;
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  bool _isTyping = false;
  bool _isSearching = false;
  bool _isRecordingVoice = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  int _lastMessageCount = 0;
  final _searchController = TextEditingController();
  final Set<String> _selectedMessageIds = {};
  ChatMessage? _pinnedMessage;
  ChatMessage? _replyingToMessage;
  int? _chatWideVisibilitySeconds;
  int? _oneOffVisibilitySeconds;
  int? get _activeVisibilitySeconds => _oneOffVisibilitySeconds ?? _chatWideVisibilitySeconds;
  set _activeVisibilitySeconds(int? val) {
    _oneOffVisibilitySeconds = val;
    _chatWideVisibilitySeconds = val;
  }
  List<TaskReminderModel> _activeChatTasks = [];

  @override
  void initState() {
    super.initState();
    _loadDisappearingTimerPref();
    _loadPinnedMessage();
    _messageController.addListener(() {
      final typing = _messageController.text.trim().isNotEmpty;
      if (typing != _isTyping) {
        setState(() => _isTyping = typing);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
      _loadChatTasks();
      final chat = Provider.of<ChatProvider>(context, listen: false);
      chat.setActiveConversation(widget.contact.username);
    });
  }

  void _loadPinnedMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_pinned_${widget.contact.username.toLowerCase()}';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && mounted) {
        final data = jsonDecode(jsonStr);
        setState(() => _pinnedMessage = ChatMessage.fromJson(data));
      }
    } catch (_) {}
  }

  void _savePinnedMessage(ChatMessage? msg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_pinned_${widget.contact.username.toLowerCase()}';
      if (msg == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(msg.toJson()));
      }
    } catch (_) {}
  }

  void _togglePinMessage(ChatMessage m) {
    setState(() {
      if (_pinnedMessage?.id == m.id || '${_pinnedMessage?.timestamp}' == '${m.timestamp}') {
        _pinnedMessage = null;
        _savePinnedMessage(null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unpinned 📌')),
        );
      } else {
        _pinnedMessage = m;
        _savePinnedMessage(m);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message pinned to top! 📌')),
        );
      }
    });
  }

  void _loadDisappearingTimerPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_disappearing_${widget.contact.username.toLowerCase()}';
      final val = prefs.getInt(key);
      if (val != null && mounted) {
        setState(() => _chatWideVisibilitySeconds = val);
      }
    } catch (_) {}
  }

  void _loadChatTasks() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.token != null) {
      final tasks = await chat.fetchTasksForTarget(widget.contact.username, auth.token!);
      if (mounted) {
        setState(() {
          _activeChatTasks = tasks.where((t) => !t.isCompleted && !t.isTriggered).toList();
        });
      }
    }
  }

  void _resetOneOffTimerIfUsed() {
    if (_oneOffVisibilitySeconds != null && mounted) {
      setState(() => _oneOffVisibilitySeconds = null);
    }
  }

  void _markRead() {
    if (mounted) {
      Provider.of<ChatProvider>(context, listen: false).markMessagesAsRead(widget.contact.username);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _chatProvider?.setActiveConversation(null);
    _recordTimer?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _recordDuration = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordDuration++);
      }
    });
  }

  void _cancelVoiceRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordDuration = 0;
    });
  }

  Widget _buildReplyBar(bool isDark, Color textPrimaryColor) {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    final sender = _replyingToMessage!.sender;
    final preview = _replyingToMessage!.content ??
        (_replyingToMessage!.fileName != null
            ? '📄 ${_replyingToMessage!.fileName}'
            : (_replyingToMessage!.type == MessageType.IMAGE
                ? '📷 Photo'
                : (_replyingToMessage!.type == MessageType.AUDIO ? '🎙️ Voice note' : 'Attachment')));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: const BorderSide(color: AppTheme.accentCyan, width: 4),
          top: BorderSide(color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight),
          right: BorderSide(color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight),
          bottom: BorderSide(color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: AppTheme.accentCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $sender',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingToMessage = null),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _formatVisibilityLabel(int? seconds) {
    if (seconds == null || seconds <= 0) return 'Off';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  Future<void> _handleSummarizeWithAi() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.token == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryEmerald)),
    );
    final summary = await chat.summarizeChatWithAi(widget.contact.username, auth.token!);
    if (!mounted) return;
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark ? AppTheme.cardDark : AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.accentCyan, size: 22),
            SizedBox(width: 10),
            Text('Chat Summary (AI)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            summary ?? 'Could not summarize chat. Make sure GEMINI_API_KEY is configured.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDisappearingMessagesSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    final options = [
      {'label': 'Off (Permanent Messages)', 'seconds': null},
      {'label': '10 Seconds', 'seconds': 10},
      {'label': '30 Seconds', 'seconds': 30},
      {'label': '1 Minute', 'seconds': 60},
      {'label': '5 Minutes', 'seconds': 300},
      {'label': '1 Hour', 'seconds': 3600},
      {'label': '24 Hours', 'seconds': 86400},
    ];

    String selectedScope = 'entire_chat';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeSec = selectedScope == 'entire_chat'
                ? _chatWideVisibilitySeconds
                : _oneOffVisibilitySeconds;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.timer_rounded, color: AppTheme.accentCyan, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Disappearing Messages Timer',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set messages to disappear automatically for participants in this chat.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(height: 14),

                      // Scope Selector: Entire Chat vs Particular Message
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1E26) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => selectedScope = 'entire_chat'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selectedScope == 'entire_chat' ? AppTheme.primaryEmerald : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Entire Chat',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: selectedScope == 'entire_chat' ? Colors.white : textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => selectedScope = 'particular_msg'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selectedScope == 'particular_msg' ? AppTheme.accentCyan : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Next Message Only',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: selectedScope == 'particular_msg' ? Colors.black87 : textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedScope == 'entire_chat'
                            ? 'All future messages sent in this conversation will expire.'
                            : 'Applies only to the next single message you send.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textSecondary),
                      ),
                      const SizedBox(height: 10),

                      ...options.map((opt) {
                        final sec = opt['seconds'] as int?;
                        final isSelected = activeSec == sec;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          leading: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppTheme.primaryEmerald : textSecondary,
                            size: 20,
                          ),
                          title: Text(
                            opt['label'] as String,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryEmerald : textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          trailing: sec != null
                              ? Text('⏳ ${_formatVisibilityLabel(sec)}', style: TextStyle(color: textSecondary, fontSize: 12))
                              : null,
                          onTap: () async {
                            Navigator.pop(context);
                            if (selectedScope == 'entire_chat') {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final chat = Provider.of<ChatProvider>(context, listen: false);
                              final messenger = ScaffoldMessenger.of(context);

                              setState(() {
                                _chatWideVisibilitySeconds = sec;
                              });

                              if (auth.currentUser != null) {
                                final label = sec != null ? _formatVisibilityLabel(sec) : 'off';
                                chat.sendTextMessage(
                                  sender: auth.currentUser!.username,
                                  recipient: widget.contact.username,
                                  content: sec != null
                                      ? '⏱️ You turned on disappearing messages ($label)'
                                      : '⏱️ You turned off disappearing messages',
                                );
                              }

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    sec != null
                                        ? 'Entire chat messages will disappear after ${_formatVisibilityLabel(sec)} ⏳'
                                        : 'Disappearing messages turned off for this chat.',
                                  ),
                                ),
                              );

                              try {
                                final prefs = await SharedPreferences.getInstance();
                                final key = 'chat_disappearing_${widget.contact.username.toLowerCase()}';
                                if (sec != null) {
                                  await prefs.setInt(key, sec);
                                } else {
                                  await prefs.remove(key);
                                }
                              } catch (_) {}
                            } else {
                              setState(() {
                                _oneOffVisibilitySeconds = sec;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    sec != null
                                        ? 'Next message set to disappear after ${_formatVisibilityLabel(sec)} ⏳'
                                        : 'Particular message timer cleared.',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      }),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMultiDeleteDialog(List<ChatMessage> allMessages) {
    final selectedMsgs = allMessages.where((m) =>
        _selectedMessageIds.contains(m.id) ||
        _selectedMessageIds.contains('${m.timestamp}')).toList();

    if (selectedMsgs.isEmpty) return;

    final chat = Provider.of<ChatProvider>(context, listen: false);
    final curUser = chat.currentUsername?.toLowerCase();
    final allFromMe = curUser != null && selectedMsgs.every((m) => m.sender.toLowerCase() == curUser);
    final someFromMe = curUser != null && selectedMsgs.any((m) => m.sender.toLowerCase() == curUser);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Delete ${selectedMsgs.length} message(s)?', style: TextStyle(color: textPrimary, fontSize: 18)),
        content: Text(
          'Choose how you want to delete the selected message(s).',
          style: TextStyle(color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              chat.deleteMultipleForMe(widget.contact.username, _selectedMessageIds.toList());
              setState(() => _selectedMessageIds.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleted for you 🗑️')),
              );
            },
            child: const Text('Delete for Me', style: TextStyle(color: Colors.redAccent)),
          ),
          if (someFromMe)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                final msgsToDeleteForEveryone = selectedMsgs.where((m) => m.sender.toLowerCase() == curUser).toList();
                chat.deleteMultipleForEveryone(widget.contact.username, msgsToDeleteForEveryone);
                if (!allFromMe) {
                  final otherIds = selectedMsgs.where((m) => m.sender.toLowerCase() != curUser).map((m) => m.id ?? '${m.timestamp}').toList();
                  chat.deleteMultipleForMe(widget.contact.username, otherIds);
                }
                setState(() => _selectedMessageIds.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deleted for everyone! 🗑️')),
                );
              },
              child: const Text('Delete for Everyone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _sendVoiceNote() {
    _recordTimer?.cancel();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    if (auth.currentUser == null) return;

    final duration = _recordDuration > 0 ? _recordDuration : 3;

    chat.sendAudioMessage(
      sender: auth.currentUser!.username,
      recipient: widget.contact.username,
      durationSeconds: duration,
      visibilitySeconds: _activeVisibilitySeconds,
    );

    setState(() {
      _isRecordingVoice = false;
      _recordDuration = 0;
    });
    _scrollToBottom();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice note audio message sent! 🎙️'), duration: Duration(seconds: 2)),
    );
  }

  void _showGroupDetailsDialog() {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final group = chat.groups.firstWhere(
      (g) => g.groupId.toLowerCase() == widget.contact.username.toLowerCase(),
      orElse: () => GroupModel(
        groupId: widget.contact.username,
        name: widget.contact.email,
        description: 'Group Conversation',
        adminUsername: 'Admin',
        members: [widget.contact.username],
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    GroupInfoDialog.show(context, group);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(String msgId) {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final msgs = chat.getMessagesFor(widget.contact.username);
    final index = msgs.indexWhere((m) => m.id == msgId || '${m.timestamp}' == msgId);
    if (index != -1 && _scrollController.hasClients) {
      final total = msgs.length;
      final targetFraction = (index / (total > 0 ? total : 1)).clamp(0.0, 1.0);
      final targetOffset = _scrollController.position.maxScrollExtent * targetFraction;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _sendText() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    if (auth.currentUser == null) return;

    final reply = _replyingToMessage;
    String? replyText;
    if (reply != null) {
      if (reply.content != null && reply.content!.isNotEmpty) {
        replyText = reply.content;
      } else if (reply.fileName != null) {
        replyText = '📄 ${reply.fileName}';
      } else if (reply.type == MessageType.IMAGE) {
        replyText = '📷 Photo attachment';
      } else if (reply.type == MessageType.AUDIO) {
        replyText = '🎙️ Voice note';
      } else if (reply.type == MessageType.LOCATION) {
        replyText = '📍 Location';
      } else {
        replyText = 'Attachment';
      }
    }

    chat.sendTextMessage(
      sender: auth.currentUser!.username,
      recipient: widget.contact.username,
      content: text,
      visibilitySeconds: _activeVisibilitySeconds,
      replyToId: reply?.id ?? (reply != null ? '${reply.timestamp}' : null),
      replyToSender: reply?.sender,
      replyToText: replyText,
    );

    _messageController.clear();
    if (_replyingToMessage != null) {
      setState(() => _replyingToMessage = null);
    }
    _resetOneOffTimerIfUsed();
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage({bool isViewOnce = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.currentUser == null || auth.token == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      await chat.sendImageMessage(
        sender: auth.currentUser!.username,
        recipient: widget.contact.username,
        file: File(pickedFile.path),
        token: auth.token!,
        visibilitySeconds: _activeVisibilitySeconds,
        isViewOnce: isViewOnce,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.currentUser == null || auth.token == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    setState(() => _isUploading = true);

    try {
      await chat.sendFileMessage(
        sender: auth.currentUser!.username,
        recipient: widget.contact.username,
        file: File(result.files.single.path!),
        token: auth.token!,
        visibilitySeconds: _activeVisibilitySeconds,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendLocation() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    if (auth.currentUser == null) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS Location Services.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      chat.sendLocationMessage(
        sender: auth.currentUser!.username,
        recipient: widget.contact.username,
        latitude: position.latitude,
        longitude: position.longitude,
        visibilitySeconds: _activeVisibilitySeconds,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _showCodeSnippetDialog() {
    final codeController = TextEditingController();
    String selectedLanguage = 'Dart';
    final languages = ['Dart', 'Java', 'Python', 'JavaScript', 'SQL', 'C++', 'HTML/CSS', 'JSON'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
          final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.code_rounded, color: AppTheme.accentNeon),
                const SizedBox(width: 8),
                Text('Send Code Snippet', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: selectedLanguage,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                    isExpanded: true,
                    items: languages.map((lang) {
                      return DropdownMenuItem(value: lang, child: Text(lang));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedLanguage = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    maxLines: 10,
                    minLines: 4,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste or type code snippet here...',
                      hintStyle: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      fillColor: const Color(0xFF1E293B),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Code'),
                onPressed: () {
                  final code = codeController.text.trim();
                  if (code.isNotEmpty) {
                    final formattedMessage = '```${selectedLanguage.toLowerCase()}\n$code\n```';
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final chat = Provider.of<ChatProvider>(context, listen: false);
                    if (auth.currentUser != null) {
                      chat.sendTextMessage(
                        sender: auth.currentUser!.username,
                        recipient: widget.contact.username,
                        content: formattedMessage,
                        visibilitySeconds: _activeVisibilitySeconds,
                      );
                      _scrollToBottom();
                    }
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForwardModal(List<ChatMessage> msgsToForward) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final chat = Provider.of<ChatProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
        final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Forward Message to...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: chat.contacts.length,
                  itemBuilder: (context, index) {
                    final target = chat.contacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AppTheme.getProfileImageProvider(target.profileImage),
                        child: AppTheme.getProfileImageProvider(target.profileImage) == null
                            ? Text(target.username.isNotEmpty ? target.username[0].toUpperCase() : 'U')
                            : null,
                      ),
                      title: Text(target.username, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text(target.email, style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.send_rounded, color: AppTheme.primaryEmerald),
                      onTap: () {
                        Navigator.pop(context);
                        for (var m in msgsToForward) {
                          if (m.type == MessageType.TEXT && m.content != null) {
                            chat.sendTextMessage(
                              sender: auth.currentUser!.username,
                              recipient: target.username,
                              content: m.content!,
                            );
                          }
                        }
                        setState(() => _selectedMessageIds.clear());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Forwarded to ${target.username}! 🚀')),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
        final textPrimaryColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Row 1: Task Reminder, Image, Document
              Row(
                children: [
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.alarm_add_rounded,
                      label: 'Task Reminder',
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.pop(context);
                        final isGroup = widget.contact.username.startsWith('group_');
                        TaskReminderDialog.show(
                          context,
                          targetId: widget.contact.username,
                          targetName: widget.contact.username,
                          isGroup: isGroup,
                        );
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.photo_camera_rounded,
                      label: 'Image',
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendImage();
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendFile();
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Row 2: Location, Voice Note, Code Snippet
              Row(
                children: [
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      color: Colors.tealAccent.shade400,
                      onTap: () {
                        Navigator.pop(context);
                        _sendLocation();
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.mic_rounded,
                      label: 'Voice Note',
                      color: Colors.amber,
                      onTap: () {
                        Navigator.pop(context);
                        _sendVoiceNote();
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.code_rounded,
                      label: 'Code Snippet',
                      color: AppTheme.accentNeon,
                      onTap: () {
                        Navigator.pop(context);
                        _showCodeSnippetDialog();
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Row 3: Disappearing Messages Timer
              Row(
                children: [
                  Expanded(
                    child: _buildAttachmentOption(
                      icon: Icons.timer_outlined,
                      label: 'Disappearing',
                      color: AppTheme.accentCyan,
                      onTap: () {
                        Navigator.pop(context);
                        _showDisappearingMessagesSheet();
                      },
                      textColor: textPrimaryColor,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ChatMessage message) {
    final controller = TextEditingController(text: message.content ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Edit Message', style: TextStyle(color: textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: textPrimary),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter edited content...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                Provider.of<ChatProvider>(context, listen: false).editMessage(message, newText);
              }
              Navigator.pop(context);
            },
            child: const Text('Save Edit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCallModal(bool isVideo) {
    if (!isVideo) {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      callProvider.startCall(
        receiverId: widget.contact.id ?? 0,
        receiverName: widget.contact.username,
        receiverProfileImage: widget.contact.profileImage,
        getAuthToken: () async => authProvider.token,
      );
      return;
    }

    final chat = Provider.of<ChatProvider>(context, listen: false);
    chat.sendCallOffer(widget.contact.username, isVideo);

    final webrtc = WebRtcService();
    webrtc.initializeRenderers().then((_) {
      webrtc.startLocalStream(isVideo);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isMuted = false;
        bool isSpeaker = true;

        return Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            final isConnected = chatProvider.isInActiveCall;
            final isEnded = chatProvider.activeCallPeer == null && !isConnected;

            if (isEnded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) Navigator.pop(context);
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
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
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isVideo ? 'HD Live Video Call (WebRTC P2P)' : 'Encrypted Voice Call',
                        style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      if (isVideo)
                        Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.5), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: RTCVideoView(webrtc.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 54,
                          backgroundImage: AppTheme.getProfileImageProvider(widget.contact.profileImage),
                          child: AppTheme.getProfileImageProvider(widget.contact.profileImage) == null
                              ? Text(
                                  widget.contact.username.isNotEmpty ? widget.contact.username[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                )
                              : null,
                        ),
                      const SizedBox(height: 16),
                      Text(
                        widget.contact.username,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isConnected ? '00:15 Connected (Encrypted WebRTC Stream)' : 'Ringing...',
                        style: TextStyle(
                          color: isConnected ? AppTheme.primaryEmerald : Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 32,
                        icon: Icon(isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: isMuted ? Colors.redAccent : Colors.white),
                        onPressed: () {
                          isMuted = !isMuted;
                          webrtc.toggleMute(isMuted);
                          (context as Element).markNeedsBuild();
                        },
                      ),
                      FloatingActionButton(
                        backgroundColor: Colors.redAccent,
                        onPressed: () {
                          chat.endCall(widget.contact.username);
                          webrtc.dispose();
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        },
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                      ),
                      IconButton(
                        iconSize: 32,
                        icon: Icon(isSpeaker ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: isSpeaker ? AppTheme.primaryEmerald : Colors.white),
                        onPressed: () {
                          isSpeaker = !isSpeaker;
                          webrtc.toggleSpeaker(isSpeaker);
                          (context as Element).markNeedsBuild();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => webrtc.dispose());
  }

  void _showStarredMessagesSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StarredMessagesScreen(filterContactUsername: widget.contact.username),
      ),
    );
  }

  String _formatWhatsAppChatDate(int timestamp) {
    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(messageDate.year, messageDate.month, messageDate.day);
    final diffDays = today.difference(msgDay).inDays;

    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays > 1 && diffDays < 7) {
      return DateFormat('EEEE').format(messageDate);
    } else {
      return DateFormat('d MMMM yyyy').format(messageDate);
    }
  }

  Widget _buildWhatsAppDatePill(int timestamp, bool isDark) {
    final dateText = _formatWhatsAppChatDate(timestamp);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182229) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF222E35) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chat = Provider.of<ChatProvider>(context);

    final messages = chat.getMessagesFor(widget.contact.username);
    final isOnline = widget.contact.status == 'ONLINE';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark ? AppTheme.bgDark : AppTheme.bgLight;
    final surfaceBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final cardBorderColor = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markRead();
      });
    }

    final isSelecting = _selectedMessageIds.isNotEmpty;

    List<ChatMessage> displayedMessages = messages;
    if (_isSearching && _searchController.text.trim().isNotEmpty) {
      final query = _searchController.text.trim().toLowerCase();
      displayedMessages = messages
          .where((m) => (m.content ?? '').toLowerCase().contains(query) || (m.fileName ?? '').toLowerCase().contains(query))
          .toList();
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: isSelecting
          ? AppBar(
              backgroundColor: AppTheme.primaryEmerald,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => setState(() => _selectedMessageIds.clear()),
              ),
              title: Text(
                '${_selectedMessageIds.length} Selected',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                if (_selectedMessageIds.length == 1)
                  IconButton(
                    icon: const Icon(Icons.push_pin_rounded, color: Colors.white),
                    tooltip: 'Pin Message',
                    onPressed: () {
                      final selectedMsg = messages.firstWhere((m) => m.id == _selectedMessageIds.first || '${m.timestamp}' == _selectedMessageIds.first);
                      setState(() {
                        _pinnedMessage = selectedMsg;
                        _selectedMessageIds.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message pinned to top! 📌')),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                  tooltip: 'Copy',
                  onPressed: () {
                    final selectedMsgs = messages.where((m) => _selectedMessageIds.contains(m.id) || _selectedMessageIds.contains('${m.timestamp}')).toList();
                    final fullText = selectedMsgs.map((m) => m.content ?? '').where((t) => t.isNotEmpty).join('\n---\n');
                    if (fullText.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: fullText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied selected messages! 📋')),
                      );
                    }
                    setState(() => _selectedMessageIds.clear());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.shortcut_rounded, color: Colors.white),
                  tooltip: 'Forward',
                  onPressed: () {
                    final selectedMsgs = messages.where((m) => _selectedMessageIds.contains(m.id) || _selectedMessageIds.contains('${m.timestamp}')).toList();
                    _showForwardModal(selectedMsgs);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  tooltip: 'Delete',
                  onPressed: () => _showMultiDeleteDialog(messages),
                ),
              ],
            )
          : AppBar(
              titleSpacing: 0,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: textPrimaryColor),
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        hintStyle: TextStyle(color: textSecondaryColor, fontSize: 14),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    )
                  : Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (widget.contact.username.startsWith('group_')) {
                              _showGroupDetailsDialog();
                            } else {
                              UserProfileDialog.show(context, widget.contact);
                            }
                          },
                          child: UserAvatar(
                            username: widget.contact.username,
                            profileImage: widget.contact.profileImage,
                            radius: 18,
                            isGroup: widget.contact.username.startsWith('group_'),
                            showOnlineBadge: !widget.contact.username.startsWith('group_'),
                            isOnline: isOnline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (widget.contact.username.startsWith('group_')) {
                                _showGroupDetailsDialog();
                              } else {
                                UserProfileDialog.show(context, widget.contact);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.contact.username.startsWith('group_')
                                      ? widget.contact.email
                                      : widget.contact.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimaryColor,
                                  ),
                                ),
                                Text(
                                  widget.contact.username.startsWith('group_')
                                      ? 'Tap to view group members'
                                      : (chat.isUserTyping(widget.contact.username)
                                          ? 'typing...'
                                          : (isOnline ? 'online' : 'offline')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: chat.isUserTyping(widget.contact.username) ? FontWeight.bold : FontWeight.normal,
                                    color: widget.contact.username.startsWith('group_')
                                        ? AppTheme.primaryEmerald
                                        : (chat.isUserTyping(widget.contact.username)
                                            ? AppTheme.primaryEmerald
                                            : (isOnline ? AppTheme.statusOnline : textSecondaryColor)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
              actions: [
                if (_isSearching) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${displayedMessages.length} found',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close Search',
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                      });
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: textPrimaryColor, size: 22),
                    tooltip: 'Search Messages',
                    onPressed: () => setState(() => _isSearching = true),
                  ),
                  if (widget.contact.username.startsWith('group_'))
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryEmerald, size: 22),
                      tooltip: 'Group Info & Members',
                      onPressed: _showGroupDetailsDialog,
                    ),
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppTheme.primaryEmerald, size: 22),
                    tooltip: 'Voice Call',
                    onPressed: () => _showCallModal(false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_rounded, color: AppTheme.accentCyan, size: 22),
                    tooltip: 'Video Call',
                    onPressed: () => _showCallModal(true),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: textPrimaryColor),
                    color: cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) {
                    if (value == 'ai_summarize') {
                      _handleSummarizeWithAi();
                    } else if (value == 'disappearing') {
                      _showDisappearingMessagesSheet();
                    } else if (value == 'search') {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) _searchController.clear();
                      });
                    } else if (value == 'starred') {
                      _showStarredMessagesSheet();
                    } else if (value == 'profile') {
                      UserProfileDialog.show(context, widget.contact);
                    } else if (value == 'clear') {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: cardBg,
                          title: Text('Clear Chat', style: TextStyle(color: textPrimaryColor)),
                          content: Text(
                            'Delete local chat history with ${widget.contact.username}?',
                            style: TextStyle(color: textSecondaryColor),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel', style: TextStyle(color: textSecondaryColor)),
                            ),
                            TextButton(
                              onPressed: () {
                                chat.clearChat(widget.contact.username);
                                Navigator.pop(context);
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'ai_summarize',
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentCyan, size: 20),
                          const SizedBox(width: 12),
                          Text('Summarize with AI 🤖', style: TextStyle(color: textPrimaryColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'disappearing',
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: AppTheme.accentCyan, size: 20),
                          const SizedBox(width: 12),
                          Text('Disappearing Messages', style: TextStyle(color: textPrimaryColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: textPrimaryColor, size: 20),
                          const SizedBox(width: 12),
                          Text(_isSearching ? 'Close Search' : 'Search Chat', style: TextStyle(color: textPrimaryColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'starred',
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          Text('Starred Messages', style: TextStyle(color: textPrimaryColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: AppTheme.primaryEmerald, size: 20),
                          const SizedBox(width: 12),
                          Text('View Profile', style: TextStyle(color: textPrimaryColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 12),
                          Text('Clear Chat', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
      body: Column(
        children: [
          if (_activeChatTasks.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF231F14) : const Color(0xFFFEF3C7),
                border: const Border(bottom: BorderSide(color: Colors.orangeAccent, width: 1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_on_rounded, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active Reminder: ${_activeChatTasks.first.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orangeAccent : Colors.orange.shade900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final isGroup = widget.contact.username.startsWith('group_');
                      TaskReminderDialog.show(
                        context,
                        targetId: widget.contact.username,
                        targetName: widget.contact.username,
                        isGroup: isGroup,
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  ),
                ],
              ),
            ),
          if (_pinnedMessage != null)
            GestureDetector(
              onTap: () {
                if (_pinnedMessage?.id != null) {
                  _scrollToMessage(_pinnedMessage!.id!);
                } else if (_pinnedMessage?.timestamp != null) {
                  _scrollToMessage('${_pinnedMessage!.timestamp}');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  border: Border(
                    bottom: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pinned message',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• Tap to view',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pinnedMessage!.content ?? _pinnedMessage!.fileName ?? "Attachment",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        setState(() => _pinnedMessage = null);
                        _savePinnedMessage(null);
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_isUploading)
            const LinearProgressIndicator(
              color: AppTheme.primaryEmerald,
              backgroundColor: Colors.transparent,
              minHeight: 3,
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).unfocus();
                if (_selectedMessageIds.isNotEmpty) {
                  setState(() => _selectedMessageIds.clear());
                }
              },
              child: messages.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 28, color: AppTheme.primaryEmerald),
                          const SizedBox(height: 8),
                          Text(
                            'End-to-End Direct Chat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Send a message to start conversation with ${widget.contact.username}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: displayedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = displayedMessages[index];
                      final isMe = auth.currentUser != null &&
                          msg.sender.toLowerCase() == auth.currentUser!.username.toLowerCase();
                      final msgId = msg.id ?? '${msg.timestamp}';
                      final isSel = _selectedMessageIds.contains(msgId);

                      bool showDateHeader = false;
                      if (index == 0) {
                        showDateHeader = true;
                      } else {
                        final prevMsg = displayedMessages[index - 1];
                        final prevDate = DateTime.fromMillisecondsSinceEpoch(prevMsg.timestamp);
                        final currDate = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
                        showDateHeader = prevDate.year != currDate.year ||
                            prevDate.month != currDate.month ||
                            prevDate.day != currDate.day;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader)
                            _buildWhatsAppDatePill(msg.timestamp, isDark),
                          ChatBubble(
                            message: msg,
                            isMe: isMe,
                            isSelected: isSel,
                            onEdit: _showEditDialog,
                            onTap: () {
                              if (_selectedMessageIds.isNotEmpty) {
                                setState(() {
                                  if (_selectedMessageIds.contains(msgId)) {
                                    _selectedMessageIds.remove(msgId);
                                  } else {
                                    _selectedMessageIds.add(msgId);
                                  }
                                });
                              } else {
                                FocusScope.of(context).unfocus();
                              }
                            },
                            onLongPress: _selectedMessageIds.isNotEmpty
                                ? () {
                                    setState(() {
                                      if (_selectedMessageIds.contains(msgId)) {
                                        _selectedMessageIds.remove(msgId);
                                      } else {
                                        _selectedMessageIds.add(msgId);
                                      }
                                    });
                                  }
                                : null,
                            onReply: (m) => setState(() => _replyingToMessage = m),
                            onReplyTap: (replyId) => _scrollToMessage(replyId),
                            onPin: (m) => _togglePinMessage(m),
                            onForward: (m) => _showForwardModal([m]),
                            onDelete: (m) {
                              chat.deleteForMe(m);
                            },
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            decoration: BoxDecoration(
              color: surfaceBg,
              border: Border(top: BorderSide(color: cardBorderColor)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingToMessage != null)
                    _buildReplyBar(isDark, textPrimaryColor),
                  if (_activeVisibilitySeconds != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded, size: 14, color: AppTheme.accentCyan),
                          const SizedBox(width: 6),
                          Text(
                            'Messages vanish after ${_formatVisibilityLabel(_activeVisibilitySeconds)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _activeVisibilitySeconds = null),
                            child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.accentCyan),
                          ),
                        ],
                      ),
                    ),
                  _isRecordingVoice
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
                              tooltip: 'Cancel Recording',
                              onPressed: _cancelVoiceRecording,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Recording 0:${_recordDuration.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Voice Audio Note 🎙️',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                tooltip: 'Send Voice Note',
                                onPressed: _sendVoiceNote,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: cardBorderColor, width: 1),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryEmerald, size: 24),
                                      tooltip: 'Share Media, Tasks & Code',
                                      splashRadius: 20,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: _showAttachmentSheet,
                                    ),
                                    if (_activeVisibilitySeconds != null && _activeVisibilitySeconds! > 0)
                                      GestureDetector(
                                        onTap: _showDisappearingMessagesSheet,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentCyan.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppTheme.accentCyan, width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.timer_outlined, size: 11, color: AppTheme.accentCyan),
                                              const SizedBox(width: 2),
                                              Text(
                                                _formatVisibilityLabel(_activeVisibilitySeconds),
                                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: TextField(
                                        controller: _messageController,
                                        style: TextStyle(color: textPrimaryColor, fontSize: 14.5),
                                        textCapitalization: TextCapitalization.sentences,
                                        minLines: 1,
                                        maxLines: 4,
                                        decoration: InputDecoration(
                                          hintText: 'Type a message...',
                                          hintStyle: TextStyle(color: textSecondaryColor, fontSize: 14.5),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                        ),
                                        onSubmitted: (_) => _sendText(),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.attach_file_rounded, color: AppTheme.primaryEmerald, size: 22),
                                      tooltip: 'Send Document',
                                      splashRadius: 20,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      onPressed: _pickAndSendFile,
                                    ),
                                    if (!_isTyping) ...[
                                      IconButton(
                                        icon: const Icon(Icons.photo_camera_rounded, color: AppTheme.primaryEmerald, size: 22),
                                        tooltip: 'Send Image',
                                        splashRadius: 20,
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        onPressed: _pickAndSendImage,
                                      ),
                                    ],
                                    const SizedBox(width: 2),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _isTyping ? AppTheme.primaryGradient : null,
                                color: _isTyping ? null : AppTheme.primaryEmerald,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryEmerald.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isTyping ? Icons.send_rounded : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                tooltip: _isTyping ? 'Send Message' : 'Record Voice Note',
                                onPressed: _isTyping ? _sendText : _startVoiceRecording,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

