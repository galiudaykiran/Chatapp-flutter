import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/task_reminder_model.dart';
import '../widgets/notification_banner.dart';
import '../widgets/task_reminder_alert_dialog.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatProvider extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  Timer? _ephemeralTimer;

  ChatProvider() {
    _startEphemeralScanner();
  }

  @override
  void dispose() {
    _ephemeralTimer?.cancel();
    super.dispose();
  }

  void _startEphemeralScanner() {
    _ephemeralTimer?.cancel();
    _ephemeralTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      bool anyRemoved = false;

      _messages.forEach((key, list) {
        final originalCount = list.length;
        list.removeWhere((m) =>
            m.autoDeleteTimestamp != null &&
            m.autoDeleteTimestamp! > 0 &&
            now >= m.autoDeleteTimestamp!);
        if (list.length != originalCount) {
          anyRemoved = true;
          _saveLocalMessages(key);
        }
      });

      if (anyRemoved) {
        notifyListeners();
      }
    });
  }

  List<UserModel> _contacts = [];
  List<GroupModel> _groups = [];
  final Map<String, List<ChatMessage>> _messages = {};
  bool _isWsConnected = false;
  bool _isLoadingContacts = false;
  String? _error;
  String? _currentUsername;

  List<UserModel> get contacts => _contacts;
  List<GroupModel> get groups => _groups;
  bool get isWsConnected => _isWsConnected;
  bool get isLoadingContacts => _isLoadingContacts;
  String? get error => _error;
  String? get currentUsername => _currentUsername;

  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;

  void setActiveConversation(String? id) {
    _activeConversationId = id?.toLowerCase();
    if (_activeConversationId != null) {
      markMessagesAsRead(_activeConversationId!);
    }
  }

  ChatMessage? getLastMessageFor(String conversationId) {
    final lowerKey = conversationId.toLowerCase();
    final list = _messages[lowerKey];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  int getUnreadCountFor(String conversationId) {
    final lowerKey = conversationId.toLowerCase();
    final list = _messages[lowerKey];
    if (list == null || list.isEmpty) return 0;
    final currentLower = _currentUsername?.toLowerCase() ?? '';
    return list.where((m) {
      final isFromOther = m.sender.toLowerCase() != currentLower;
      final isUnread = !m.isRead && m.status != 'READ' && m.status != 'SEEN';
      return isFromOther && isUnread;
    }).length;
  }

  int getTotalUnreadCount() {
    int total = 0;
    final currentLower = _currentUsername?.toLowerCase() ?? '';
    for (final c in _contacts) {
      if (c.username.toLowerCase() != currentLower) {
        total += getUnreadCountFor(c.username);
      }
    }
    for (final g in _groups) {
      total += getUnreadCountFor(g.groupId);
    }
    return total;
  }

  void markMessagesAsRead(String conversationId) {
    final lowerKey = conversationId.toLowerCase();
    final list = _messages[lowerKey];
    if (list == null || list.isEmpty) return;
    final currentLower = _currentUsername?.toLowerCase() ?? '';
    bool changed = false;

    for (int i = 0; i < list.length; i++) {
      final m = list[i];
      if (m.sender.toLowerCase() != currentLower && (!m.isRead || m.status != 'READ')) {
        list[i] = m.copyWith(isRead: true, status: 'READ');
        _webSocketService.markAsRead(list[i]);
        changed = true;
      }
    }

    if (changed) {
      _saveLocalMessages(lowerKey);
      notifyListeners();
    }
  }

  List<UserModel> getSortedContacts() {
    final currentLower = _currentUsername?.toLowerCase() ?? '';
    final list = _contacts.where((u) => u.username.toLowerCase() != currentLower).toList();
    list.sort((a, b) {
      final lastA = getLastMessageFor(a.username);
      final lastB = getLastMessageFor(b.username);
      final tsA = lastA?.timestamp ?? 0;
      final tsB = lastB?.timestamp ?? 0;
      if (tsA != tsB) {
        return tsB.compareTo(tsA); // WhatsApp: newest conversation at top
      }
      if (a.status == 'ONLINE' && b.status != 'ONLINE') return -1;
      if (a.status != 'ONLINE' && b.status == 'ONLINE') return 1;
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });
    return list;
  }

  List<GroupModel> getSortedGroups() {
    final list = List<GroupModel>.from(_groups);
    list.sort((a, b) {
      final lastA = getLastMessageFor(a.groupId);
      final lastB = getLastMessageFor(b.groupId);
      final tsA = lastA?.timestamp ?? 0;
      final tsB = lastB?.timestamp ?? 0;
      if (tsA != tsB) {
        return tsB.compareTo(tsA); // WhatsApp: newest conversation at top
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  List<ChatMessage> getMessagesFor(String username) {
    final lowerKey = username.toLowerCase();
    if (!_messages.containsKey(lowerKey)) {
      _messages[lowerKey] = [];
      loadLocalMessages(lowerKey);
    }
    return _messages[lowerKey] ?? [];
  }

  Future<void> loadLocalMessages(String username) async {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;
    final lowerKey = username.toLowerCase();
    final storageKey = 'local_chats_${_currentUsername!.toLowerCase()}_$lowerKey';
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(jsonStr);
        final loaded = rawList.map((j) => ChatMessage.fromJson(j)).toList();
        _messages[lowerKey] = loaded;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLocalMessages(String conversationKey) async {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;
    final lowerKey = conversationKey.toLowerCase();
    final storageKey = 'local_chats_${_currentUsername!.toLowerCase()}_$lowerKey';
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages[lowerKey] ?? [];
      final jsonStr = jsonEncode(list.map((m) => m.toJson()).toList());
      await prefs.setString(storageKey, jsonStr);
    } catch (_) {}
  }

  Future<void> clearChat(String username) async {
    final lowerKey = username.toLowerCase();
    _messages[lowerKey] = [];
    if (_currentUsername != null && _currentUsername!.isNotEmpty) {
      final storageKey = 'local_chats_${_currentUsername!.toLowerCase()}_$lowerKey';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    }
    notifyListeners();
  }

  final List<ChatMessage> _pendingOfflineMessages = [];

  Future<void> initOfflineStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUsername ??= prefs.getString('stored_current_username');
      final cachedContactsJson = prefs.getString('cached_contacts');
      if (cachedContactsJson != null && cachedContactsJson.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(cachedContactsJson);
        _contacts = rawList.map((j) => UserModel.fromJson(j)).toList();
        for (var c in _contacts) {
          loadLocalMessages(c.username);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Function(Map<String, dynamic>)? _onCallReceived;
  Function(ChatMessage)? onNewMessageNotification;

  void setOnCallReceived(Function(Map<String, dynamic>) callback) {
    _onCallReceived = callback;
    _webSocketService.setOnCallReceived(callback);
  }

  void setOnNewMessageNotification(Function(ChatMessage) callback) {
    onNewMessageNotification = callback;
  }

  void connectWebSocket(String token, String username, {Function(Map<String, dynamic>)? onCallReceived}) {
    if (onCallReceived != null) {
      _onCallReceived = onCallReceived;
    }
    _currentUsername = username;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('stored_current_username', username);
    });

    _webSocketService.setOnTaskReminderReceived((payload) {
      TaskReminderAlertDialog.triggerAlert(payload);
    });

    syncAllMyTasks(token);
    _webSocketService.connect(
      token: token,
      username: username,
      onConnectionStatusChanged: (connected) {
        _isWsConnected = connected;
        if (connected && _pendingOfflineMessages.isNotEmpty) {
          final toSend = List<ChatMessage>.from(_pendingOfflineMessages);
          _pendingOfflineMessages.clear();
          for (var msg in toSend) {
            _webSocketService.sendMessage(msg);
          }
        }
        notifyListeners();
      },
      onMessageReceived: (message) {
        _addMessage(message);
      },
      onCallReceived: _onCallReceived,
    );
  }

  void disconnectWebSocket() {
    _webSocketService.disconnect();
    _isWsConnected = false;
    notifyListeners();
  }

  Future<void> fetchContacts(String token) async {
    _isLoadingContacts = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await ApiService.getUsers(token);
      _isLoadingContacts = false;

      // Cache contacts locally for offline access
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_contacts.map((c) => c.toJson()).toList());
      await prefs.setString('cached_contacts', jsonStr);

      for (var c in _contacts) {
        loadLocalMessages(c.username);
      }
      await fetchUserGroups(token);
      notifyListeners();
    } catch (e) {
      _isLoadingContacts = false;
      // Load offline cached contacts if network/backend fails
      await initOfflineStorage();
      _error = null; // Suppress hard error so user can view local offline chats seamlessly
      notifyListeners();
    }
  }

  Future<void> fetchUserGroups(String token) async {
    try {
      final list = await ApiService.getMyGroups(token);
      final rawGroups = list.map((j) => GroupModel.fromJson(j)).toList();
      
      // Display ONLY groups in which the current user is a member!
      if (_currentUsername != null && _currentUsername!.isNotEmpty) {
        final currentLower = _currentUsername!.toLowerCase();
        _groups = rawGroups.where((g) {
          return g.members.any((m) => m.toLowerCase() == currentLower);
        }).toList();
      } else {
        _groups = rawGroups;
      }

      for (var g in _groups) {
        _webSocketService.subscribeToGroupTopic(g.groupId, (msg) {
          _addMessage(msg);
        });
        loadLocalMessages(g.groupId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching groups: $e");
    }
  }

  Future<bool> leaveGroup(String groupId, String token) async {
    try {
      final success = await ApiService.leaveGroup(groupId, token);
      if (success) {
        _groups.removeWhere((g) => g.groupId == groupId);
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncAllMyTasks(String token) async {
    try {
      final list = await ApiService.fetchMyTasks(token);
      final tasks = list.map((j) => TaskReminderModel.fromJson(j)).toList();
      for (var task in tasks) {
        if (!task.isCompleted) {
          TaskReminderAlertDialog.scheduleLocalReminder(
            id: task.id,
            title: task.title,
            description: task.description,
            targetId: task.targetId,
            isGroup: task.isGroup,
            creatorUsername: task.creatorUsername,
            scheduledTimestamp: task.scheduledTimestamp,
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<List<TaskReminderModel>> fetchTasksForTarget(String targetId, String token) async {
    try {
      final list = await ApiService.fetchTasksForTarget(targetId, token);
      final tasks = list.map((j) => TaskReminderModel.fromJson(j)).toList();
      for (var t in tasks) {
        if (!t.isTriggered && !t.isCompleted) {
          TaskReminderAlertDialog.scheduleLocalReminder(
            id: t.id,
            title: t.title,
            description: t.description,
            targetId: t.targetId,
            isGroup: t.isGroup,
            creatorUsername: t.creatorUsername,
            scheduledTimestamp: t.scheduledTimestamp,
          );
        }
      }
      return tasks;
    } catch (_) {
      return [];
    }
  }

  Future<TaskReminderModel?> createTaskReminder({
    required String token,
    required String title,
    String? description,
    required String targetId,
    required bool isGroup,
    required int scheduledTimestamp,
  }) async {
    try {
      final json = await ApiService.createTaskReminder(
        token: token,
        title: title,
        description: description,
        targetId: targetId,
        isGroup: isGroup,
        scheduledTimestamp: scheduledTimestamp,
      );
      if (json != null) {
        final created = TaskReminderModel.fromJson(json);
        TaskReminderAlertDialog.scheduleLocalReminder(
          id: created.id,
          title: created.title,
          description: created.description,
          targetId: created.targetId,
          isGroup: created.isGroup,
          creatorUsername: created.creatorUsername,
          scheduledTimestamp: created.scheduledTimestamp,
        );
        return created;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleTaskCompleted(int taskId, String token) async {
    return await ApiService.toggleTaskCompleted(taskId, token);
  }

  Future<bool> deleteTask(int taskId, String token) async {
    return await ApiService.deleteTask(taskId, token);
  }

  Future<GroupModel?> createGroup({
    required String token,
    required String name,
    String? description,
    required List<String> members,
  }) async {
    try {
      final json = await ApiService.createGroup(
        token: token,
        name: name,
        description: description,
        members: members,
      );
      final newGroup = GroupModel.fromJson(json);
      _groups.add(newGroup);
      _webSocketService.subscribeToGroupTopic(newGroup.groupId, (msg) {
        _addMessage(msg);
      });
      notifyListeners();
      return newGroup;
    } catch (e) {
      debugPrint("Error creating group: $e");
      return null;
    }
  }

  void sendChatMessage(ChatMessage msg) {
    if (_isWsConnected) {
      _webSocketService.sendMessage(msg);
    } else {
      _pendingOfflineMessages.add(msg);
    }
    _addMessage(msg);
  }

  void markViewOnceOpened(ChatMessage msg) {
    final contact = msg.recipient.toLowerCase().startsWith('group_')
        ? msg.recipient
        : (msg.sender.toLowerCase() == _currentUsername?.toLowerCase() ? msg.recipient : msg.sender);
    final lowerKey = contact.toLowerCase();
    final list = _messages[lowerKey];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(isViewOnceOpened: true);
        _saveLocalMessages(lowerKey);
        notifyListeners();

        // Send VIEW_ONCE_OPENED update via WebSocket
        final openedNotice = list[idx].copyWith(
          type: MessageType.VIEW_ONCE_OPENED,
          isViewOnceOpened: true,
        );
        if (_isWsConnected) {
          _webSocketService.sendMessage(openedNotice);
        }
      }
    }
  }

  Future<String?> summarizeChatWithAi(String contactUsername, String token) async {
    final lowerKey = contactUsername.toLowerCase();
    final msgs = _messages[lowerKey] ?? [];
    final textList = msgs
        .where((m) => m.content != null && m.content!.isNotEmpty)
        .take(50)
        .map((m) => '${m.sender}: ${m.content}')
        .toList();

    return ApiService.summarizeChat(textList, token);
  }

  void sendTextMessage({
    required String sender,
    required String recipient,
    required String content,
    int? visibilitySeconds,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final msgId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final autoDelete = (visibilitySeconds != null && visibilitySeconds > 0)
        ? now + (visibilitySeconds * 1000)
        : null;
    final msg = ChatMessage(
      id: msgId,
      sender: sender,
      recipient: recipient,
      type: MessageType.TEXT,
      content: content,
      timestamp: now,
      visibilitySeconds: visibilitySeconds,
      autoDeleteTimestamp: autoDelete,
      replyToId: replyToId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    if (_isWsConnected) {
      _webSocketService.sendMessage(msg);
    } else {
      _pendingOfflineMessages.add(msg);
    }
    _addMessage(msg);
  }

  Future<void> sendImageMessage({
    required String sender,
    required String recipient,
    required File file,
    required String token,
    int? visibilitySeconds,
    bool isViewOnce = false,
  }) async {
    try {
      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      String fileUrl = '';

      if (token.isNotEmpty) {
        try {
          final response = await ApiService.uploadFile(token, file);
          if (response.containsKey('fileUrl') && response['fileUrl'] != null) {
            fileUrl = response['fileUrl'].toString();
          }
        } catch (uploadError) {
          debugPrint("Backend image upload error, using base64 fallback: $uploadError");
        }
      }

      if (fileUrl.isEmpty) {
        final bytes = await file.readAsBytes();
        final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
        final mimeType = (ext == 'png' || ext == 'webp' || ext == 'gif') ? 'image/$ext' : 'image/jpeg';
        final base64Str = base64Encode(bytes);
        fileUrl = 'data:$mimeType;base64,$base64Str';
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = 'img_${DateTime.now().microsecondsSinceEpoch}';
      final autoDelete = (visibilitySeconds != null && visibilitySeconds > 0)
          ? now + (visibilitySeconds * 1000)
          : null;
      final msg = ChatMessage(
        id: msgId,
        sender: sender,
        recipient: recipient,
        type: MessageType.IMAGE,
        fileUrl: fileUrl,
        fileName: fileName,
        content: isViewOnce ? 'View Once Photo' : 'Image attachment',
        timestamp: now,
        visibilitySeconds: visibilitySeconds,
        autoDeleteTimestamp: autoDelete,
        isViewOnce: isViewOnce,
      );

      if (_isWsConnected) {
        _webSocketService.sendMessage(msg);
      } else {
        _pendingOfflineMessages.add(msg);
      }
      _addMessage(msg);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendFileMessage({
    required String sender,
    required String recipient,
    required File file,
    required String token,
    int? visibilitySeconds,
  }) async {
    try {
      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      String fileUrl = '';

      if (token.isNotEmpty) {
        try {
          final response = await ApiService.uploadFile(token, file);
          if (response.containsKey('fileUrl') && response['fileUrl'] != null) {
            fileUrl = response['fileUrl'].toString();
          }
        } catch (uploadError) {
          debugPrint("Backend file upload error, using base64 fallback: $uploadError");
        }
      }

      if (fileUrl.isEmpty) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        fileUrl = 'data:application/octet-stream;base64,$base64Str';
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = 'file_${DateTime.now().microsecondsSinceEpoch}';
      final autoDelete = (visibilitySeconds != null && visibilitySeconds > 0)
          ? now + (visibilitySeconds * 1000)
          : null;
      final msg = ChatMessage(
        id: msgId,
        sender: sender,
        recipient: recipient,
        type: MessageType.FILE,
        fileUrl: fileUrl,
        fileName: fileName,
        content: fileName,
        timestamp: now,
        visibilitySeconds: visibilitySeconds,
        autoDeleteTimestamp: autoDelete,
      );

      if (_isWsConnected) {
        _webSocketService.sendMessage(msg);
      } else {
        _pendingOfflineMessages.add(msg);
      }
      _addMessage(msg);
    } catch (e) {
      rethrow;
    }
  }

  void sendAudioMessage({
    required String sender,
    required String recipient,
    required int durationSeconds,
    int? visibilitySeconds,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final msgId = 'audio_${DateTime.now().microsecondsSinceEpoch}';
    final autoDelete = (visibilitySeconds != null && visibilitySeconds > 0)
        ? now + (visibilitySeconds * 1000)
        : null;
    final msg = ChatMessage(
      id: msgId,
      sender: sender,
      recipient: recipient,
      type: MessageType.AUDIO,
      duration: durationSeconds,
      content: 'Voice Note ($durationSeconds s)',
      timestamp: now,
      visibilitySeconds: visibilitySeconds,
      autoDeleteTimestamp: autoDelete,
    );

    if (_isWsConnected) {
      _webSocketService.sendMessage(msg);
    } else {
      _pendingOfflineMessages.add(msg);
    }
    _addMessage(msg);
  }

  void toggleReaction(ChatMessage targetMsg, String emoji) {
    final curUser = _currentUsername?.toLowerCase();
    if (curUser == null) return;

    final key = _resolveConversationKey(targetMsg);
    final list = _messages[key];
    if (list == null) return;

    for (int i = 0; i < list.length; i++) {
      final msg = list[i];
      if ((msg.id != null && msg.id == targetMsg.id) ||
          (msg.timestamp == targetMsg.timestamp && msg.content == targetMsg.content)) {
        final newReaction = msg.reaction == emoji ? null : emoji;
        final updatedMsg = ChatMessage(
          id: msg.id,
          sender: msg.sender,
          recipient: msg.recipient,
          type: msg.type,
          content: msg.content,
          fileUrl: msg.fileUrl,
          fileName: msg.fileName,
          latitude: msg.latitude,
          longitude: msg.longitude,
          timestamp: msg.timestamp,
          isRead: msg.isRead,
          status: msg.status,
          reaction: newReaction,
          isStarred: msg.isStarred,
          duration: msg.duration,
        );
        list[i] = updatedMsg;
        _saveLocalMessages(key);
        notifyListeners();
        break;
      }
    }
  }

  void toggleStarred(ChatMessage targetMsg) {
    final curUser = _currentUsername?.toLowerCase();
    if (curUser == null) return;

    final key = _resolveConversationKey(targetMsg);
    final list = _messages[key];
    if (list == null) return;

    for (int i = 0; i < list.length; i++) {
      final msg = list[i];
      if ((msg.id != null && msg.id == targetMsg.id) ||
          (msg.timestamp == targetMsg.timestamp && msg.content == targetMsg.content)) {
        final updatedMsg = ChatMessage(
          id: msg.id,
          sender: msg.sender,
          recipient: msg.recipient,
          type: msg.type,
          content: msg.content,
          fileUrl: msg.fileUrl,
          fileName: msg.fileName,
          latitude: msg.latitude,
          longitude: msg.longitude,
          timestamp: msg.timestamp,
          isRead: msg.isRead,
          status: msg.status,
          reaction: msg.reaction,
          isStarred: !msg.isStarred,
          duration: msg.duration,
        );
        list[i] = updatedMsg;
        _saveLocalMessages(key);
        notifyListeners();
        break;
      }
    }
  }

  void sendLocationMessage({
    required String sender,
    required String recipient,
    required double latitude,
    required double longitude,
    int? visibilitySeconds,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final msgId = 'loc_${DateTime.now().microsecondsSinceEpoch}';
    final autoDelete = (visibilitySeconds != null && visibilitySeconds > 0)
        ? now + (visibilitySeconds * 1000)
        : null;
    final msg = ChatMessage(
      id: msgId,
      sender: sender,
      recipient: recipient,
      type: MessageType.LOCATION,
      latitude: latitude,
      longitude: longitude,
      content: 'Shared Location',
      timestamp: now,
      visibilitySeconds: visibilitySeconds,
      autoDeleteTimestamp: autoDelete,
    );

    if (_isWsConnected) {
      _webSocketService.sendMessage(msg);
    } else {
      _pendingOfflineMessages.add(msg);
    }
    _addMessage(msg);
  }



  final Map<String, bool> _typingUsers = {};

  bool isUserTyping(String username) => _typingUsers[username.toLowerCase()] ?? false;

  void sendTypingStatus(String recipient, bool isTyping) {
    if (_currentUsername != null && _currentUsername!.isNotEmpty) {
      _webSocketService.sendTypingStatus(_currentUsername!, recipient, isTyping);
    }
  }

  void editMessage(ChatMessage targetMsg, String newContent) {
    final curUser = _currentUsername?.toLowerCase();
    if (curUser == null) return;

    final key = _resolveConversationKey(targetMsg);
    final list = _messages[key];
    if (list == null) return;

    for (int i = 0; i < list.length; i++) {
      final msg = list[i];
      if ((msg.id != null && msg.id == targetMsg.id) ||
          (msg.timestamp == targetMsg.timestamp && msg.content == targetMsg.content)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final editedMsg = ChatMessage(
          id: msg.id,
          sender: msg.sender,
          recipient: msg.recipient,
          type: MessageType.EDIT,
          content: newContent,
          fileUrl: msg.fileUrl,
          fileName: msg.fileName,
          latitude: msg.latitude,
          longitude: msg.longitude,
          timestamp: msg.timestamp,
          isRead: msg.isRead,
          status: msg.status,
          reaction: msg.reaction,
          isStarred: msg.isStarred,
          duration: msg.duration,
          edited: true,
          deleted: false,
          editedTimestamp: now,
          visibilitySeconds: msg.visibilitySeconds,
          autoDeleteTimestamp: msg.autoDeleteTimestamp,
        );
        list[i] = editedMsg;
        _webSocketService.sendMessage(editedMsg);
        _saveLocalMessages(key);
        notifyListeners();
        break;
      }
    }
  }

  void deleteForMe(ChatMessage targetMsg) {
    final curUser = _currentUsername?.toLowerCase();
    if (curUser == null) return;

    final key = _resolveConversationKey(targetMsg);
    final list = _messages[key];
    if (list == null) return;

    list.removeWhere((m) =>
        (m.id != null && m.id == targetMsg.id) ||
        (m.timestamp == targetMsg.timestamp && m.content == targetMsg.content));

    _saveLocalMessages(key);
    notifyListeners();
  }

  void deleteMultipleForMe(String contactUsername, List<String> targetIds) {
    final lowerKey = contactUsername.toLowerCase();
    final list = _messages[lowerKey];
    if (list == null) return;

    list.removeWhere((m) =>
        targetIds.contains(m.id) || targetIds.contains('${m.timestamp}'));

    _saveLocalMessages(lowerKey);
    notifyListeners();
  }

  void deleteForEveryone(ChatMessage targetMsg) {
    final curUser = _currentUsername?.toLowerCase();
    if (curUser == null) return;

    final key = _resolveConversationKey(targetMsg);
    final list = _messages[key];
    if (list == null) return;

    for (int i = 0; i < list.length; i++) {
      final msg = list[i];
      if ((msg.id != null && msg.id == targetMsg.id) ||
          (msg.timestamp == targetMsg.timestamp && msg.content == targetMsg.content)) {
        final deletedMsg = ChatMessage(
          id: msg.id,
          sender: msg.sender,
          recipient: msg.recipient,
          type: MessageType.DELETE,
          content: 'This message was deleted',
          timestamp: msg.timestamp,
          deleted: true,
          deleteType: 'DELETE_FOR_EVERYONE',
        );
        list[i] = deletedMsg;
        _webSocketService.sendMessage(deletedMsg);
        _saveLocalMessages(key);
        notifyListeners();
        break;
      }
    }
  }

  void deleteMultipleForEveryone(String contactUsername, List<ChatMessage> targets) {
    for (var m in targets) {
      deleteForEveryone(m);
    }
  }

  ChatMessage? _incomingCallOffer;
  ChatMessage? get incomingCallOffer => _incomingCallOffer;

  bool _isInActiveCall = false;
  bool get isInActiveCall => _isInActiveCall;

  String? _activeCallPeer;
  String? get activeCallPeer => _activeCallPeer;

  String? _activeCallMode;
  String? get activeCallMode => _activeCallMode;

  void sendCallOffer(String recipient, bool isVideo) {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;
    _activeCallPeer = recipient;
    _activeCallMode = isVideo ? 'VIDEO' : 'VOICE';
    _webSocketService.sendCallSignal(_currentUsername!, recipient, MessageType.CALL_OFFER, _activeCallMode!);
    notifyListeners();
  }

  void acceptCall(String caller) {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;
    _incomingCallOffer = null;
    _isInActiveCall = true;
    _activeCallPeer = caller;
    _webSocketService.sendCallSignal(_currentUsername!, caller, MessageType.CALL_ACCEPT, _activeCallMode ?? 'VOICE');
    notifyListeners();
  }

  void declineCall(String caller) {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;
    _incomingCallOffer = null;
    _webSocketService.sendCallSignal(_currentUsername!, caller, MessageType.CALL_DECLINE, 'DECLINE');
    notifyListeners();
  }

  void endCall(String peer) {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;
    _incomingCallOffer = null;
    _isInActiveCall = false;
    _activeCallPeer = null;
    _activeCallMode = null;
    _webSocketService.sendCallSignal(_currentUsername!, peer, MessageType.CALL_END, 'END');
    notifyListeners();
  }

  String _resolveConversationKey(ChatMessage msg) {
    if (msg.recipient.toLowerCase().startsWith('group_')) {
      return msg.recipient.toLowerCase();
    }
    final curUser = _currentUsername?.toLowerCase();
    if (curUser != null && curUser.isNotEmpty && msg.sender.toLowerCase() == curUser) {
      return msg.recipient.toLowerCase();
    }
    return msg.sender.toLowerCase();
  }

  void _addMessage(ChatMessage msg) {
    if (msg.type == MessageType.CALL_OFFER) {
      if (msg.recipient.toLowerCase() == _currentUsername?.toLowerCase()) {
        _incomingCallOffer = msg;
        _activeCallPeer = msg.sender;
        _activeCallMode = msg.content;
        notifyListeners();
      }
      return;
    }
    if (msg.type == MessageType.CALL_ACCEPT) {
      if (msg.recipient.toLowerCase() == _currentUsername?.toLowerCase()) {
        _isInActiveCall = true;
        notifyListeners();
      }
      return;
    }
    if (msg.type == MessageType.CALL_DECLINE || msg.type == MessageType.CALL_END) {
      _incomingCallOffer = null;
      _isInActiveCall = false;
      _activeCallPeer = null;
      _activeCallMode = null;
      notifyListeners();
      return;
    }

    if (msg.type == MessageType.TYPING) {
      _typingUsers[msg.sender.toLowerCase()] = msg.content == 'TYPING_START';
      notifyListeners();
      return;
    }
    // Handle real-time user status changes from WebSocket JOIN / LEAVE events
    if (msg.type == MessageType.JOIN || msg.type == MessageType.LEAVE) {
      final senderUsername = msg.sender.toLowerCase();
      final newStatus = msg.type == MessageType.JOIN ? 'ONLINE' : 'OFFLINE';
      
      bool statusChanged = false;
      for (int i = 0; i < _contacts.length; i++) {
        if (_contacts[i].username.toLowerCase() == senderUsername) {
          if (_contacts[i].status != newStatus) {
            _contacts[i] = UserModel(
              id: _contacts[i].id,
              username: _contacts[i].username,
              email: _contacts[i].email,
              mobileNumber: _contacts[i].mobileNumber,
              profileImage: _contacts[i].profileImage,
              status: newStatus,
            );
            statusChanged = true;
          }
          break;
        }
      }
      if (statusChanged) {
        notifyListeners();
      }
      return;
    }

    final lowerKey = _resolveConversationKey(msg);
    if (lowerKey.isEmpty) return;

    if (!_messages.containsKey(lowerKey)) {
      _messages[lowerKey] = [];
    }

    final list = _messages[lowerKey]!;

    // Check if this is a READ receipt update for an existing sent message
    if (msg.status == 'READ' || msg.isRead) {
      for (int i = 0; i < list.length; i++) {
        final existing = list[i];
        if ((msg.id != null && existing.id == msg.id) ||
            (existing.timestamp == msg.timestamp && existing.content == msg.content)) {
          list[i] = ChatMessage(
            id: existing.id,
            sender: existing.sender,
            recipient: existing.recipient,
            type: existing.type,
            content: existing.content,
            fileUrl: existing.fileUrl,
            fileName: existing.fileName,
            latitude: existing.latitude,
            longitude: existing.longitude,
            timestamp: existing.timestamp,
            isRead: true,
            status: 'READ',
          );
          _saveLocalMessages(lowerKey);
          notifyListeners();
          return;
        }
      }
    }

    // Handle EDIT updates from remote
    if (msg.type == MessageType.EDIT || msg.edited) {
      for (int i = 0; i < list.length; i++) {
        final existing = list[i];
        if ((msg.id != null && existing.id == msg.id) ||
            (existing.timestamp == msg.timestamp)) {
          list[i] = ChatMessage(
            id: existing.id,
            sender: existing.sender,
            recipient: existing.recipient,
            type: existing.type,
            content: msg.content,
            fileUrl: existing.fileUrl,
            fileName: existing.fileName,
            latitude: existing.latitude,
            longitude: existing.longitude,
            timestamp: existing.timestamp,
            isRead: existing.isRead,
            status: existing.status,
            reaction: existing.reaction,
            isStarred: existing.isStarred,
            duration: existing.duration,
            edited: true,
            deleted: false,
            editedTimestamp: msg.editedTimestamp ?? DateTime.now().millisecondsSinceEpoch,
            visibilitySeconds: existing.visibilitySeconds,
            autoDeleteTimestamp: existing.autoDeleteTimestamp,
          );
          _saveLocalMessages(lowerKey);
          notifyListeners();
          return;
        }
      }
    }

    // Handle DELETE updates from remote
    if (msg.type == MessageType.DELETE || msg.deleted) {
      for (int i = 0; i < list.length; i++) {
        final existing = list[i];
        if ((msg.id != null && existing.id == msg.id) ||
            (existing.timestamp == msg.timestamp)) {
          list[i] = ChatMessage(
            id: existing.id,
            sender: existing.sender,
            recipient: existing.recipient,
            type: MessageType.DELETE,
            content: 'This message was deleted',
            fileUrl: null,
            fileName: null,
            latitude: null,
            longitude: null,
            timestamp: existing.timestamp,
            isRead: existing.isRead,
            status: existing.status,
            reaction: null,
            isStarred: false,
            duration: null,
            edited: existing.edited,
            deleted: true,
            deleteType: 'DELETE_FOR_EVERYONE',
          );
          _saveLocalMessages(lowerKey);
          notifyListeners();
          return;
        }
      }
    }

    // Deduplicate by message ID or (sender + timestamp + content)
    bool isDuplicate = list.any((m) {
      if (m.id != null && msg.id != null && m.id == msg.id) return true;
      return m.sender == msg.sender &&
          m.timestamp == msg.timestamp &&
          m.content == msg.content;
    });

    if (!isDuplicate) {
      if (msg.sender.toLowerCase() != _currentUsername?.toLowerCase()) {
        if (_activeConversationId != null && _activeConversationId == lowerKey) {
          msg = msg.copyWith(isRead: true, status: 'READ');
          _webSocketService.markAsRead(msg);
        } else {
          msg = msg.copyWith(isRead: false, status: 'DELIVERED');
        }
      }
      list.add(msg);
      _saveLocalMessages(lowerKey);
      if (msg.sender.toLowerCase() != _currentUsername?.toLowerCase()) {
        if (onNewMessageNotification != null) {
          onNewMessageNotification!.call(msg);
        } else {
          try {
            FlutterRingtonePlayer().playNotification();
            HapticFeedback.mediumImpact();
          } catch (_) {}
          NotificationBanner.show(
            title: msg.recipient.startsWith('group_') ? 'Group Message (${msg.sender})' : msg.sender,
            body: msg.content ?? 'New message',
            senderUsername: msg.recipient.startsWith('group_') ? msg.recipient : msg.sender,
            currentUsername: _currentUsername ?? '',
          );
        }
      }
      notifyListeners();
    }
  }
}
