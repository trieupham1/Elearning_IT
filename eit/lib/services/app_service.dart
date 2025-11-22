import 'auth_service.dart';
import 'course_service.dart';

class AppService {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  // Service instances
  final AuthService auth = AuthService();
  final CourseService courses = CourseService();

  // Initialize the app services
  Future<void> initialize() async {
    // Check if user is already logged in
    await auth.checkAuthStatus();
  }

  // Helper method to check if user is authenticated
  bool get isAuthenticated => auth.isLoggedIn;

  // Helper method to get current user
  get currentUser => auth.currentUser;

  // Logout from all services
  Future<void> logout() async {
    await auth.logout();
  }
}
