import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/call_model.dart';
import '../services/agora_call_service.dart';

enum CallState {
  idle,
  ringingOutgoing,
  ringingIncoming,
  connected,
  ended,
  rejected,
  cancelled,
  failed,
}

class CallProvider extends ChangeNotifier {
  final AgoraCallService _agoraService = AgoraCallService();

  CallModel? _currentCall;
  CallState _state = CallState.idle;
  bool _remoteUserJoined = false;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _ringtoneTimer;
  String? _errorMessage;

  CallModel? get currentCall => _currentCall;
  CallState get state => _state;
  bool get remoteUserJoined => _remoteUserJoined;
  int get callDurationSeconds => _callDurationSeconds;
  bool get isMuted => _agoraService.isMuted;
  bool get isSpeaker => _agoraService.isSpeakerPhone;
  String? get errorMessage => _errorMessage;

  CallProvider() {
    _setupAgoraCallbacks();
  }

  void _startRingtoneLoop({required bool isIncoming}) {
    _stopRingtoneLoop();
    _ringtoneTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_state == CallState.ringingIncoming) {
        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.click);
      } else if (_state == CallState.ringingOutgoing) {
        HapticFeedback.selectionClick();
      } else {
        _stopRingtoneLoop();
      }
    });
  }

  void _stopRingtoneLoop() {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
  }

  void _setupAgoraCallbacks() {
    _agoraService.onJoinedSuccessCallback = () {
      debugPrint("CALL_CONNECTED: Local user joined Agora channel");
      notifyListeners();
    };

    _agoraService.onUserJoinedCallback = (uid) {
      debugPrint("REMOTE_USER_JOINED: Remote user $uid joined channel");
      _stopRingtoneLoop();
      HapticFeedback.mediumImpact();
      _remoteUserJoined = true;
      _state = CallState.connected;
      _startDurationTimer();
      notifyListeners();
    };

    _agoraService.onUserOfflineCallback = (uid) {
      debugPrint("REMOTE_USER_OFFLINE: Remote user $uid left");
      endCall(getAuthToken: () async => null);
    };

    _agoraService.onErrorCallback = (err) {
      _errorMessage = err;
      notifyListeners();
    };
  }

  // Called when user presses Voice Call button
  Future<bool> startCall({
    required int receiverId,
    required String receiverName,
    String? receiverProfileImage,
    required Future<String?> Function() getAuthToken,
  }) async {
    _clearState();
    _state = CallState.ringingOutgoing;
    _startRingtoneLoop(isIncoming: false);
    notifyListeners();

    try {
      final token = await getAuthToken();
      if (token == null) {
        _setError("Authentication failed");
        return false;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.startCallUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiverId': receiverId,
          'callType': 'VOICE',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentCall = CallModel.fromJson(data);
        debugPrint("CALL_STARTED: Call initiated with ID: ${_currentCall!.callId}");

        // Initialize Agora and join channel as caller
        if (_currentCall!.token != null && _currentCall!.uid != null) {
          await _agoraService.initEngine(_currentCall!.appId);
          await _agoraService.joinChannel(
            token: _currentCall!.token!,
            channelName: _currentCall!.channelName,
            uid: _currentCall!.uid!,
          );
        }

        _startRingingTimeout(getAuthToken);
        notifyListeners();
        return true;
      } else {
        String msg = 'Unable to start call (Status ${response.statusCode})';
        try {
          if (response.body.trim().isNotEmpty) {
            final errJson = jsonDecode(response.body);
            if (errJson is Map && errJson.containsKey('message')) {
              msg = errJson['message'].toString();
            }
          }
        } catch (_) {}
        _setError(msg);
        return false;
      }
    } catch (e) {
      debugPrint("Error starting call: $e");
      _setError("Failed to start call: $e");
      return false;
    }
  }

  // Handle incoming call notification (FCM / WebSocket)
  void handleIncomingCall(Map<String, dynamic> data) {
    if (_state != CallState.idle) {
      debugPrint("Ignoring incoming call notification: App already in a call state ($_state)");
      return;
    }

    _currentCall = CallModel(
      callId: data['callId']?.toString() ?? '',
      appId: '3a496a15c508417e971ffa6f75ba7c7b',
      channelName: data['channelName']?.toString() ?? '',
      status: 'RINGING',
      callerId: int.tryParse(data['callerId']?.toString() ?? '0') ?? 0,
      callerName: data['callerName']?.toString() ?? 'Incoming Call',
      callerProfileImage: data['callerProfileImage']?.toString(),
      receiverId: 0,
      receiverName: '',
      callType: data['callType']?.toString() ?? 'VOICE',
    );

    _state = CallState.ringingIncoming;
    _startRingtoneLoop(isIncoming: true);
    debugPrint("INCOMING_CALL_SHOWN: Incoming call from ${_currentCall!.callerName}");
    notifyListeners();
  }

  // Accept Call
  Future<bool> acceptCall({required Future<String?> Function() getAuthToken}) async {
    if (_currentCall == null) return false;
    _stopRingingTimeout();

    try {
      final token = await getAuthToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.acceptCallUrl(_currentCall!.callId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentCall = CallModel.fromJson(data);
        _state = CallState.connected;
        _remoteUserJoined = true;
        _startDurationTimer();
        debugPrint("CALL_ACCEPTED: Receiver accepting call ${_currentCall!.callId}");

        if (_currentCall!.token != null && _currentCall!.uid != null) {
          await _agoraService.initEngine(_currentCall!.appId);
          await _agoraService.joinChannel(
            token: _currentCall!.token!,
            channelName: _currentCall!.channelName,
            uid: _currentCall!.uid!,
          );
        }

        notifyListeners();
        return true;
      } else {
        _setError("Unable to accept call");
        return false;
      }
    } catch (e) {
      _setError("Error accepting call: $e");
      return false;
    }
  }

  // Reject Call
  Future<void> rejectCall({required Future<String?> Function() getAuthToken}) async {
    if (_currentCall == null) return;
    _stopRingingTimeout();
    final callId = _currentCall!.callId;

    _state = CallState.rejected;
    notifyListeners();

    try {
      final token = await getAuthToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.rejectCallUrl(callId)),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (e) {
      debugPrint("Error sending reject call API: $e");
    } finally {
      _resetAfterDelay();
    }
  }

  // Cancel Outgoing Call
  Future<void> cancelCall({required Future<String?> Function() getAuthToken}) async {
    if (_currentCall == null) return;
    _stopRingingTimeout();
    final callId = _currentCall!.callId;

    _state = CallState.cancelled;
    notifyListeners();

    try {
      final token = await getAuthToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.cancelCallUrl(callId)),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (e) {
      debugPrint("Error sending cancel call API: $e");
    } finally {
      await _agoraService.leaveChannel();
      _resetAfterDelay();
    }
  }

  // End Call
  Future<void> endCall({required Future<String?> Function() getAuthToken}) async {
    if (_currentCall == null && _state == CallState.idle) return;
    _stopRingingTimeout();
    _stopDurationTimer();

    final callId = _currentCall?.callId;
    _state = CallState.ended;
    notifyListeners();

    try {
      await _agoraService.leaveChannel();
      await _agoraService.dispose();

      if (callId != null) {
        final token = await getAuthToken();
        if (token != null) {
          await http.post(
            Uri.parse(ApiConfig.endCallUrl(callId)),
            headers: {'Authorization': 'Bearer $token'},
          );
        }
      }
    } catch (e) {
      debugPrint("Error ending call: $e");
    } finally {
      _resetAfterDelay();
    }
  }

  // Remote updates via WebSocket signal
  void updateCallFromRemote(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    debugPrint("WEBSOCKET_CALL_UPDATE: Remote call status update: $status");

    if (status == 'ACCEPTED') {
      _state = CallState.connected;
      _remoteUserJoined = true;
      _startDurationTimer();
      notifyListeners();
    } else if (status == 'REJECTED') {
      _state = CallState.rejected;
      _stopRingingTimeout();
      _agoraService.leaveChannel();
      notifyListeners();
      _resetAfterDelay();
    } else if (status == 'CANCELLED') {
      _state = CallState.cancelled;
      _stopRingingTimeout();
      _agoraService.leaveChannel();
      notifyListeners();
      _resetAfterDelay();
    } else if (status == 'ENDED') {
      _state = CallState.ended;
      _stopDurationTimer();
      _agoraService.leaveChannel();
      _agoraService.dispose();
      notifyListeners();
      _resetAfterDelay();
    }
  }

  Future<void> toggleMute() async {
    await _agoraService.toggleMute();
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    await _agoraService.toggleSpeakerphone();
    notifyListeners();
  }

  void _startDurationTimer() {
    _stopDurationTimer();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _startRingingTimeout(Future<String?> Function() getAuthToken) {
    _stopRingingTimeout();
    _ringingTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_state == CallState.ringingOutgoing) {
        debugPrint("Call ringing timed out (no answer)");
        cancelCall(getAuthToken: getAuthToken);
      }
    });
  }

  void _stopRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _state = CallState.failed;
    notifyListeners();
    _resetAfterDelay();
  }

  void clearCallState() {
    _clearState();
    notifyListeners();
  }

  void _clearState() {
    _stopRingtoneLoop();
    _stopDurationTimer();
    _stopRingingTimeout();
    _currentCall = null;
    _state = CallState.idle;
    _remoteUserJoined = false;
    _callDurationSeconds = 0;
    _errorMessage = null;
  }

  void _resetAfterDelay() {
    _ringingTimeoutTimer?.cancel();
    Timer(const Duration(milliseconds: 1500), () {
      if (_state == CallState.cancelled ||
          _state == CallState.ended ||
          _state == CallState.rejected ||
          _state == CallState.failed) {
        _clearState();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _stopRingingTimeout();
    _agoraService.dispose();
    super.dispose();
  }
}
