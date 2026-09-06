// ignore_for_file: constant_identifier_names

import '../config/api_config.dart';

enum MessageType {
  TEXT,
  IMAGE,
  FILE,
  LOCATION,
  JOIN,
  LEAVE,
  AUDIO,
  TYPING,
  EDIT,
  DELETE,
  CALL_OFFER,
  CALL_ACCEPT,
  CALL_DECLINE,
  CALL_END,
  POLL,
  POLL_VOTE,
  VIEW_ONCE_OPENED,
}

class ChatMessage {
  final String? id;
  final String sender;
  final String recipient;
  final MessageType type;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final double? latitude;
  final double? longitude;
  final int timestamp;
  final bool isRead;
  final String? status;
  final String? reaction;
  final bool isStarred;
  final int? duration;
  final bool edited;
  final bool deleted;
  final int? editedTimestamp;
  final int? visibilitySeconds;
  final int? autoDeleteTimestamp;
  final String? deleteType;
  final String? replyToId;
  final String? replyToSender;
  final String? replyToText;
  final bool isPinned;
  final bool isViewOnce;
  final bool isViewOnceOpened;
  final String? pollData;

  ChatMessage({
    this.id,
    required this.sender,
    required this.recipient,
    required this.type,
    this.content,
    this.fileUrl,
    this.fileName,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.isRead = false,
    this.status,
    this.reaction,
    this.isStarred = false,
    this.duration,
    this.edited = false,
    this.deleted = false,
    this.editedTimestamp,
    this.visibilitySeconds,
    this.autoDeleteTimestamp,
    this.deleteType,
    this.replyToId,
    this.replyToSender,
    this.replyToText,
    this.isPinned = false,
    this.isViewOnce = false,
    this.isViewOnceOpened = false,
    this.pollData,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageType parsedType;
    final typeStr = (json['type'] ?? 'TEXT').toString().toUpperCase();
    final fName = (json['fileName'] ?? '').toString().toLowerCase();
    final rawUrl = (json['fileUrl'] ?? '').toString();
    final fixedUrl = (rawUrl.startsWith('data:') || rawUrl.startsWith('blob:'))
        ? rawUrl
        : (rawUrl.isNotEmpty ? ApiConfig.fixUrl(rawUrl) : null);
    final fUrl = (fixedUrl ?? '').toLowerCase();

    bool isDataUriImage = rawUrl.startsWith('data:image/');
    bool isImageExtension = isDataUriImage ||
        fName.endsWith('.jpg') ||
        fName.endsWith('.jpeg') ||
        fName.endsWith('.png') ||
        fName.endsWith('.gif') ||
        fName.endsWith('.webp') ||
        fUrl.endsWith('.jpg') ||
        fUrl.endsWith('.jpeg') ||
        fUrl.endsWith('.png') ||
        fUrl.endsWith('.gif') ||
        fUrl.endsWith('.webp');

    switch (typeStr) {
      case 'IMAGE':
        parsedType = MessageType.IMAGE;
        break;
      case 'FILE':
        parsedType = isImageExtension ? MessageType.IMAGE : MessageType.FILE;
        break;
      case 'LOCATION':
        parsedType = MessageType.LOCATION;
        break;
      case 'AUDIO':
        parsedType = MessageType.AUDIO;
        break;
      case 'TYPING':
        parsedType = MessageType.TYPING;
        break;
      case 'EDIT':
        parsedType = MessageType.EDIT;
        break;
      case 'DELETE':
        parsedType = MessageType.DELETE;
        break;
      case 'JOIN':
        parsedType = MessageType.JOIN;
        break;
      case 'LEAVE':
        parsedType = MessageType.LEAVE;
        break;
      case 'CALL_OFFER':
        parsedType = MessageType.CALL_OFFER;
        break;
      case 'CALL_ACCEPT':
        parsedType = MessageType.CALL_ACCEPT;
        break;
      case 'CALL_DECLINE':
        parsedType = MessageType.CALL_DECLINE;
        break;
      case 'CALL_END':
        parsedType = MessageType.CALL_END;
        break;
      case 'POLL':
        parsedType = MessageType.POLL;
        break;
      case 'POLL_VOTE':
        parsedType = MessageType.POLL_VOTE;
        break;
      case 'VIEW_ONCE_OPENED':
        parsedType = MessageType.VIEW_ONCE_OPENED;
        break;
      default:
        parsedType = MessageType.TEXT;
    }

    final rawStatus = json['status']?.toString().toUpperCase();
    final bool readState = json['isRead'] == true ||
        json['read'] == true ||
        rawStatus == 'READ' ||
        rawStatus == 'SEEN';

    return ChatMessage(
      id: json['id']?.toString(),
      sender: json['sender'] ?? '',
      recipient: json['recipient'] ?? '',
      type: parsedType,
      content: json['content'],
      fileUrl: fixedUrl,
      fileName: json['fileName'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      timestamp: json['timestamp'] is int
          ? json['timestamp']
          : DateTime.now().millisecondsSinceEpoch,
      isRead: readState,
      status: rawStatus,
      reaction: json['reaction']?.toString(),
      isStarred: json['isStarred'] == true,
      duration: json['duration'] is int ? json['duration'] : null,
      edited: json['edited'] == true,
      deleted: json['deleted'] == true,
      editedTimestamp: json['editedTimestamp'] is int
          ? json['editedTimestamp']
          : int.tryParse(json['editedTimestamp']?.toString() ?? ''),
      visibilitySeconds: json['visibilitySeconds'] is int
          ? json['visibilitySeconds']
          : int.tryParse(json['visibilitySeconds']?.toString() ?? ''),
      autoDeleteTimestamp: json['autoDeleteTimestamp'] is int
          ? json['autoDeleteTimestamp']
          : int.tryParse(json['autoDeleteTimestamp']?.toString() ?? ''),
      deleteType: json['deleteType']?.toString(),
      replyToId: json['replyToId']?.toString(),
      replyToSender: json['replyToSender']?.toString(),
      replyToText: json['replyToText']?.toString(),
      isPinned: json['isPinned'] == true,
      isViewOnce: json['isViewOnce'] == true,
      isViewOnceOpened: json['isViewOnceOpened'] == true,
      pollData: json['pollData']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'recipient': recipient,
      'type': type.name,
      'content': content,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'isRead': isRead,
      'status': status,
      'reaction': reaction,
      'isStarred': isStarred,
      'duration': duration,
      'edited': edited,
      'deleted': deleted,
      'editedTimestamp': editedTimestamp,
      'visibilitySeconds': visibilitySeconds,
      'autoDeleteTimestamp': autoDeleteTimestamp,
      'deleteType': deleteType,
      'replyToId': replyToId,
      'replyToSender': replyToSender,
      'replyToText': replyToText,
      'isPinned': isPinned,
      'isViewOnce': isViewOnce,
      'isViewOnceOpened': isViewOnceOpened,
      'pollData': pollData,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? sender,
    String? recipient,
    MessageType? type,
    String? content,
    String? fileUrl,
    String? fileName,
    double? latitude,
    double? longitude,
    int? timestamp,
    bool? isRead,
    String? status,
    String? reaction,
    bool? isStarred,
    int? duration,
    bool? edited,
    bool? deleted,
    int? editedTimestamp,
    int? visibilitySeconds,
    int? autoDeleteTimestamp,
    String? deleteType,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
    bool? isPinned,
    bool? isViewOnce,
    bool? isViewOnceOpened,
    String? pollData,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      type: type ?? this.type,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      reaction: reaction ?? this.reaction,
      isStarred: isStarred ?? this.isStarred,
      duration: duration ?? this.duration,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      editedTimestamp: editedTimestamp ?? this.editedTimestamp,
      visibilitySeconds: visibilitySeconds ?? this.visibilitySeconds,
      autoDeleteTimestamp: autoDeleteTimestamp ?? this.autoDeleteTimestamp,
      deleteType: deleteType ?? this.deleteType,
      replyToId: replyToId ?? this.replyToId,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToText: replyToText ?? this.replyToText,
      isPinned: isPinned ?? this.isPinned,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      isViewOnceOpened: isViewOnceOpened ?? this.isViewOnceOpened,
      pollData: pollData ?? this.pollData,
    );
  }
}
