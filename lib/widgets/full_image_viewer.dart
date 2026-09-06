import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class FullImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onMessageTap;
  final VoidCallback? onVoiceCallTap;
  final VoidCallback? onVideoCallTap;

  const FullImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.onMessageTap,
    this.onVoiceCallTap,
    this.onVideoCallTap,
  });

  static void show(
    BuildContext context, {
    required String? imageUrl,
    required String title,
    String? subtitle,
    VoidCallback? onMessageTap,
    VoidCallback? onVoiceCallTap,
    VoidCallback? onVideoCallTap,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (context, _, __) => FullImageViewer(
          imageUrl: imageUrl,
          title: title,
          subtitle: subtitle,
          onMessageTap: onMessageTap,
          onVoiceCallTap: onVoiceCallTap,
          onVideoCallTap: onVideoCallTap,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _showControls = true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..storage[12] = -position.dx * 1.5
        ..storage[13] = -position.dy * 1.5
        ..storage[0] = 2.5
        ..storage[5] = 2.5;
    }
  }

  void _copyImageDetails() {
    Clipboard.setData(ClipboardData(text: widget.title));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryEmerald, size: 20),
            const SizedBox(width: 10),
            Text('Copied "${widget.title}" to clipboard!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _simulateSaveImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: AppTheme.primaryEmerald, size: 20),
            SizedBox(width: 10),
            Text('Profile picture saved to photo gallery 📸'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFullImage() {
    final rawUrl = widget.imageUrl;

    if (rawUrl == null || rawUrl.isEmpty) {
      return Container(
        width: 240,
        height: 240,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.storyRingGradient,
        ),
        child: CircleAvatar(
          backgroundColor: AppTheme.cardDark,
          child: Text(
            widget.title.isNotEmpty ? widget.title[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontSize: 90,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryEmerald,
            ),
          ),
        ),
      );
    }

    if (rawUrl.startsWith('data:image')) {
      try {
        final base64Data = rawUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
        );
      } catch (_) {
        return _buildFallbackAvatar();
      }
    } else if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return Image.network(
        rawUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryEmerald),
          );
        },
        errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
      );
    }

    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 260,
      height: 260,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.storyRingGradient,
      ),
      child: CircleAvatar(
        backgroundColor: AppTheme.cardDark,
        child: Text(
          widget.title.isNotEmpty ? widget.title[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryEmerald,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Zoomable Image View
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Hero(
                    tag: 'profile_pic_${widget.title}',
                    child: _buildFullImage(),
                  ),
                ),
              ),
            ),

            // Top Bar Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _showControls ? 0 : -90,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                      onPressed: _copyImageDetails,
                      tooltip: 'Copy Info',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                      onPressed: _simulateSaveImage,
                      tooltip: 'Save Picture',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Quick Action Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              bottom: _showControls ? 16 : -100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.cardBorderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (widget.onMessageTap != null)
                      _buildActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Message',
                        color: AppTheme.primaryEmerald,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onMessageTap!();
                        },
                      ),
                    if (widget.onVoiceCallTap != null)
                      _buildActionButton(
                        icon: Icons.phone_rounded,
                        label: 'Voice Call',
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onVoiceCallTap!();
                        },
                      ),
                    if (widget.onVideoCallTap != null)
                      _buildActionButton(
                        icon: Icons.videocam_rounded,
                        label: 'Video Call',
                        color: Colors.purpleAccent,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onVideoCallTap!();
                        },
                      ),
                    _buildActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      color: Colors.amber,
                      onTap: _copyImageDetails,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
