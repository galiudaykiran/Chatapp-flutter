class GroupModel {
  final String groupId;
  final String name;
  final String? description;
  final String? groupImage;
  final String adminUsername;
  final List<String> members;
  final int createdAt;

  GroupModel({
    required this.groupId,
    required this.name,
    this.description,
    this.groupImage,
    required this.adminUsername,
    required this.members,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      groupId: json['groupId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Group',
      description: json['description']?.toString(),
      groupImage: json['groupImage']?.toString(),
      adminUsername: json['adminUsername']?.toString() ?? '',
      members: (json['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['createdAt'] is int ? json['createdAt'] : (int.tryParse(json['createdAt']?.toString() ?? '0') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'groupImage': groupImage,
      'adminUsername': adminUsername,
      'members': members,
      'createdAt': createdAt,
    };
  }
}
