class TaskReminderModel {
  final int id;
  final String title;
  final String description;
  final String targetId;
  final bool isGroup;
  final String creatorUsername;
  final int scheduledTimestamp;
  final bool isCompleted;
  final bool isTriggered;

  TaskReminderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetId,
    required this.isGroup,
    required this.creatorUsername,
    required this.scheduledTimestamp,
    required this.isCompleted,
    required this.isTriggered,
  });

  factory TaskReminderModel.fromJson(Map<String, dynamic> json) {
    return TaskReminderModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      isGroup: json['isGroup'] == true || json['isGroup']?.toString() == 'true',
      creatorUsername: json['creatorUsername']?.toString() ?? '',
      scheduledTimestamp: json['scheduledTimestamp'] is int
          ? json['scheduledTimestamp']
          : int.tryParse(json['scheduledTimestamp']?.toString() ?? '0') ?? 0,
      isCompleted: json['isCompleted'] == true || json['isCompleted']?.toString() == 'true',
      isTriggered: json['isTriggered'] == true || json['isTriggered']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetId': targetId,
      'isGroup': isGroup,
      'creatorUsername': creatorUsername,
      'scheduledTimestamp': scheduledTimestamp,
      'isCompleted': isCompleted,
      'isTriggered': isTriggered,
    };
  }
}
