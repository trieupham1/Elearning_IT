import 'dart:convert';
import '../models/message.dart';
import 'api_service.dart';

class MessageService {
  final ApiService _apiService = ApiService();

  Future<List<ChatMessage>> getConversation(String userId) async {
    try {
      final response = await _apiService.get('/messages/conversation/$userId');
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      print('Error loading conversation: $e');
      return [];
    }
  }

  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _apiService.get('/messages/conversations');
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } catch (e) {
      print('Error loading conversations: $e');
      return [];
    }
  }

  Future<ChatMessage?> sendMessage({
    required String receiverId,
    required String content,
    String? fileId, // Add this parameter
  }) async {
    try {
      final response = await _apiService.post(
        '/messages',
        body: {
          'receiverId': receiverId,
          'content': content,
          if (fileId != null) 'fileId': fileId, // Include fileId if provided
        },
      );

      final data = json.decode(response.body);
      return ChatMessage.fromJson(data);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get('/messages/unread/count');
      final data = json.decode(response.body);
      return data['count'] ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<bool> markAsRead(String messageId) async {
    try {
      final response = await _apiService.put(
        '/messages/$messageId/read',
        body: {},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error marking message as read: $e');
      return false;
    }
  }
}
