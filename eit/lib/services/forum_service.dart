import 'dart:convert';
import 'api_service.dart';
import '../models/forum.dart';

class ForumService {
  final ApiService _apiService = ApiService();
  static const String _baseUrl = '/forum';

  /// Get all topics for a course with optional filters
  Future<Map<String, dynamic>> getTopics({
    required String courseId,
    String? search,
    String sortBy = 'recent',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'sortBy': sortBy,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _apiService.get(
        '$_baseUrl/course/$courseId/topics?$queryString',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'topics': (data['topics'] as List)
              .map((t) => ForumTopic.fromJson(t))
              .toList(),
          'pagination': ForumPagination.fromJson(data['pagination']),
        };
      } else {
        throw Exception('Failed to load topics: ${response.body}');
      }
    } catch (e) {
      print('Error in getTopics: $e');
      rethrow;
    }
  }

  /// Get a single topic by ID
  Future<ForumTopic> getTopic(String topicId) async {
    try {
      final response = await _apiService.get('$_baseUrl/topics/$topicId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Topic data received: $data'); // Debug log
        // Backend returns the topic directly, not wrapped in { topic: ... }
        return ForumTopic.fromJson(data);
      } else {
        throw Exception('Failed to load topic: ${response.body}');
      }
    } catch (e) {
      print('Error in getTopic: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Create a new topic
  Future<ForumTopic> createTopic({
    required String courseId,
    required String title,
    required String content,
    List<ForumAttachment> attachments = const [],
    List<String> tags = const [],
  }) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/course/$courseId/topics',
        body: {
          'title': title,
          'content': content,
          'attachments': attachments.map((a) => a.toJson()).toList(),
          'tags': tags,
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('Create topic response: $data'); // Debug log
        // Backend returns the topic directly, not wrapped
        return ForumTopic.fromJson(data);
      } else {
        throw Exception('Failed to create topic: ${response.body}');
      }
    } catch (e) {
      print('Error in createTopic: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Update a topic
  Future<ForumTopic> updateTopic({
    required String topicId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    try {
      final response = await _apiService.put(
        '$_baseUrl/topics/$topicId',
        body: {'title': title, 'content': content, 'tags': tags},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ForumTopic.fromJson(data['topic']);
      } else {
        throw Exception('Failed to update topic: ${response.body}');
      }
    } catch (e) {
      print('Error in updateTopic: $e');
      rethrow;
    }
  }

  /// Delete a topic
  Future<void> deleteTopic(String topicId) async {
    try {
      final response = await _apiService.delete('$_baseUrl/topics/$topicId');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete topic: ${response.body}');
      }
    } catch (e) {
      print('Error in deleteTopic: $e');
      rethrow;
    }
  }

  /// Toggle like on a topic
  Future<Map<String, dynamic>> toggleTopicLike(String topicId) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/topics/$topicId/like',
        body: {},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Toggle like response: $data'); // Debug log
        // Backend returns { likes: number, isLiked: boolean }
        return data ?? {'likes': 0, 'isLiked': false};
      } else {
        throw Exception('Failed to toggle like: ${response.body}');
      }
    } catch (e) {
      print('Error in toggleTopicLike: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Pin/unpin a topic (instructor only)
  Future<Map<String, dynamic>> toggleTopicPin(String topicId) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/topics/$topicId/pin',
        body: {},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to toggle pin: ${response.body}');
      }
    } catch (e) {
      print('Error in toggleTopicPin: $e');
      rethrow;
    }
  }

  /// Lock/unlock a topic (instructor only)
  Future<Map<String, dynamic>> toggleTopicLock(String topicId) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/topics/$topicId/lock',
        body: {},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to toggle lock: ${response.body}');
      }
    } catch (e) {
      print('Error in toggleTopicLock: $e');
      rethrow;
    }
  }

  /// Get all replies for a topic
  Future<List<ForumReply>> getReplies(String topicId) async {
    try {
      final response = await _apiService.get(
        '$_baseUrl/topics/$topicId/replies',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Replies data received: $data'); // Debug log
        // Backend returns replies array directly, not wrapped in { replies: ... }
        return (data as List)
            .map((r) => ForumReply.fromJson(r as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load replies: ${response.body}');
      }
    } catch (e) {
      print('Error in getReplies: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Create a reply to a topic
  Future<ForumReply> createReply({
    required String topicId,
    required String content,
    String? parentReplyId,
    List<ForumAttachment> attachments = const [],
  }) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/topics/$topicId/replies',
        body: {
          'content': content,
          if (parentReplyId != null) 'parentReplyId': parentReplyId,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('Create reply response: $data');
        // Backend returns the reply directly, not wrapped
        return ForumReply.fromJson(data);
      } else {
        throw Exception('Failed to create reply: ${response.body}');
      }
    } catch (e) {
      print('Error in createReply: $e');
      rethrow;
    }
  }

  /// Update a reply
  Future<ForumReply> updateReply({
    required String replyId,
    required String content,
  }) async {
    try {
      final response = await _apiService.put(
        '$_baseUrl/replies/$replyId',
        body: {'content': content},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ForumReply.fromJson(data['reply']);
      } else {
        throw Exception('Failed to update reply: ${response.body}');
      }
    } catch (e) {
      print('Error in updateReply: $e');
      rethrow;
    }
  }

  /// Delete a reply
  Future<void> deleteReply(String replyId) async {
    try {
      final response = await _apiService.delete('$_baseUrl/replies/$replyId');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete reply: ${response.body}');
      }
    } catch (e) {
      print('Error in deleteReply: $e');
      rethrow;
    }
  }

  /// Toggle like on a reply
  Future<Map<String, dynamic>> toggleReplyLike(String replyId) async {
    try {
      final response = await _apiService.post(
        '$_baseUrl/replies/$replyId/like',
        body: {},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Toggle reply like response: $data'); // Debug log
        return data ?? {'likes': 0, 'isLiked': false};
      } else {
        throw Exception('Failed to toggle like: ${response.body}');
      }
    } catch (e) {
      print('Error in toggleReplyLike: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }
}
