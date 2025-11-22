// services/assignment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assignment.dart';
import '../models/assignment_submission.dart';
import '../models/assignment_tracking.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class AssignmentService {
  final String baseUrl = '${ApiConfig.baseUrl}/assignments';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ==================== CRUD Operations ====================

  /// Create a new assignment
  Future<Assignment> createAssignment({
    required String courseId,
    required String title,
    String? description,
    List<String>? groupIds,
    required DateTime startDate,
    required DateTime deadline,
    bool allowLateSubmission = false,
    DateTime? lateDeadline,
    int maxAttempts = 1,
    List<String>? allowedFileTypes,
    int maxFileSize = 10485760,
    List<AssignmentAttachment>? attachments,
    int points = 100,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'courseId': courseId,
        'title': title,
        'description': description,
        'groupIds': groupIds ?? [],
        'startDate': startDate.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'allowLateSubmission': allowLateSubmission,
        'lateDeadline': lateDeadline?.toIso8601String(),
        'maxAttempts': maxAttempts,
        'allowedFileTypes': allowedFileTypes ?? [],
        'maxFileSize': maxFileSize,
        'attachments': attachments?.map((a) => a.toJson()).toList() ?? [],
        'points': points,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return Assignment.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to create assignment');
      }
    } catch (e) {
      throw ApiException('Error creating assignment: $e');
    }
  }

  /// Get all assignments for a course
  Future<List<Assignment>> getAssignmentsByCourse(String courseId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/course/$courseId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Assignment.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to fetch assignments');
      }
    } catch (e) {
      throw ApiException('Error fetching assignments: $e');
    }
  }

  /// Get a single assignment by ID
  Future<Assignment> getAssignment(String assignmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$assignmentId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Assignment.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to fetch assignment');
      }
    } catch (e) {
      throw ApiException('Error fetching assignment: $e');
    }
  }

  /// Update an assignment
  Future<Assignment> updateAssignment(
    String assignmentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/$assignmentId'),
        headers: headers,
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return Assignment.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to update assignment');
      }
    } catch (e) {
      throw ApiException('Error updating assignment: $e');
    }
  }

  /// Delete an assignment
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/$assignmentId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to delete assignment');
      }
    } catch (e) {
      throw ApiException('Error deleting assignment: $e');
    }
  }

  // ==================== Submission Operations ====================

  /// Submit an assignment
  Future<AssignmentSubmission> submitAssignment({
    required String assignmentId,
    required List<SubmissionFile> files,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'files': files.map((f) => f.toJson()).toList()});

      final response = await http.post(
        Uri.parse('$baseUrl/$assignmentId/submit'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return AssignmentSubmission.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to submit assignment');
      }
    } catch (e) {
      throw ApiException('Error submitting assignment: $e');
    }
  }

  /// Get student's own submissions for an assignment
  Future<List<AssignmentSubmission>> getMySubmissions(
    String assignmentId,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$assignmentId/my-submissions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AssignmentSubmission.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to fetch submissions');
      }
    } catch (e) {
      throw ApiException('Error fetching submissions: $e');
    }
  }

  /// Grade a submission (Instructor only)
  Future<AssignmentSubmission> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'grade': grade, 'feedback': feedback ?? ''});

      final response = await http.post(
        Uri.parse('$baseUrl/submissions/$submissionId/grade'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return AssignmentSubmission.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to grade submission');
      }
    } catch (e) {
      throw ApiException('Error grading submission: $e');
    }
  }

  // ==================== Tracking & Analytics ====================

  /// Get tracking data for an assignment (Instructor only)
  Future<AssignmentTracking> getTrackingData(String assignmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$assignmentId/tracking'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return AssignmentTracking.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to fetch tracking data');
      }
    } catch (e) {
      throw ApiException('Error fetching tracking data: $e');
    }
  }

  /// Download tracking data as CSV (Instructor only)
  Future<String> exportTrackingCSV(String assignmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$assignmentId/export-csv'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to export CSV');
      }
    } catch (e) {
      throw ApiException('Error exporting CSV: $e');
    }
  }

  /// Download all assignments for a course as CSV (Instructor only)
  Future<String> exportCourseAssignmentsCSV(String courseId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/course/$courseId/export-csv'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        final error = jsonDecode(response.body);
        throw ApiException(error['message'] ?? 'Failed to export course CSV');
      }
    } catch (e) {
      throw ApiException('Error exporting course CSV: $e');
    }
  }

  // ==================== Helper Methods ====================

  /// Check if user can submit based on assignment rules
  bool canSubmit(Assignment assignment, int currentAttempts) {
    // Check if assignment is available
    if (!assignment.isAvailable) return false;

    // Check if deadline passed
    if (assignment.isOverdue) {
      if (!assignment.allowLateSubmission) return false;
      if (!assignment.canSubmitLate) return false;
    }

    // Check attempt limit
    if (currentAttempts >= assignment.maxAttempts) return false;

    return true;
  }

  /// Get time remaining until deadline
  String getTimeRemaining(DateTime deadline) {
    final now = DateTime.now();
    if (now.isAfter(deadline)) return 'Overdue';

    final diff = deadline.difference(now);
    if (diff.inDays > 0) return '${diff.inDays} days left';
    if (diff.inHours > 0) return '${diff.inHours} hours left';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes left';
    return 'Less than a minute';
  }

  /// Format file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Validate file before submission
  bool validateFile(
    SubmissionFile file,
    List<String> allowedTypes,
    int maxSize,
  ) {
    // Check size
    if (file.fileSize > maxSize) return false;

    // Check type if restrictions exist
    if (allowedTypes.isNotEmpty) {
      final extension = '.${file.fileName.split('.').last.toLowerCase()}';
      if (!allowedTypes.contains(extension)) return false;
    }

    return true;
  }
}
