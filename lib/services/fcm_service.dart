import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("FCM_BACKGROUND: Received FCM message in background/terminated: ${message.data}");
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Function(Map<String, dynamic> data)? onIncomingCallReceived;

  Future<void> initFirebase({required Future<String?> Function() getAuthToken}) async {
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('FCM permission status: ${settings.authorizationStatus}');

      _fcmToken = await messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await sendTokenToBackend(_fcmToken!, getAuthToken);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await sendTokenToBackend(newToken, getAuthToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("FCM_RECEIVED: Foreground FCM message received: ${message.data}");
        if (message.data['type'] == 'INCOMING_CALL') {
          if (onIncomingCallReceived != null) {
            onIncomingCallReceived!(message.data);
          }
        }
      });

      // Background app click listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("FCM_OPENED_APP: FCM message opened app: ${message.data}");
        if (message.data['type'] == 'INCOMING_CALL') {
          if (onIncomingCallReceived != null) {
            onIncomingCallReceived!(message.data);
          }
        }
      });

      // Terminated app initial message
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && initialMessage.data['type'] == 'INCOMING_CALL') {
        debugPrint("FCM_INITIAL_MSG: Terminated app opened with FCM message: ${initialMessage.data}");
        if (onIncomingCallReceived != null) {
          onIncomingCallReceived!(initialMessage.data);
        }
      }
    } catch (e) {
      debugPrint("FCM initialization error (will fallback to WebSocket): $e");
    }
  }

  Future<void> sendTokenToBackend(String token, Future<String?> Function() getAuthToken) async {
    try {
      final authToken = await getAuthToken();
      if (authToken == null || authToken.isEmpty) return;

      final response = await http.post(
        Uri.parse(ApiConfig.fcmTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        debugPrint("FCM_TOKEN_SENT: FCM token updated on backend successfully");
      } else {
        debugPrint("FCM token update failed with status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error sending FCM token to backend: $e");
    }
  }
}
