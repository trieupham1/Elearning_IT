import 'dart:convert';
import 'api_service.dart';

class ClassworkItem {
  final String id;
  final String type; // 'assignment', 'quiz', 'material'
  final String courseId;
  final String title;
  final String? description;
  final DateTime? deadline; // for assignments
  final DateTime? closeDate; // for quizzes
  final DateTime createdAt;
  final int? maxAttempts;
  final bool? allowLateSubmission;
  final int? duration; // for quizzes (in seconds)
  final List<dynamic>? files; // for materials
  final bool? isCompleted; // for quizzes - whether student has completed it

  ClassworkItem({
    required this.id,
    required this.type,
    required this.courseId,
    required this.title,
    this.description,
    this.deadline,
    this.closeDate,
    required this.createdAt,
    this.maxAttempts,
    this.allowLateSubmission,
    this.duration,
    this.files,
    this.isCompleted,
  });

  factory ClassworkItem.fromJson(Map<String, dynamic> json) {
    return ClassworkItem(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      courseId: json['courseId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      closeDate: json['closeDate'] != null
          ? DateTime.parse(json['closeDate'])
          : null,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      maxAttempts: json['maxAttempts'],
      allowLateSubmission: json['allowLateSubmission'],
      duration: json['duration'],
      files: json['files'],
      isCompleted: json['isCompleted'],
    );
  }

  DateTime? get dueDate => deadline ?? closeDate;
}

class ClassworkService {
  final ApiService _apiService = ApiService();

  Future<List<ClassworkItem>> getClasswork({
    required String courseId,
    String? search,
    String? filter, // 'assignments', 'quizzes', 'materials'
  }) async {
    try {
      String endpoint = '/classwork/course/$courseId';
      List<String> queryParams = [];

      if (search != null && search.isNotEmpty) {
        queryParams.add('search=$search');
      }

      if (filter != null && filter.isNotEmpty) {
        queryParams.add('filter=$filter');
      }

      if (queryParams.isNotEmpty) {
        endpoint += '?${queryParams.join('&')}';
      }

      final response = await _apiService.get(endpoint);
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ClassworkItem.fromJson(json)).toList();
    } catch (e) {
      print('Error loading classwork: $e');
      return [];
    }
  }

  Future<ClassworkItem?> createAssignment({
    required String courseId,
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime deadline,
    bool allowLateSubmission = false,
    int maxAttempts = 1,
    List<String>? allowedFileTypes,
    int maxFileSize = 10485760,
  }) async {
    try {
      final response = await _apiService.post(
        '/classwork/assignments',
        body: {
          'courseId': courseId,
          'title': title,
          'description': description,
          'groupIds': [],
          'startDate': startDate.toIso8601String(),
          'deadline': deadline.toIso8601String(),
          'allowLateSubmission': allowLateSubmission,
          'maxAttempts': maxAttempts,
          'allowedFileTypes': allowedFileTypes ?? [],
          'maxFileSize': maxFileSize,
        },
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return ClassworkItem.fromJson({...json, 'type': 'assignment'});
      }
      return null;
    } catch (e) {
      print('Error creating assignment: $e');
      return null;
    }
  }

  Future<ClassworkItem?> createQuiz({
    required String courseId,
    required String title,
    String? description,
    required DateTime openDate,
    required DateTime closeDate,
    required int duration,
    int maxAttempts = 1,
  }) async {
    try {
      final response = await _apiService.post(
        '/classwork/quizzes',
        body: {
          'courseId': courseId,
          'title': title,
          'description': description,
          'groupIds': [],
          'openDate': openDate.toIso8601String(),
          'closeDate': closeDate.toIso8601String(),
          'duration': duration,
          'maxAttempts': maxAttempts,
        },
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return ClassworkItem.fromJson({...json, 'type': 'quiz'});
      }
      return null;
    } catch (e) {
      print('Error creating quiz: $e');
      return null;
    }
  }

  Future<ClassworkItem?> createMaterial({
    required String courseId,
    required String title,
    String? description,
    List<Map<String, dynamic>>? files,
    List<String>? links,
  }) async {
    try {
      final response = await _apiService.post(
        '/classwork/materials',
        body: {
          'courseId': courseId,
          'title': title,
          'description': description,
          'files': files ?? [],
          'links': links ?? [],
        },
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return ClassworkItem.fromJson({...json, 'type': 'material'});
      }
      return null;
    } catch (e) {
      print('Error creating material: $e');
      return null;
    }
  }
}
