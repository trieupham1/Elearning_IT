import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/notification.dart';
import '../utils/token_manager.dart';
import 'api_service.dart';

class NotificationService extends ApiService {
  // Get all notifications for current user
  Future<List<NotificationModel>> getNotifications({bool? unreadOnly}) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      String url = '${ApiConfig.baseUrl}${ApiConfig.notifications}';
      if (unreadOnly == true) {
        url += '?unreadOnly=true';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => NotificationModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load notifications: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.notifications}/unread/count',
            ),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      } else {
        throw Exception('Failed to load unread count: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching unread count: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .put(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.notifications}/$notificationId/read',
            ),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to mark notification as read: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .put(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.notifications}/read/all',
            ),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to mark all notifications as read: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .delete(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.notifications}/$notificationId',
            ),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  // Create a notification (typically for instructors)
  Future<NotificationModel> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}'),
            headers: headers,
            body: json.encode({
              'userId': userId,
              'type': type,
              'title': title,
              'message': message,
              'data': data,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        return NotificationModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating notification: $e');
    }
  }

  // Send course invitation
  Future<void> sendCourseInvitation({
    required String courseId,
    required List<String> studentIds,
    String? groupId,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final body = {'courseId': courseId, 'studentIds': studentIds};
      if (groupId != null) {
        body['groupId'] = groupId;
      }

      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.notifications}/course-invitation',
            ),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to send course invitation: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending course invitation: $e');
    }
  }

  // Respond to course invitation
  Future<void> respondToCourseInvitation({
    required String notificationId,
    required bool accept,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.notifications}/$notificationId/respond',
            ),
            headers: headers,
            body: json.encode({'accept': accept}),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to respond to invitation: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error responding to invitation: $e');
    }
  }

  // Respond to course join request (instructor)
  Future<void> respondToJoinRequest({
    required String courseId,
    required String notificationId,
    required bool approve,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.courses}/$courseId/join-request/$notificationId/respond',
            ),
            headers: headers,
            body: json.encode({'approve': approve}),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to respond to join request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error responding to join request: $e');
    }
  }
}
