import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/import_models.dart';

class StudentService {
  // Get all students
  Future<List<User>> getStudents() async {
    final headers = await ApiConfig.headers();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/students'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to load students');
    }
  }

  // Get single student
  Future<User> getStudent(String id) async {
    final headers = await ApiConfig.headers();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/students/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to load student');
    }
  }

  // Create student
  Future<User> createStudent({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String studentId,
    String? password,
    String? phoneNumber,
  }) async {
    final headers = await ApiConfig.headers();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/students'),
      headers: headers,
      body: json.encode({
        'username': username,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'studentId': studentId,
        'password': password ?? 'student123',
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      }),
    );

    if (response.statusCode == 201) {
      return User.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to create student');
    }
  }

  // Update student
  Future<User> updateStudent({
    required String id,
    String? email,
    String? phoneNumber,
    String? password,
    int? year,
    String? bio,
  }) async {
    final headers = await ApiConfig.headers();
    final body = <String, dynamic>{};

    if (email != null) body['email'] = email;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (password != null) body['password'] = password;
    if (year != null) body['year'] = year;
    if (bio != null) body['bio'] = bio;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/students/$id'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to update student');
    }
  }

  // Delete student
  Future<void> deleteStudent(String id) async {
    final headers = await ApiConfig.headers();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/students/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to delete student');
    }
  }

  // CSV Import Preview
  Future<List<ImportPreviewItem<StudentCsvData>>> previewImport(
    List<StudentCsvData> students,
  ) async {
    final headers = await ApiConfig.headers();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/students/import/preview'),
      headers: headers,
      body: json.encode({'students': students.map((s) => s.toJson()).toList()}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> preview = data['preview'];

      return preview.map((item) {
        return ImportPreviewItem<StudentCsvData>(
          data: StudentCsvData(
            username: item['data']['username'],
            email: item['data']['email'],
            firstName: item['data']['firstName'],
            lastName: item['data']['lastName'],
            studentId: item['data']['studentId'],
            password: item['data']['password'] ?? 'student123',
            department: item['data']['department'],
            phoneNumber: item['data']['phoneNumber'],
            year: item['data']['year'],
          ),
          status: _parseStatus(item['status']),
          message: item['message'],
          rowNumber: item['rowNumber'],
        );
      }).toList();
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to preview import');
    }
  }

  // CSV Import Confirm
  Future<ImportResult<StudentCsvData>> confirmImport(
    List<ImportPreviewItem<StudentCsvData>> items,
  ) async {
    final headers = await ApiConfig.headers();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/students/import/confirm'),
      headers: headers,
      body: json.encode({
        'items': items
            .map(
              (item) => {
                'rowNumber': item.rowNumber,
                'status': item.status.name,
                'message': item.message,
                'data': item.data.toJson(),
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> resultItems = data['items'];

      return ImportResult<StudentCsvData>(
        totalRows: data['totalRows'],
        added: data['added'],
        skipped: data['skipped'],
        errors: data['errors'],
        items: resultItems.map((item) {
          return ImportPreviewItem<StudentCsvData>(
            data: StudentCsvData(
              username: item['data']['username'],
              email: item['data']['email'],
              firstName: item['data']['firstName'],
              lastName: item['data']['lastName'],
              studentId: item['data']['studentId'],
              password: item['data']['password'] ?? 'student123',
              department: item['data']['department'],
              phoneNumber: item['data']['phoneNumber'],
              year: item['data']['year'],
            ),
            status: _parseStatus(item['status']),
            message: item['message'],
            rowNumber: item['rowNumber'],
          );
        }).toList(),
      );
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to import students');
    }
  }

  ImportStatus _parseStatus(String status) {
    switch (status) {
      case 'willBeAdded':
        return ImportStatus.willBeAdded;
      case 'alreadyExists':
        return ImportStatus.alreadyExists;
      case 'error':
        return ImportStatus.error;
      case 'updated':
        return ImportStatus.updated;
      default:
        return ImportStatus.error;
    }
  }
}
