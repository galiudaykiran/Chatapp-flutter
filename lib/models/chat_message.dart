// ignore_for_file: constant_identifier_names

import '../config/api_config.dart';

enum MessageType { TEXT, IMAGE, FILE, LOCATION }

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
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageType parsedType;
    final typeStr = (json['type'] ?? 'TEXT').toString().toUpperCase();
    final fName = (json['fileName'] ?? '').toString().toLowerCase();
    final rawUrl = (json['fileUrl'] ?? '').toString();
    final fixedUrl = rawUrl.isNotEmpty ? ApiConfig.fixUrl(rawUrl) : null;
    final fUrl = (fixedUrl ?? '').toLowerCase();

    bool isImageExtension = fName.endsWith('.jpg') ||
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
      default:
        parsedType = MessageType.TEXT;
    }

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
    };
  }
}
