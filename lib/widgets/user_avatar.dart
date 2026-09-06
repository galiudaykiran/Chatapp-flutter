import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String username;
  final String? profileImage;
  final double radius;
  final double? fontSize;
  final bool isGroup;
  final bool showOnlineBadge;
  final bool isOnline;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.username,
    this.profileImage,
    this.radius = 24,
    this.fontSize,
    this.isGroup = false,
    this.showOnlineBadge = false,
    this.isOnline = false,
    this.onTap,
  });

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFFFF416C), Color(0xFFFF4B2B)], // Sunset Coral
    [Color(0xFF0072FF), Color(0xFF00C6FF)], // Ocean Blue
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Electric Purple
    [Color(0xFFF2994A), Color(0xFFF2C94C)], // Amber Honey
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Mint Emerald
    [Color(0xFFE52D27), Color(0xFFB31217)], // Crimson Red
    [Color(0xFF0575E6), Color(0xFF00F260)], // Cyan Lime
    [Color(0xFF7F00FF), Color(0xFFE100FF)], // Neon Magenta
    [Color(0xFFFF8008), Color(0xFFFFC837)], // Tangerine Gold
    [Color(0xFF2193B0), Color(0xFF6DD5ED)], // Sky Topaz
    [Color(0xFF654EA3), Color(0xFFEAAFC8)], // Cosmic Lavender
    [Color(0xFF00B09B), Color(0xFF96C93D)], // Jade Green
    [Color(0xFFD31027), Color(0xFFEA384D)], // Cherry Pop
    [Color(0xFF0F2027), Color(0xFF203A43)], // Slate Onyx
    [Color(0xFF4A00E0), Color(0xFF8E2DE2)], // Royal Indigo
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Hot Pink Coral
  ];

  List<Color> _getGradientForName(String name) {
    if (name.isEmpty) return _avatarGradients[0];
    int hash = 5381;
    final lower = name.toLowerCase().trim();
    for (int i = 0; i < lower.length; i++) {
      hash = (((hash << 5) + hash) + lower.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return _avatarGradients[hash % _avatarGradients.length];
  }

  String _getInitial(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim();
    if (clean.isEmpty) return 'U';
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradientForName(username);
    final initial = _getInitial(username);
    final textFontSize = fontSize ?? (radius * 0.78);
    final hasValidImage = profileImage != null &&
        profileImage!.trim().isNotEmpty &&
        !profileImage!.contains('null');

    Widget avatarContent;

    if (hasValidImage) {
      final imgUrl = profileImage!.trim();
      if (imgUrl.startsWith('data:') || imgUrl.contains(';base64,')) {
        try {
          final base64Str = imgUrl.split(',').last;
          final bytes = base64Decode(base64Str);
          avatarContent = ClipOval(
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildLetterFallback(gradient, initial, textFontSize),
            ),
          );
        } catch (_) {
          avatarContent = _buildLetterFallback(gradient, initial, textFontSize);
        }
      } else {
        avatarContent = ClipOval(
          child: Image.network(
            ApiConfig.fixUrl(imgUrl),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildLetterFallback(gradient, initial, textFontSize),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return _buildLetterFallback(gradient, initial, textFontSize);
            },
          ),
        );
      }
    } else {
      avatarContent = _buildLetterFallback(gradient, initial, textFontSize);
    }

    Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (showOnlineBadge) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                color: isOnline ? AppTheme.statusOnline : AppTheme.statusOffline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _buildLetterFallback(List<Color> gradient, String initial, double fSize) {
    if (isGroup) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: radius * 0.9,
          ),
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: fSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
