import 'dart:convert';
import '../models/dashboard_summary.dart';
import 'api_service.dart';

class DashboardService {
  final ApiService _apiService = ApiService();

  /// Get complete dashboard summary for the current student
  Future<DashboardSummary> getDashboardSummary() async {
    try {
      print('📊 DashboardService: Fetching dashboard summary...');

      final response = await _apiService.get('/dashboard/student/summary');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ DashboardService: Dashboard summary loaded successfully');
        return DashboardSummary.fromJson(data);
      } else {
        print(
          '❌ DashboardService: Failed to load dashboard - Status: ${response.statusCode}',
        );
        throw Exception(
          'Failed to load dashboard summary: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ DashboardService: Error loading dashboard summary: $e');
      rethrow;
    }
  }

  /// Get filtered assignments (pending, submitted, late, graded)
  Future<List<Map<String, dynamic>>> getAssignments({String? status}) async {
    try {
      String endpoint = '/dashboard/student/assignments';
      if (status != null) {
        endpoint += '?status=$status';
      }

      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load assignments');
      }
    } catch (e) {
      print('Error loading assignments: $e');
      rethrow;
    }
  }

  /// Get quiz results with completion status
  Future<List<Map<String, dynamic>>> getQuizzes() async {
    try {
      final response = await _apiService.get('/dashboard/student/quizzes');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load quizzes');
      }
    } catch (e) {
      print('Error loading quizzes: $e');
      rethrow;
    }
  }

  /// Refresh dashboard data (useful for pull-to-refresh)
  Future<DashboardSummary> refreshDashboard() async {
    print('🔄 DashboardService: Refreshing dashboard data...');
    return getDashboardSummary();
  }

  /// Get instructor dashboard summary
  Future<Map<String, dynamic>> getInstructorDashboardSummary() async {
    try {
      print('📊 DashboardService: Fetching instructor dashboard summary...');

      final response = await _apiService.get('/dashboard/instructor/summary');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ DashboardService: Instructor dashboard summary loaded successfully',
        );
        return data;
      } else {
        print(
          '❌ DashboardService: Failed to load instructor dashboard - Status: ${response.statusCode}',
        );
        throw Exception(
          'Failed to load instructor dashboard summary: ${response.statusCode}',
        );
      }
    } catch (e) {
      print(
        '❌ DashboardService: Error loading instructor dashboard summary: $e',
      );
      rethrow;
    }
  }
}
