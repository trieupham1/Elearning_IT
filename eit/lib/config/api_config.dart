import '../utils/token_manager.dart';

class ApiConfig {
  // Production (deployed) URL - used for all platforms
  static const String _prodBase = 'https://elearning-it.onrender.com/api';

  // Optional compile-time override. Set with --dart-define=API_BASE=https://.../api
  static const String _envBase = String.fromEnvironment('API_BASE', defaultValue: '');

  // API endpoints (based on your actual backend routes)
  static const String auth = '/auth';
  static const String users = '/users';
  static const String semesters = '/semesters';
  static const String courses = '/courses';
  static const String groups = '/groups';
  static const String students = '/students';
  static const String announcements = '/announcements';
  static const String files = '/files';
  static const String notifications = '/notifications';

  // File upload endpoints
  static const String uploadFile = '/files/upload';
  static const String downloadFile = '/files';

  // Timeout duration
  static const Duration timeout = Duration(seconds: 30);

  // Helper method to get the correct base URL for different environments
  static String getBaseUrl() {
    // If compile-time override provided, use it.
    if (_envBase.isNotEmpty) return _envBase;

    // Use production URL for all platforms
    return _prodBase;
  }

  // Add baseUrl getter for backward compatibility
  static String get baseUrl => getBaseUrl();

  // Helper method to get headers with authorization token
  static Future<Map<String, String>> headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<String?> _getToken() async {
    try {
      return await TokenManager.getToken();
    } catch (e) {
      return null;
    }
  }
}
