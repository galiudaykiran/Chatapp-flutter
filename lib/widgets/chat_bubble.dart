import 'poll_card.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import 'location_card.dart';
import 'full_image_viewer.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(ChatMessage)? onReply;
  final Function(String replyToId)? onReplyTap;
  final Function(ChatMessage)? onPin;
  final Function(ChatMessage)? onForward;
  final Function(ChatMessage)? onDelete;
  final Function(ChatMessage)? onEdit;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onReply,
    this.onReplyTap,
    this.onPin,
    this.onForward,
    this.onDelete,
    this.onEdit,
  });

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final String formattedUrl = imageUrl.startsWith('data:') || imageUrl.contains(';base64,')
        ? imageUrl
        : ApiConfig.fixUrl(imageUrl);

    FullImageViewer.show(
      context,
      imageUrl: formattedUrl,
      title: 'Chat Attachment',
      subtitle: DateFormat('MMM dd, hh:mm a').format(
        DateTime.fromMillisecondsSinceEpoch(message.timestamp),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
        final textPrimaryColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
        final maxHeight = MediaQuery.of(context).size.height * 0.75;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // WhatsApp Style Floating Emoji Quick Reaction Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['❤️', '👍', '😂', '😮', '😢', '🔥'].map((emoji) {
                        final isCurrentReaction = message.reaction == emoji;
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.pop(context);
                            final chat = Provider.of<ChatProvider>(context, listen: false);
                            chat.toggleReaction(message, emoji);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentReaction
                                  ? (isDark ? AppTheme.primaryEmerald.withValues(alpha: 0.3) : const Color(0xFFD1FAE5))
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.reply_rounded, color: AppTheme.accentCyan),
                    title: Text(
                      'Reply',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Quote this message in reply',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (onReply != null) onReply!(message);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      message.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                    ),
                    title: Text(
                      message.isStarred ? 'Unstar Message' : 'Star Message',
                      style: TextStyle(color: textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final chat = Provider.of<ChatProvider>(context, listen: false);
                      chat.toggleStarred(message);
                    },
                  ),
                  if (isMe && (message.type == MessageType.TEXT || message.type == MessageType.EDIT) && !message.deleted && message.content != null) ...[
                    ListTile(
                      leading: const Icon(Icons.edit_rounded, color: AppTheme.accentCyan),
                      title: Text('Edit Message', style: TextStyle(color: textPrimaryColor)),
                      onTap: () {
                        Navigator.pop(context);
                        if (onEdit != null) onEdit!(message);
                      },
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: Text('Delete for Me', style: TextStyle(color: textPrimaryColor)),
                    subtitle: Text('Removes only on this device', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                    onTap: () {
                      Navigator.pop(context);
                      final chat = Provider.of<ChatProvider>(context, listen: false);
                      chat.deleteForMe(message);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message deleted for you 🗑️')),
                      );
                    },
                  ),
                  if (isMe && !message.deleted) ...[
                    ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                      title: const Text('Delete for Everyone', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      subtitle: Text('Deletes for all participants in chat', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                      onTap: () {
                        Navigator.pop(context);
                        final chat = Provider.of<ChatProvider>(context, listen: false);
                        chat.deleteForEveryone(message);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message deleted for everyone! 🗑️')),
                        );
                      },
                    ),
                  ],
                  if ((message.type == MessageType.TEXT || message.type == MessageType.EDIT) && message.content != null && !message.deleted) ...[
                    ListTile(
                      leading: const Icon(Icons.copy_rounded, color: AppTheme.primaryEmerald),
                      title: Text('Copy Text', style: TextStyle(color: textPrimaryColor)),
                      onTap: () {
                        Navigator.pop(context);
                        Clipboard.setData(ClipboardData(text: message.content!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message copied to clipboard! 📋')),
                        );
                      },
                    ),
                  ],
                  if (message.type == MessageType.IMAGE && message.fileUrl != null) ...[
                    ListTile(
                      leading: const Icon(Icons.download_rounded, color: AppTheme.primaryEmerald),
                      title: Text('Save / Download Image', style: TextStyle(color: textPrimaryColor)),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image saved to gallery! 🖼️')),
                        );
                      },
                    ),
                  ],
                  ListTile(
                    leading: Icon(
                      message.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: Colors.amber,
                    ),
                    title: Text(
                      message.isPinned ? 'Unpin Message' : 'Pin to Top',
                      style: TextStyle(color: textPrimaryColor),
                    ),
                    subtitle: Text(
                      message.isPinned ? 'Remove from top banner' : 'Keep visible at the top of the chat',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (onPin != null) onPin!(message);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shortcut_rounded, color: Colors.blueAccent),
                    title: Text('Forward Message', style: TextStyle(color: textPrimaryColor)),
                    onTap: () {
                      Navigator.pop(context);
                      if (onForward != null) onForward!(message);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isCodeSnippet(String text) {
    if (text.contains('```')) return true;
    final lines = text.split('\n');
    if (lines.length >= 3) {
      final codePattern = RegExp(
        r'\b(class|import|def|function|public|private|var|val|final|const|void|int|String|return|if|else|for|while|try|catch|override)\b',
      );
      int count = 0;
      for (var line in lines) {
        if (codePattern.hasMatch(line) || line.trim().endsWith('{') || line.trim().endsWith('};') || line.trim().endsWith(';')) {
          count++;
        }
      }
      return count >= 2;
    }
    return false;
  }

  Widget _buildCodeBlock(BuildContext context, String rawText) {
    String cleanCode = rawText;
    String langTag = 'CODE';

    if (rawText.contains('```')) {
      final parts = rawText.split('```');
      if (parts.length >= 2) {
        final block = parts[1];
        final firstLineEnd = block.indexOf('\n');
        if (firstLineEnd != -1) {
          final possibleLang = block.substring(0, firstLineEnd).trim();
          if (possibleLang.isNotEmpty && possibleLang.length < 12) {
            langTag = possibleLang.toUpperCase();
            cleanCode = block.substring(firstLineEnd + 1).trim();
          } else {
            cleanCode = block.trim();
          }
        } else {
          cleanCode = block.trim();
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code_rounded, color: AppTheme.accentNeon, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      langTag,
                      style: const TextStyle(
                        color: AppTheme.accentNeon,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: cleanCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard! 📋'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, color: Colors.white70, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Copy Code',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              cleanCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(message.timestamp),
    );

    final bool isMessageRead = message.isRead || message.status == 'READ' || message.status == 'SEEN';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleBg = isSelected
        ? AppTheme.primaryEmerald.withValues(alpha: 0.3)
        : (isMe
            ? (isDark ? const Color(0xFF005C4B) : const Color(0xFF00A884))
            : (isDark ? AppTheme.cardDark : AppTheme.cardLight));

    final bubbleBorder = isSelected
        ? AppTheme.primaryEmerald
        : (isMe
            ? (isDark ? const Color(0xFF007A63) : const Color(0xFF008F6F))
            : (isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight));

    final textSecondaryColor = isMe
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight);

    final bool isGroupMessage = message.recipient.toLowerCase().startsWith('group_');
    final bool hasReaction = message.reaction != null && message.reaction!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        final chat = Provider.of<ChatProvider>(context, listen: false);
        chat.toggleReaction(message, '❤️');
      },
      onLongPress: onLongPress ?? () => _showActionSheet(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: 4.0,
            bottom: hasReaction ? 14.0 : 4.0,
            left: 12.0,
            right: 12.0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                  border: Border.all(
                    color: bubbleBorder,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (isGroupMessage && !isMe) ...[
                      Text(
                        message.sender,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    if (message.replyToText != null && message.replyToText!.isNotEmpty)
                      _buildReplyQuotePreview(context, isDark, isMe),
                    _buildMessageContent(context, isDark),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isStarred) ...[
                          const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                        ],
                        if (message.visibilitySeconds != null && message.visibilitySeconds! > 0) ...[
                          Icon(Icons.timer_outlined, size: 11, color: textSecondaryColor),
                          const SizedBox(width: 2),
                          Text(
                            message.autoDeleteTimestamp != null
                                ? '${((message.autoDeleteTimestamp! - DateTime.now().millisecondsSinceEpoch) / 1000).clamp(0, 86400).ceil()}s'
                                : '${message.visibilitySeconds}s',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: textSecondaryColor,
                          ),
                        ),
                        if (message.edited || message.type == MessageType.EDIT) ...[
                          const SizedBox(width: 4),
                          Text(
                            message.editedTimestamp != null
                                ? '(edited ${DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(message.editedTimestamp!))})'
                                : '(edited)',
                            style: TextStyle(
                              fontSize: 9,
                              fontStyle: FontStyle.italic,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isMessageRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 14,
                            color: isMessageRead ? AppTheme.accentCyan : textSecondaryColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (hasReaction)
                Positioned(
                  bottom: -10,
                  right: isMe ? 8 : null,
                  left: !isMe ? 8 : null,
                  child: GestureDetector(
                    onTap: () {
                      final chat = Provider.of<ChatProvider>(context, listen: false);
                      chat.toggleReaction(message, message.reaction!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF121B22) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message.reaction!,
                        style: const TextStyle(fontSize: 13, height: 1.1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyQuotePreview(BuildContext context, bool isDark, bool isMe) {
    return GestureDetector(
      onTap: () {
        if (message.replyToId != null && onReplyTap != null) {
          onReplyTap!(message.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? (isMe ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.5))
              : (isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white : AppTheme.accentCyan,
              width: 3.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, size: 12, color: isMe ? Colors.white70 : AppTheme.accentCyan),
                const SizedBox(width: 4),
                Text(
                  message.replyToSender ?? 'Replying',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : AppTheme.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              message.replyToText ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white.withValues(alpha: 0.9) : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:') || imageUrl.contains(';base64,')) {
      try {
        final base64Data = imageUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImageError(),
        );
      } catch (_) {
        return _buildImageError();
      }
    }

    return Image.network(
      ApiConfig.fixUrl(imageUrl),
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 180,
          color: AppTheme.surfaceDark,
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryEmerald),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildImageError(),
    );
  }

  Widget _buildViewOnceBubble(BuildContext context, bool isDark, Color textPrimary, Color textSecondary) {
    final bool opened = message.isViewOnceOpened;
    final chat = Provider.of<ChatProvider>(context, listen: false);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: opened
          ? null
          : () {
              if (message.fileUrl != null && message.fileUrl!.isNotEmpty) {
                _showFullScreenImage(context, message.fileUrl!);
                if (!isMe) {
                  chat.markViewOnceOpened(message);
                }
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: opened
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : (isDark ? const Color(0xFF0F2E28) : const Color(0xFFE6F4EA)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: opened
                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400)
                : AppTheme.primaryEmerald,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: opened ? textSecondary : AppTheme.primaryEmerald,
                  width: 1.5,
                ),
              ),
              child: Text(
                '1',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: opened ? textSecondary : AppTheme.primaryEmerald,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              opened ? 'Opened' : 'Photo • Tap to view',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: opened ? textSecondary : (isMe ? Colors.white : AppTheme.primaryEmerald),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 140,
      color: AppTheme.surfaceDark,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, size: 40, color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDark) {
    final textPrimaryColor = isMe
        ? Colors.white
        : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight);

    final textSecondaryColor = isMe
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight);

    switch (message.type) {
      case MessageType.POLL:
        return PollCard(message: message, isDark: isDark, isMe: isMe);
      case MessageType.POLL_VOTE:
      case MessageType.VIEW_ONCE_OPENED:
        return const SizedBox.shrink();
      case MessageType.IMAGE:
        if (message.isViewOnce) {
          return _buildViewOnceBubble(context, isDark, textPrimaryColor, textSecondaryColor);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, message.fileUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(message.fileUrl!),
                ),
              ),
            if (message.content != null && message.content!.isNotEmpty && message.content != 'Image attachment') ...[
              const SizedBox(height: 6),
              Text(
                message.content!,
                style: TextStyle(fontSize: 15, color: textPrimaryColor),
              ),
            ],
          ],
        );
      case MessageType.FILE:
        return GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Document: ${message.fileName ?? "File attachment"}')),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  color: isMe ? Colors.white : AppTheme.primaryEmerald,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? 'Document File',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textPrimaryColor,
                      ),
                    ),
                    Text(
                      'Attachment',
                      style: TextStyle(fontSize: 11, color: textSecondaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case MessageType.AUDIO:
        return _VoiceNoteBubble(
          message: message,
          isMe: isMe,
          isDark: isDark,
          textSecondaryColor: textSecondaryColor,
        );
      case MessageType.LOCATION:
        return LocationCard(
          latitude: message.latitude ?? 0.0,
          longitude: message.longitude ?? 0.0,
        );
      case MessageType.DELETE:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 16, color: isMe ? Colors.white70 : Colors.grey),
            const SizedBox(width: 6),
            Text(
              'This message was deleted',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        );
      case MessageType.TYPING:
        return const SizedBox.shrink();
      case MessageType.JOIN:
      case MessageType.LEAVE:
        return const SizedBox.shrink();
      case MessageType.CALL_OFFER:
      case MessageType.CALL_ACCEPT:
      case MessageType.CALL_DECLINE:
      case MessageType.CALL_END:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              message.type == MessageType.CALL_DECLINE
                  ? Icons.call_missed_rounded
                  : Icons.phone_in_talk_rounded,
              size: 18,
              color: isMe ? Colors.white : AppTheme.primaryEmerald,
            ),
            const SizedBox(width: 8),
            Text(
              message.type == MessageType.CALL_OFFER
                  ? 'Call offer (${message.content ?? "Voice"})'
                  : (message.type == MessageType.CALL_ACCEPT
                      ? 'Call connected'
                      : (message.type == MessageType.CALL_DECLINE ? 'Call declined' : 'Call ended')),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryColor),
            ),
          ],
        );
      case MessageType.TEXT:
      case MessageType.EDIT:
        if (message.deleted) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded, size: 16, color: isMe ? Colors.white70 : Colors.grey),
              const SizedBox(width: 6),
              Text(
                'This message was deleted',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          );
        }
        final content = message.content ?? '';
        if (content.startsWith('⏰ Scheduled Reminder:') || content.startsWith('🔔 Reminder Alert:')) {
          return _buildTaskReminderCard(context, content, isDark, isMe);
        }
        if (_isCodeSnippet(content)) {
          return _buildCodeBlock(context, content);
        }
        return SelectableText(
          content,
          style: TextStyle(fontSize: 15, color: textPrimaryColor),
        );
    }
  }
  Widget _buildTaskReminderCard(BuildContext context, String rawText, bool isDark, bool isMe) {
    final lines = rawText.split('\n');
    final header = lines.isNotEmpty ? lines[0] : '⏰ Scheduled Reminder';
    String timeInfo = '';
    String desc = '';

    for (var line in lines.skip(1)) {
      if (line.startsWith('📅')) {
        timeInfo = line.replaceFirst('📅', '').trim();
      } else if (line.startsWith('📝')) {
        desc = line.replaceFirst('📝', '').trim();
      }
    }

    final isAlert = header.contains('Reminder Alert');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlert
            ? (isDark ? const Color(0xFF3B1D24) : const Color(0xFFFFE4E6))
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? Colors.redAccent : Colors.orangeAccent,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isAlert ? Colors.redAccent : Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAlert ? Icons.notifications_active_rounded : Icons.alarm_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  header,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isAlert ? Colors.redAccent : Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
          if (timeInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFFED7AA),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text(
                    timeInfo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceNoteBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final Color textSecondaryColor;

  const _VoiceNoteBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.textSecondaryColor,
  });

  @override
  State<_VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<_VoiceNoteBubble> {
  bool _isPlaying = false;
  double _speed = 1.0;

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppTheme.primaryEmerald;
    final speedText = '${_speed.toStringAsFixed(_speed.truncateToDouble() == _speed ? 0 : 1)}x';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.primaryEmerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: color,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(16, (i) {
                final heights = [12, 18, 8, 24, 14, 20, 10, 16, 22, 14, 8, 18, 12, 24, 16, 10];
                final isPassed = _isPlaying ? (i % 2 == 0) : true;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: heights[i % heights.length].toDouble(),
                  decoration: BoxDecoration(
                    color: isPassed ? color : color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '0:${(widget.message.duration ?? 5).toString().padLeft(2, '0')} • Voice Note',
                  style: TextStyle(fontSize: 11, color: widget.textSecondaryColor),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppTheme.primaryEmerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      speedText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.isMe ? Colors.white : AppTheme.primaryEmerald,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

