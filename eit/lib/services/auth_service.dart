import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/user.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService extends ApiService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      print('🔐 Attempting login for: ${request.username}');
      
      // Test connection first
      final isConnected = await testConnection();
      if (!isConnected) {
        throw ApiException('Cannot connect to server. Please check if the backend is running on ${ApiConfig.getBaseUrl()}');
      }
      
      final response = await post(
        '${ApiConfig.auth}/login',
        body: request.toJson(),
        withAuth: false,
      );

      final data = parseResponse(response);
      print('🔐 Login response data: $data');
      
      final loginResponse = LoginResponse.fromJson(data);

      // Save token and user data
      await saveToken(loginResponse.token);
      _currentUser = loginResponse.user;

      print('✅ Login successful for: ${loginResponse.user.username}');
      return loginResponse;
    } catch (e) {
      print('❌ Login failed: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Login failed: $e');
    }
  }

  Future<User> register(RegisterRequest request) async {
    try {
      final response = await post(
        '${ApiConfig.auth}/register',
        body: request.toJson(),
        withAuth: false,
      );

      final data = parseResponse(response);
      return User.fromJson(data['user']);
    } catch (e) {
      throw ApiException('Registration failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      // Call backend logout endpoint if needed
      await post('${ApiConfig.auth}/logout');
    } catch (e) {
      // Continue with local logout even if server call fails
    } finally {
      // Clear local data
      await clearToken();
      _currentUser = null;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      if (_currentUser != null) {
        return _currentUser;
      }

      final token = await getToken();
      if (token == null) {
        return null;
      }

      final response = await get('${ApiConfig.auth}/me');
      final data = parseResponse(response);
      _currentUser = User.fromJson(data);

      return _currentUser;
    } catch (e) {
      // If token is invalid, clear it
      await clearToken();
      _currentUser = null;
      return null;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await put(
        '${ApiConfig.auth}/change-password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } catch (e) {
      throw ApiException('Failed to change password: $e');
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      await post(
        '${ApiConfig.auth}/forgot-password',
        body: {'email': email},
        withAuth: false,
      );
    } catch (e) {
      throw ApiException('Failed to request password reset: $e');
    }
  }

  Future<User> updateProfile(Map<String, dynamic> userData) async {
    try {
      final response = await put('${ApiConfig.users}/profile', body: userData);
      final data = parseResponse(response);
      _currentUser = User.fromJson(data);
      return _currentUser!;
    } catch (e) {
      throw ApiException('Failed to update profile: $e');
    }
  }

  Future<User> updateProfilePicture(PlatformFile file) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw ApiException('No authentication token found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.getBaseUrl()}/users/profile-picture'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Handle web vs mobile/desktop platforms
      if (file.bytes != null) {
        // Web platform - use bytes
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePicture',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (file.path != null) {
        // Mobile/Desktop - use file path
        request.files.add(
          await http.MultipartFile.fromPath('profilePicture', file.path!),
        );
      } else {
        throw ApiException('Unable to access file data');
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('🔍 Profile picture upload response status: ${response.statusCode}');
      print('📄 Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = parseResponse(response);
        print('📦 Parsed response data: $data');
        print('👤 User data from response: ${data['user']}');
        _currentUser = User.fromJson(data['user']);
        return _currentUser!;
      } else {
        final errorData = parseResponse(response);
        throw ApiException(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
      throw ApiException('Failed to update profile picture: $e');
    }
  }

  Future<bool> checkAuthStatus() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // Forgot Password - Send reset email
  Future<void> forgotPassword(String email) async {
    try {
      print('🔐 Requesting password reset for: $email');

      // Use longer timeout for email sending (60 seconds)
      final headers = await ApiConfig.headers();
      final url = '${ApiConfig.getBaseUrl()}${ApiConfig.auth}/forgot-password';

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode({'email': email}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        parseResponse(response);
        print('✅ Password reset email sent to: $email');
      } else {
        final data = parseResponse(response);
        throw ApiException(data['message'] ?? 'Failed to send reset email', response.statusCode);
      }
    } catch (e) {
      print('❌ Forgot password failed: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to send reset email: $e');
    }
  }

  // Reset Password - Update password with verification code
  Future<void> resetPassword(String email, String code, String newPassword) async {
    try {
      print('🔐 Resetting password with verification code');
      
      final response = await post(
        '${ApiConfig.auth}/reset-password',
        body: {
          'email': email,
          'code': code,
          'newPassword': newPassword,
        },
        withAuth: false,
      );

      parseResponse(response);
      print('✅ Password reset successful');
    } catch (e) {
      print('❌ Password reset failed: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to reset password: $e');
    }
  }

  // Legacy method for token-based reset (backward compatibility)
  Future<void> resetPasswordWithToken(String token, String newPassword) async {
    try {
      print('🔐 Resetting password with token (legacy)');
      
      final response = await post(
        '${ApiConfig.auth}/reset-password-token',
        body: {
          'token': token,
          'newPassword': newPassword,
        },
        withAuth: false,
      );

      parseResponse(response);
      print('✅ Password reset successful');
    } catch (e) {
      print('❌ Password reset failed: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to reset password: $e');
    }
  }
}
