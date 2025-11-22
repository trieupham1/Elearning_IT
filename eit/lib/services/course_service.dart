import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/course.dart';
import '../utils/token_manager.dart';
import 'api_service.dart';

class CourseService extends ApiService {
  Future<List<Course>> getCourses({String? semester}) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final url = semester != null
          ? '${ApiConfig.baseUrl}${ApiConfig.courses}?semester=$semester'
          : '${ApiConfig.baseUrl}${ApiConfig.courses}';

      final headers = await ApiConfig.headers();

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load courses: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching courses: $e');
    }
  }

  Future<Course> getCourseById(String id) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.courses}/$id'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return Course.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load course: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching course: $e');
    }
  }

  Future<Course> createCourse({
    required String code,
    required String name,
    required String description,
    required String semesterId,
    required int sessions,
    required String color,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.courses}'),
            headers: headers,
            body: json.encode({
              'code': code,
              'name': name,
              'description': description,
              'semester': semesterId,
              'sessions': sessions,
              'color': color,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        return Course.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create course: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating course: $e');
    }
  }

  Future<Course> updateCourse({
    required String id,
    required String code,
    required String name,
    required String description,
    required String semesterId,
    required int sessions,
    required String color,
  }) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.courses}/$id'),
            headers: headers,
            body: json.encode({
              'code': code,
              'name': name,
              'description': description,
              'semester': semesterId,
              'sessions': sessions,
              'color': color,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return Course.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update course: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating course: $e');
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.courses}/$id'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete course: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting course: $e');
    }
  }
}
