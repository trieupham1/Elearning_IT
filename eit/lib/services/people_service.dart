import 'dart:convert';
import '../models/user.dart';
import 'api_service.dart';

class PeopleService {
  final ApiService _apiService = ApiService();

  Future<Map<String, List<User>>> getCoursePeople(String courseId) async {
    try {
      final response = await _apiService.get('/courses/$courseId/people');

      print('People Response Status: ${response.statusCode}');
      print('People Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final List<dynamic> instructorsJson = data['instructors'] ?? [];
        final List<dynamic> studentsJson = data['students'] ?? [];

        final instructors = instructorsJson
            .map((json) => User.fromJson(json))
            .toList();
        final students = studentsJson
            .map((json) => User.fromJson(json))
            .toList();

        return {'instructors': instructors, 'students': students};
      } else {
        print('Error: Status code ${response.statusCode}');
        return {'instructors': [], 'students': []};
      }
    } catch (e, stackTrace) {
      print('Error loading course people: $e');
      print('Stack trace: $stackTrace');
      return {'instructors': [], 'students': []};
    }
  }
}
