import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        final call = callProvider.currentCall;
        final state = callProvider.state;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (state == CallState.idle || call == null) {
          return const SizedBox.shrink();
        }

        final isCaller = call.callerId == (authProvider.currentUser?.id ?? 0);
        final displayName = isCaller ? call.receiverName : call.callerName;
        final displayImage = isCaller ? call.receiverProfileImage : call.callerProfileImage;

        String statusText;
        switch (state) {
          case CallState.ringingOutgoing:
            statusText = 'Calling...';
            break;
          case CallState.ringingIncoming:
            statusText = 'Incoming Voice Call';
            break;
          case CallState.connected:
            statusText = callProvider.remoteUserJoined
                ? _formatDuration(callProvider.callDurationSeconds)
                : 'Connecting...';
            break;
          case CallState.rejected:
            statusText = 'Call Rejected';
            break;
          case CallState.cancelled:
            statusText = 'Call Cancelled';
            break;
          case CallState.ended:
            statusText = 'Call Ended (${_formatDuration(callProvider.callDurationSeconds)})';
            break;
          case CallState.failed:
            statusText = callProvider.errorMessage ?? 'Call Failed';
            break;
          default:
            statusText = '';
        }

        final isTerminalState = state == CallState.cancelled ||
            state == CallState.ended ||
            state == CallState.rejected ||
            state == CallState.failed;

        return Scaffold(
          body: GestureDetector(
            onTap: isTerminalState ? () => callProvider.clearCallState() : null,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 30),

                    // User Info Header
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.teal.shade300, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 65,
                            backgroundColor: Colors.teal.shade800,
                            backgroundImage: displayImage != null && displayImage.isNotEmpty
                                ? NetworkImage(ApiConfig.fixUrl(displayImage))
                                : null,
                            child: (displayImage == null || displayImage.isEmpty)
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: state == CallState.connected ? Colors.tealAccent : Colors.white70,
                          ),
                        ),
                        if (isTerminalState) ...[
                          const SizedBox(height: 12),
                          const Text(
                            "Tap anywhere to dismiss",
                            style: TextStyle(fontSize: 13, color: Colors.white38),
                          ),
                        ],
                      ],
                    ),

                    // Call Control Buttons Bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 50.0, left: 24, right: 24),
                      child: state == CallState.ringingIncoming
                          ? _buildIncomingCallControls(context, callProvider, authProvider)
                          : _buildInCallControls(context, callProvider, authProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncomingCallControls(
    BuildContext context,
    CallProvider callProvider,
    AuthProvider authProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reject Call Button
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => callProvider.rejectCall(
                getAuthToken: () async => authProvider.token,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.redAccent, blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.call_end, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 8),
            const Text("Decline", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),

        // Accept Call Button
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => callProvider.acceptCall(
                getAuthToken: () async => authProvider.token,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.greenAccent, blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 8),
            const Text("Accept", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildInCallControls(
    BuildContext context,
    CallProvider callProvider,
    AuthProvider authProvider,
  ) {
    final isRingingOutgoing = callProvider.state == CallState.ringingOutgoing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute Button
        IconButton(
          onPressed: callProvider.toggleMute,
          icon: Icon(
            callProvider.isMuted ? Icons.mic_off : Icons.mic,
            color: callProvider.isMuted ? Colors.redAccent : Colors.white,
            size: 32,
          ),
          style: IconButton.styleFrom(
            backgroundColor: callProvider.isMuted ? Colors.white24 : Colors.white12,
            padding: const EdgeInsets.all(16),
          ),
        ),

        // End Call Button
        GestureDetector(
          onTap: () {
            if (isRingingOutgoing) {
              callProvider.cancelCall(getAuthToken: () async => authProvider.token);
            } else if (callProvider.state == CallState.connected) {
              callProvider.endCall(getAuthToken: () async => authProvider.token);
            } else {
              callProvider.clearCallState();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.redAccent, blurRadius: 15, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 38),
          ),
        ),

        // Speakerphone Button
        IconButton(
          onPressed: callProvider.toggleSpeaker,
          icon: Icon(
            callProvider.isSpeaker ? Icons.volume_up : Icons.volume_off,
            color: callProvider.isSpeaker ? Colors.tealAccent : Colors.white,
            size: 32,
          ),
          style: IconButton.styleFrom(
            backgroundColor: callProvider.isSpeaker ? Colors.white24 : Colors.white12,
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
