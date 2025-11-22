// models/message.dart
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? fileId; // Add this field
  final DateTime createdAt;
  final String senderName;
  final String? senderAvatar;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.fileId, // Add this parameter
    required this.createdAt,
    required this.senderName,
    this.senderAvatar,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      senderId:
          json['senderId']?['_id']?.toString() ??
          json['senderId']?.toString() ??
          '',
      receiverId:
          json['receiverId']?['_id']?.toString() ??
          json['receiverId']?.toString() ??
          '',
      content: json['content'] ?? '',
      fileId: json['fileId'], // Add this field
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      senderName:
          json['senderId']?['fullName'] ??
          json['senderId']?['username'] ??
          json['senderName'] ??
          'Unknown',
      senderAvatar:
          json['senderAvatar'] ??
          json['senderId']?['avatar'] ??
          json['senderId']?['profilePicture'],
    );
  }
}

class Conversation {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString().isNotEmpty == true
          ? json['userName'].toString()
          : 'User',
      userAvatar: json['userAvatar'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
