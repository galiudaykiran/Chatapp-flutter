import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../config/api_config.dart';
import '../models/chat_message.dart';

class WebSocketService {
  StompClient? _stompClient;
  Function(Map<String, dynamic>)? _onCallReceived;
  Function(Map<String, dynamic>)? _onTaskReminderReceived;

  bool get isConnected => _stompClient != null && _stompClient!.isActive;

  void setOnCallReceived(Function(Map<String, dynamic>)? callback) {
    if (callback != null) {
      _onCallReceived = callback;
    }
  }

  final Map<String, Function(ChatMessage)> _groupSubscriptions = {};

  void setOnTaskReminderReceived(Function(Map<String, dynamic>)? callback) {
    if (callback != null) {
      _onTaskReminderReceived = callback;
    }
  }

  void connect({
    required String token,
    required String username,
    required Function(ChatMessage) onMessageReceived,
    required Function(bool) onConnectionStatusChanged,
    Function(Map<String, dynamic>)? onCallReceived,
  }) {
    if (onCallReceived != null) {
      _onCallReceived = onCallReceived;
    }

    disconnect();

    _stompClient = StompClient(
      config: StompConfig(
        url: ApiConfig.wsUrl,
        onConnect: (StompFrame frame) {
          onConnectionStatusChanged(true);

          // Register user socket session
          _stompClient?.send(
            destination: '/app/chat.addUser',
            body: jsonEncode({
              'sender': username,
              'type': 'JOIN',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          );

          // Subscribe to user private message queue
          _stompClient?.subscribe(
            destination: '/user/queue/messages',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                try {
                  final Map<String, dynamic> json = jsonDecode(frame.body!);
                  final type = json['type']?.toString();
                  if ((type == 'TASK_REMINDER_ALERT' || type == 'TASK_REMINDER_CREATED') && _onTaskReminderReceived != null) {
                    _onTaskReminderReceived!(json);
                  } else {
                    onMessageReceived(ChatMessage.fromJson(json));
                  }
                } catch (_) {}
              }
            },
          );

          // Subscribe to user private call queue
          _stompClient?.subscribe(
            destination: '/user/queue/calls',
            callback: (StompFrame frame) {
              if (frame.body != null && _onCallReceived != null) {
                try {
                  final Map<String, dynamic> json = jsonDecode(frame.body!);
                  _onCallReceived!(json);
                } catch (_) {}
              }
            },
          );

          // Subscribe to public topic & task reminders
          _stompClient?.subscribe(
            destination: '/topic/messages',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                try {
                  final Map<String, dynamic> json = jsonDecode(frame.body!);
                  final type = json['type']?.toString();
                  if ((type == 'TASK_REMINDER_ALERT' || type == 'TASK_REMINDER_CREATED') && _onTaskReminderReceived != null) {
                    _onTaskReminderReceived!(json);
                  } else {
                    onMessageReceived(ChatMessage.fromJson(json));
                  }
                } catch (_) {}
              }
            },
          );

          // Subscribe to public status updates (JOIN/LEAVE events)
          _stompClient?.subscribe(
            destination: '/topic/public',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                try {
                  final Map<String, dynamic> json = jsonDecode(frame.body!);
                  onMessageReceived(ChatMessage.fromJson(json));
                } catch (_) {}
              }
            },
          );

          // Automatically subscribe / re-subscribe to all registered group topics
          _groupSubscriptions.forEach((groupId, groupMsgCallback) {
            _stompClient?.subscribe(
              destination: '/topic/group/$groupId',
              callback: (StompFrame frame) {
                if (frame.body != null) {
                  try {
                    final Map<String, dynamic> json = jsonDecode(frame.body!);
                    final type = json['type']?.toString();
                    if ((type == 'TASK_REMINDER_ALERT' || type == 'TASK_REMINDER_CREATED') && _onTaskReminderReceived != null) {
                      _onTaskReminderReceived!(json);
                    } else {
                      groupMsgCallback(ChatMessage.fromJson(json));
                    }
                  } catch (_) {}
                }
              },
            );
          });
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onDisconnect: (frame) => onConnectionStatusChanged(false),
        onWebSocketError: (error) => onConnectionStatusChanged(false),
        onStompError: (frame) => onConnectionStatusChanged(false),
      ),
    );

    _stompClient?.activate();
  }

  void subscribeToGroupTopic(String groupId, Function(ChatMessage) onMessageReceived) {
    _groupSubscriptions[groupId] = onMessageReceived;
    if (_stompClient != null && _stompClient!.isActive) {
      final destination = '/topic/group/$groupId';
      _stompClient?.subscribe(
        destination: destination,
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final Map<String, dynamic> json = jsonDecode(frame.body!);
              final type = json['type']?.toString();
              if ((type == 'TASK_REMINDER_ALERT' || type == 'TASK_REMINDER_CREATED') && _onTaskReminderReceived != null) {
                _onTaskReminderReceived!(json);
              } else {
                onMessageReceived(ChatMessage.fromJson(json));
              }
            } catch (_) {}
          }
        },
      );
    }
  }

  void sendMessage(ChatMessage message) {
    if (_stompClient != null && _stompClient!.isActive) {
      _stompClient?.send(
        destination: '/app/chat.sendMessage',
        body: jsonEncode(message.toJson()),
      );
    }
  }

  void markAsRead(ChatMessage message) {
    if (_stompClient != null && _stompClient!.isActive) {
      _stompClient?.send(
        destination: '/app/chat.markAsRead',
        body: jsonEncode(message.toJson()),
      );
    }
  }

  void sendTypingStatus(String sender, String recipient, bool isTyping) {
    if (_stompClient != null && _stompClient!.isActive) {
      _stompClient?.send(
        destination: '/app/chat.typing',
        body: jsonEncode({
          'sender': sender,
          'recipient': recipient,
          'type': 'TYPING',
          'content': isTyping ? 'TYPING_START' : 'TYPING_STOP',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
  }

  void sendCallSignal(String sender, String recipient, MessageType callType, String callMode) {
    if (_stompClient != null && _stompClient!.isActive) {
      _stompClient?.send(
        destination: '/app/chat.sendMessage',
        body: jsonEncode({
          'sender': sender,
          'recipient': recipient,
          'type': callType.name,
          'content': callMode,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
  }
}
