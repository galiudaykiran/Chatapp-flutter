import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task_reminder_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';

class TaskReminderDialog extends StatefulWidget {
  final String targetId;
  final String targetName;
  final bool isGroup;

  const TaskReminderDialog({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.isGroup,
  });

  static void show(
    BuildContext context, {
    required String targetId,
    required String targetName,
    required bool isGroup,
  }) {
    showDialog(
      context: context,
      builder: (_) => TaskReminderDialog(
        targetId: targetId,
        targetName: targetName,
        isGroup: isGroup,
      ),
    );
  }

  @override
  State<TaskReminderDialog> createState() => _TaskReminderDialogState();
}

class _TaskReminderDialogState extends State<TaskReminderDialog> {
  List<TaskReminderModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() => _isLoading = true);
    try {
      final tasks = await chat.fetchTasksForTarget(widget.targetId, auth.token!);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(minutes: 2));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
          final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
          final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.alarm_add_rounded, color: AppTheme.primaryEmerald),
                const SizedBox(width: 10),
                Text('Schedule Task Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Task Title *',
                      labelStyle: TextStyle(color: textSecondary),
                      hintText: 'e.g. Project Review Meeting',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(color: textSecondary),
                      hintText: 'Add meeting details or links...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Set Date & Time:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                selectedDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryEmerald),
                          label: Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                            style: TextStyle(color: textPrimary, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (pickedTime != null) {
                              setDialogState(() {
                                selectedTime = pickedTime;
                                selectedDate = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryEmerald),
                          label: Text(
                            selectedTime.format(ctx),
                            style: TextStyle(color: textPrimary, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;

                  final chat = Provider.of<ChatProvider>(context, listen: false);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  if (auth.token == null) return;

                  Navigator.pop(ctx);
                  final newTask = await chat.createTaskReminder(
                    token: auth.token!,
                    title: title,
                    description: descController.text.trim(),
                    targetId: widget.targetId,
                    isGroup: widget.isGroup,
                    scheduledTimestamp: selectedDate.millisecondsSinceEpoch,
                  );

                  if (newTask != null && mounted) {
                    _fetchTasks();
                    final timeFormatted = DateFormat('EEE, MMM dd, hh:mm a').format(selectedDate);
                    final descPart = (newTask.description.trim().isNotEmpty)
                        ? '\n📝 ${newTask.description.trim()}'
                        : '';
                    final reminderMsg = '⏰ Scheduled Reminder: ${newTask.title}\n📅 Due: $timeFormatted$descPart';
                    
                    if (auth.currentUser != null) {
                      chat.sendTextMessage(
                        sender: auth.currentUser!.username,
                        recipient: widget.targetId,
                        content: reminderMsg,
                      );
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Task "${newTask.title}" scheduled for $timeFormatted ⏰')),
                    );
                  }
                },
                child: const Text('SCHEDULE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final surfaceBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textPrimary = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final cardBorder = isDark ? AppTheme.cardBorderDark : AppTheme.cardBorderLight;

    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 450),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(bottom: BorderSide(color: cardBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.storyRingGradient,
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks & Reminders',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          'Target: ${widget.targetName}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Task List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryEmerald))
                  : _tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.alarm_off_rounded, size: 48, color: textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No scheduled tasks yet.',
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap "+ Schedule Task" below to set up reminders for ${widget.targetName}.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            final scheduledDate = DateTime.fromMillisecondsSinceEpoch(task.scheduledTimestamp);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: surfaceBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder),
                              ),
                              child: ListTile(
                                leading: Checkbox(
                                  activeColor: AppTheme.primaryEmerald,
                                  value: task.isCompleted,
                                  onChanged: (val) async {
                                    if (auth.token != null) {
                                      await chat.toggleTaskCompleted(task.id, auth.token!);
                                      _fetchTasks();
                                    }
                                  },
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (task.description.isNotEmpty)
                                      Text(task.description, style: TextStyle(color: textSecondary, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.primaryEmerald),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM dd, hh:mm a').format(scheduledDate),
                                          style: const TextStyle(color: AppTheme.primaryEmerald, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                        if (task.isTriggered) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('TRIGGERED 🔔', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    if (auth.token != null) {
                                      await chat.deleteTask(task.id, auth.token!);
                                      _fetchTasks();
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Footer Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showCreateTaskDialog,
                  icon: const Icon(Icons.alarm_add_rounded, color: Colors.white),
                  label: const Text('SCHEDULE NEW TASK / REMINDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
