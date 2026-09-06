import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraCallService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerPhone = true;

  Function(int uid)? onUserJoinedCallback;
  Function(int uid)? onUserOfflineCallback;
  Function()? onJoinedSuccessCallback;
  Function(String error)? onErrorCallback;

  bool get isMuted => _isMuted;
  bool get isSpeakerPhone => _isSpeakerPhone;

  Future<void> initEngine(String appId) async {
    if (_isInitialized && _engine != null) return;

    // Request microphone permission
    final micPermission = await Permission.microphone.request();
    if (micPermission.isDenied || micPermission.isPermanentlyDenied) {
      if (onErrorCallback != null) {
        onErrorCallback!('Microphone permission is required for voice calls.');
      }
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("AGORA_JOINED: Channel ${connection.channelId}, local uid ${connection.localUid}");
            if (onJoinedSuccessCallback != null) {
              onJoinedSuccessCallback!();
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("REMOTE_USER_JOINED: Remote uid $remoteUid");
            if (onUserJoinedCallback != null) {
              onUserJoinedCallback!(remoteUid);
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("REMOTE_USER_OFFLINE: Remote uid $remoteUid left. Reason: $reason");
            if (onUserOfflineCallback != null) {
              onUserOfflineCallback!(remoteUid);
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("AGORA_ERROR_EVENT: $err - $msg");
            if ((err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) &&
                _lastChannelName != null && _lastUid != null) {
              debugPrint("Token error ($err) detected. Automatically retrying join in App ID testing mode...");
              _engine?.joinChannel(
                token: "",
                channelId: _lastChannelName!,
                uid: _lastUid!,
                options: const ChannelMediaOptions(
                  clientRoleType: ClientRoleType.clientRoleBroadcaster,
                  channelProfile: ChannelProfileType.channelProfileCommunication,
                  publishMicrophoneTrack: true,
                  autoSubscribeAudio: true,
                ),
              );
              return;
            }
            if (onErrorCallback != null) {
              onErrorCallback!("Agora error $err: $msg");
            }
          },
        ),
      );

      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.setEnableSpeakerphone(true);

      _isInitialized = true;
      debugPrint("AGORA_INITIALIZED: Agora RTC Engine initialized successfully");
    } catch (e) {
      debugPrint("AGORA_INIT_FAILED: $e");
      if (onErrorCallback != null) {
        onErrorCallback!("Failed to initialize Agora engine: $e");
      }
    }
  }

  String? _lastChannelName;
  int? _lastUid;

  Future<void> joinChannel({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    if (_engine == null || !_isInitialized) {
      debugPrint("Agora Engine not initialized when trying to join channel");
      return;
    }

    _lastChannelName = channelName;
    _lastUid = uid;

    try {
      debugPrint("AGORA_JOINING: Joining channel $channelName with uid $uid (token length: ${token.length})");
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      debugPrint("AGORA_JOIN_FAILED with token, attempting join with testing mode fallback: $e");
      try {
        await _engine!.joinChannel(
          token: "",
          channelId: channelName,
          uid: uid,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileCommunication,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
          ),
        );
      } catch (fallbackError) {
        debugPrint("AGORA_FALLBACK_FAILED: $fallbackError");
      }
    }
  }

  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    debugPrint("AGORA_MUTE: Local audio muted: $_isMuted");
  }

  Future<void> toggleSpeakerphone() async {
    if (_engine == null) return;
    _isSpeakerPhone = !_isSpeakerPhone;
    await _engine!.setEnableSpeakerphone(_isSpeakerPhone);
    debugPrint("AGORA_SPEAKER: Speakerphone active: $_isSpeakerPhone");
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;
    try {
      await _engine!.leaveChannel();
      debugPrint("AGORA_LEFT: Left Agora channel");
    } catch (e) {
      debugPrint("Error leaving channel: $e");
    }
  }

  Future<void> dispose() async {
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
        _isInitialized = false;
        debugPrint("AGORA_DISPOSED: Engine released");
      } catch (e) {
        debugPrint("Error disposing Agora engine: $e");
      }
    }
  }
}
