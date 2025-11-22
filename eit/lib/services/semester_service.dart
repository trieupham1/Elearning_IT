import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/semester.dart';
import '../utils/token_manager.dart';
import 'api_service.dart';

class SemesterService extends ApiService {
  Future<List<Semester>> getSemesters() async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.semesters}'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Semester.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load semesters: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching semesters: $e');
    }
  }

  Future<Semester> getActiveSemester() async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.semesters}/active'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return Semester.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load active semester: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching active semester: $e');
    }
  }

  Future<SemesterStatistics> getSemesterStatistics(String semesterId) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.semesters}/$semesterId/statistics',
            ),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return SemesterStatistics.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load semester statistics: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching semester statistics: $e');
    }
  }
}

class SemesterStatistics {
  final String semesterId;
  final String semesterName;
  final int courses;
  final int groups;
  final int students;
  final int assignments;
  final int quizzes;

  SemesterStatistics({
    required this.semesterId,
    required this.semesterName,
    required this.courses,
    required this.groups,
    required this.students,
    required this.assignments,
    required this.quizzes,
  });

  factory SemesterStatistics.fromJson(Map<String, dynamic> json) {
    return SemesterStatistics(
      semesterId: json['semesterId'],
      semesterName: json['semesterName'],
      courses: json['courses'] ?? 0,
      groups: json['groups'] ?? 0,
      students: json['students'] ?? 0,
      assignments: json['assignments'] ?? 0,
      quizzes: json['quizzes'] ?? 0,
    );
  }
}
