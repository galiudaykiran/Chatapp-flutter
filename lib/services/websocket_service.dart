import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../config/api_config.dart';
import '../models/chat_message.dart';

class WebSocketService {
  StompClient? _stompClient;

  bool get isConnected => _stompClient != null && _stompClient!.isActive;

  void connect({
    required String token,
    required String username,
    required Function(ChatMessage) onMessageReceived,
    required Function(bool) onConnectionStatusChanged,
  }) {
    disconnect();

    _stompClient = StompClient(
      config: StompConfig(
        url: ApiConfig.wsUrl,
        onConnect: (StompFrame frame) {
          onConnectionStatusChanged(true);

          // Subscribe to user private queue
          _stompClient?.subscribe(
            destination: '/user/queue/messages',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                try {
                  final Map<String, dynamic> json = jsonDecode(frame.body!);
                  onMessageReceived(ChatMessage.fromJson(json));
                } catch (_) {}
              }
            },
          );
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

  void sendMessage(ChatMessage message) {
    if (_stompClient != null && _stompClient!.isActive) {
      _stompClient?.send(
        destination: '/app/chat.sendMessage',
        body: jsonEncode(message.toJson()),
      );
    }
  }

  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
  }
}
