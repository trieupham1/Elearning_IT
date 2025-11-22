import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_manager.dart';
import '../models/group.dart';

class GroupService {
  // Get all groups for a course
  static Future<List<Group>> getGroupsByCourse(String courseId) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups?courseId=$courseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Group.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load groups: ${response.body}');
      }
    } catch (e) {
      print('Error fetching groups: $e');
      throw Exception('Error fetching groups: $e');
    }
  }

  // Get single group
  static Future<Group> getGroup(String groupId) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups/$groupId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Group.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load group: ${response.body}');
      }
    } catch (e) {
      print('Error fetching group: $e');
      throw Exception('Error fetching group: $e');
    }
  }

  // Create group (instructor only)
  static Future<Group> createGroup({
    required String name,
    required String courseId,
    required String createdBy,
    String? description,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'courseId': courseId,
          'createdBy': createdBy,
          'description': description,
          'members': [],
        }),
      );

      if (response.statusCode == 201) {
        return Group.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create group: ${response.body}');
      }
    } catch (e) {
      print('Error creating group: $e');
      throw Exception('Error creating group: $e');
    }
  }

  // Update group (instructor only)
  static Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? description,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/groups/$groupId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return Group.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update group: ${response.body}');
      }
    } catch (e) {
      print('Error updating group: $e');
      throw Exception('Error updating group: $e');
    }
  }

  // Delete group (instructor only)
  static Future<void> deleteGroup(String groupId) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/groups/$groupId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete group: ${response.body}');
      }
    } catch (e) {
      print('Error deleting group: $e');
      throw Exception('Error deleting group: $e');
    }
  }

  // Add students to group (instructor only)
  static Future<Group> addStudentsToGroup({
    required String groupId,
    required List<String> studentIds,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/groups/$groupId/students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'studentIds': studentIds}),
      );

      if (response.statusCode == 200) {
        return Group.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to add students: ${response.body}');
      }
    } catch (e) {
      print('Error adding students to group: $e');
      throw Exception('Error adding students to group: $e');
    }
  }

  // Remove student from group (instructor only)
  static Future<Group> removeStudentFromGroup({
    required String groupId,
    required String studentId,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/groups/$groupId/students/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Group.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to remove student: ${response.body}');
      }
    } catch (e) {
      print('Error removing student from group: $e');
      throw Exception('Error removing student from group: $e');
    }
  }
}
