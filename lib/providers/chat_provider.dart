import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatProvider extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();

  List<UserModel> _contacts = [];
  final Map<String, List<ChatMessage>> _messages = {};
  bool _isWsConnected = false;
  bool _isLoadingContacts = false;
  String? _error;
  String? _currentUsername;

  List<UserModel> get contacts => _contacts;
  bool get isWsConnected => _isWsConnected;
  bool get isLoadingContacts => _isLoadingContacts;
  String? get error => _error;

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

  void connectWebSocket(String token, String username) {
    _currentUsername = username;
    _webSocketService.connect(
      token: token,
      username: username,
      onConnectionStatusChanged: (connected) {
        _isWsConnected = connected;
        notifyListeners();
      },
      onMessageReceived: (message) {
        _addMessage(message);
      },
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
      notifyListeners();
    } catch (e) {
      _isLoadingContacts = false;
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  void sendTextMessage({
    required String sender,
    required String recipient,
    required String content,
  }) {
    final msgId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final msg = ChatMessage(
      id: msgId,
      sender: sender,
      recipient: recipient,
      type: MessageType.TEXT,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _webSocketService.sendMessage(msg);
    _addMessage(msg);
  }

  Future<void> sendImageMessage({
    required String sender,
    required String recipient,
    required File file,
    required String token,
  }) async {
    try {
      final uploadRes = await ApiService.uploadFile(token, file);
      final fileUrl = uploadRes['fileUrl'] ?? '';
      final fileName = uploadRes['fileName'] ?? 'image.jpg';

      final msgId = 'img_${DateTime.now().microsecondsSinceEpoch}';
      final msg = ChatMessage(
        id: msgId,
        sender: sender,
        recipient: recipient,
        type: MessageType.IMAGE,
        fileUrl: fileUrl,
        fileName: fileName,
        content: 'Image attachment',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      _webSocketService.sendMessage(msg);
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
  }) async {
    try {
      final uploadRes = await ApiService.uploadFile(token, file);
      final fileUrl = uploadRes['fileUrl'] ?? '';
      final fileName = uploadRes['fileName'] ?? 'document';

      final msgId = 'file_${DateTime.now().microsecondsSinceEpoch}';
      final msg = ChatMessage(
        id: msgId,
        sender: sender,
        recipient: recipient,
        type: MessageType.FILE,
        fileUrl: fileUrl,
        fileName: fileName,
        content: 'File attachment',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      _webSocketService.sendMessage(msg);
      _addMessage(msg);
    } catch (e) {
      rethrow;
    }
  }

  void sendLocationMessage({
    required String sender,
    required String recipient,
    required double latitude,
    required double longitude,
  }) {
    final msgId = 'loc_${DateTime.now().microsecondsSinceEpoch}';
    final msg = ChatMessage(
      id: msgId,
      sender: sender,
      recipient: recipient,
      type: MessageType.LOCATION,
      latitude: latitude,
      longitude: longitude,
      content: 'Shared Location',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _webSocketService.sendMessage(msg);
    _addMessage(msg);
  }

  void _addMessage(ChatMessage msg) {
    final curUser = _currentUsername?.toLowerCase();
    String rawKey;

    if (curUser != null && curUser.isNotEmpty) {
      if (msg.sender.toLowerCase() == curUser) {
        rawKey = msg.recipient;
      } else {
        rawKey = msg.sender;
      }
    } else {
      rawKey = msg.sender;
    }

    if (rawKey.isEmpty) return;
    final lowerKey = rawKey.toLowerCase();

    if (!_messages.containsKey(lowerKey)) {
      _messages[lowerKey] = [];
    }

    final list = _messages[lowerKey]!;

    // Deduplicate by message ID or (sender + timestamp + content)
    bool isDuplicate = list.any((m) {
      if (m.id != null && msg.id != null && m.id == msg.id) return true;
      return m.sender == msg.sender &&
          m.timestamp == msg.timestamp &&
          m.content == msg.content;
    });

    if (!isDuplicate) {
      list.add(msg);
      _saveLocalMessages(lowerKey);
      notifyListeners();
    }
  }
}
