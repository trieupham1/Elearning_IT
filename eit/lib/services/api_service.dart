import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message';
}

class ApiService {
  static const String _tokenKey = 'auth_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _getHeaders([bool withAuth = true]) async {
    final headers = await ApiConfig.headers();

    if (withAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<http.Response> get(String endpoint, {bool withAuth = true}) async {
    try {
      final headers = await _getHeaders(withAuth);
      final url = '${ApiConfig.getBaseUrl()}$endpoint';

      print('🌐 GET Request: $url');
      print('📋 Headers: $headers');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      print('📥 Response Status: ${response.statusCode}');
      print(
        '📥 Response Body: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}',
      );

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw ApiException(
        'No internet connection - check if backend server is running on ${ApiConfig.getBaseUrl()}',
      );
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw ApiException('HTTP error occurred');
    } catch (e) {
      print('❌ Request Exception: $e');
      throw ApiException('Request failed: $e');
    }
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(withAuth);
      final url = '${ApiConfig.getBaseUrl()}$endpoint';
      final bodyString = body != null ? json.encode(body) : null;

      print('🌐 POST Request: $url');
      print('📋 Headers: $headers');
      print('📤 Body: $bodyString');

      final response = await http
          .post(Uri.parse(url), headers: headers, body: bodyString)
          .timeout(ApiConfig.timeout);

      print('📥 Response Status: ${response.statusCode}');
      print(
        '📥 Response Body: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}',
      );

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw ApiException(
        'No internet connection - check if backend server is running on ${ApiConfig.getBaseUrl()}',
      );
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw ApiException('HTTP error occurred');
    } catch (e) {
      print('❌ Request Exception: $e');
      throw ApiException('Request failed: $e');
    }
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(withAuth);
      final url = '${ApiConfig.getBaseUrl()}$endpoint';
      final response = await http
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException {
      throw ApiException('HTTP error occurred');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }
  }

  Future<http.Response> delete(String endpoint, {bool withAuth = true}) async {
    try {
      final headers = await _getHeaders(withAuth);
      final url = '${ApiConfig.getBaseUrl()}$endpoint';
      final response = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on HttpException {
      throw ApiException('HTTP error occurred');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }
  }

  http.Response _handleResponse(http.Response response) {
    print('🔍 Handling response: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    String message = 'Request failed (${response.statusCode})';
    try {
      if (response.body.isNotEmpty) {
        final body = json.decode(response.body);
        if (body is Map<String, dynamic>) {
          message = body['message'] ?? body['error'] ?? message;
        } else if (body is String) {
          message = body;
        }
      }
    } catch (e) {
      print('⚠️ Failed to parse error response: $e');
      // If JSON parsing fails, include the raw response in the message
      if (response.body.isNotEmpty) {
        message = '$message - Raw response: ${response.body}';
      }
    }

    print('❌ API Error: $message');
    throw ApiException(message, response.statusCode);
  }

  Map<String, dynamic> parseResponse(http.Response response) {
    try {
      if (response.body.isEmpty) return {};
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (e) {
      throw ApiException('Failed to parse response');
    }
  }

  // Test connectivity to the backend server
  Future<bool> testConnection() async {
    try {
      print('🔄 Testing connection to ${ApiConfig.getBaseUrl()}...');

      final response = await http
          .get(
            Uri.parse('${ApiConfig.getBaseUrl()}/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      print('✅ Connection test result: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }
}
