import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcService {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  MediaStream? get localStream => _localStream;

  Future<void> initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<MediaStream> startLocalStream(bool isVideo) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'mandatory': {
          'echoCancellation': 'true',
          'googEchoCancellation': 'true',
          'googAutoGainControl': 'true',
          'googNoiseSuppression': 'true',
          'googHighpassFilter': 'true',
        },
        'optional': [],
      },
      'video': isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
    Helper.setSpeakerphoneOn(true);
    return _localStream!;
  }

  Future<RTCPeerConnection> createPeerConnectionHelper({
    required Function(RTCIceCandidate) onIceCandidate,
    required Function(MediaStream) onRemoteStream,
  }) async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration);

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    }

    _peerConnection?.onIceCandidate = (candidate) {
      onIceCandidate(candidate);
    };

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        onRemoteStream(event.streams[0]);
      }
    };

    return _peerConnection!;
  }

  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !isMuted;
      });
    }
  }

  void toggleCamera(bool isVideoEnabled) {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = isVideoEnabled;
      });
    }
  }

  void toggleSpeaker(bool isSpeaker) {
    Helper.setSpeakerphoneOn(isSpeaker);
  }

  Future<void> dispose() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
  }
}
