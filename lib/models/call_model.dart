class CallModel {
  final String callId;
  final String appId;
  final String channelName;
  final String? token;
  final int? uid;
  final String status;
  final int callerId;
  final String callerName;
  final String? callerProfileImage;
  final int receiverId;
  final String receiverName;
  final String? receiverProfileImage;
  final String callType;
  final int duration;

  CallModel({
    required this.callId,
    required this.appId,
    required this.channelName,
    this.token,
    this.uid,
    required this.status,
    required this.callerId,
    required this.callerName,
    this.callerProfileImage,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfileImage,
    this.callType = 'VOICE',
    this.duration = 0,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      callId: json['callId']?.toString() ?? '',
      appId: json['appId']?.toString() ?? '3a496a15c508417e971ffa6f75ba7c7b',
      channelName: json['channelName']?.toString() ?? '',
      token: json['token']?.toString(),
      uid: json['uid'] is int ? json['uid'] : int.tryParse(json['uid']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'RINGING',
      callerId: json['callerId'] is int ? json['callerId'] : int.parse(json['callerId']?.toString() ?? '0'),
      callerName: json['callerName']?.toString() ?? 'Unknown',
      callerProfileImage: json['callerProfileImage']?.toString(),
      receiverId: json['receiverId'] is int ? json['receiverId'] : int.parse(json['receiverId']?.toString() ?? '0'),
      receiverName: json['receiverName']?.toString() ?? 'Unknown',
      receiverProfileImage: json['receiverProfileImage']?.toString(),
      callType: json['callType']?.toString() ?? 'VOICE',
      duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'appId': appId,
      'channelName': channelName,
      'token': token,
      'uid': uid,
      'status': status,
      'callerId': callerId,
      'callerName': callerName,
      'callerProfileImage': callerProfileImage,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverProfileImage': receiverProfileImage,
      'callType': callType,
      'duration': duration,
    };
  }
}
