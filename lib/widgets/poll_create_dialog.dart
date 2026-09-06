import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';

class PollCreateDialog extends StatefulWidget {
  final String recipient;

  const PollCreateDialog({super.key, required this.recipient});

  static Future<void> show(BuildContext context, {required String recipient}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PollCreateDialog(recipient: recipient),
    );
  }

  @override
  State<PollCreateDialog> createState() => _PollCreateDialogState();
}

class _PollCreateDialogState extends State<PollCreateDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;

  void _addOption() {
    if (_optionControllers.length < 8) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers.removeAt(index);
      });
    }
  }

  void _createPoll() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll question')),
      );
      return;
    }

    final validOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 2 options')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final sender = auth.currentUser?.username ?? 'User';

    final pollMap = {
      'question': question,
      'options': validOptions,
      'allowMultiple': _allowMultiple,
      'votes': <String, List<String>>{},
    };

    final pollMessage = ChatMessage(
      sender: sender,
      recipient: widget.recipient,
      type: MessageType.POLL,
      content: question,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      pollData: jsonEncode(pollMap),
    );

    chat.sendChatMessage(pollMessage);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final cardBorder = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.poll_rounded, color: AppTheme.primaryEmerald, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Create Poll',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Question',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _questionController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Options',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              ..._optionControllers.asMap().entries.map((entry) {
                final int idx = entry.key;
                final TextEditingController ctrl = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Option ${idx + 1}',
                            filled: true,
                            fillColor: cardBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _removeOption(idx),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (_optionControllers.length < 8)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryEmerald, size: 18),
                  label: const Text('Add Option', style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Allow multiple answers', style: TextStyle(color: textPrimary, fontSize: 14)),
                value: _allowMultiple,
                activeTrackColor: AppTheme.primaryEmerald,
                onChanged: (val) => setState(() => _allowMultiple = val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _createPoll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('CREATE POLL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
