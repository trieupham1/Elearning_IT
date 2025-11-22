import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class FileService {
  final ApiService _apiService = ApiService();

  /// Pick a file using file_picker
  /// Returns PlatformFile or null if cancelled
  Future<PlatformFile?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      rethrow;
    }
  }

  /// Upload a PlatformFile to the server
  /// Returns a map with 'fileName', 'fileUrl', 'fileSize', 'mimeType'
  Future<Map<String, dynamic>> uploadFile(PlatformFile file) async {
    try {
      List<int> fileBytes;

      // Handle web vs mobile/desktop
      if (file.bytes != null) {
        // Web platform - use bytes directly
        fileBytes = file.bytes!;
      } else if (file.path != null) {
        // Mobile/Desktop - read file from path
        final ioFile = File(file.path!);
        if (!await ioFile.exists()) {
          throw Exception('File not found at path: ${file.path}');
        }
        fileBytes = await ioFile.readAsBytes();
      } else {
        throw Exception(
          'Unable to access file data (no bytes or path available)',
        );
      }

      // Get auth token
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${await _getBaseUrl()}/files/upload'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add file using bytes
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: file.name),
      );

      print('📤 Uploading file: ${file.name} (${fileBytes.length} bytes)');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Return consistent format
        return {
          'fileName': data['fileName'] ?? file.name,
          'fileUrl':
              data['fileUrl'] ?? data['url'] ?? '/api/files/${data['fileId']}',
          'fileSize': data['fileSize'] ?? fileBytes.length,
          'mimeType': data['mimeType'] ?? 'application/octet-stream',
        };
      } else {
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error uploading file: $e');
      rethrow;
    }
  }

  /// Upload multiple files
  Future<List<Map<String, dynamic>>> uploadFiles(
    List<PlatformFile> files,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (var file in files) {
      try {
        final result = await uploadFile(file);
        results.add(result);
      } catch (e) {
        print('Failed to upload ${file.name}: $e');
        // Continue with other files
      }
    }

    return results;
  }

  /// Delete a file from the server (if endpoint exists)
  Future<void> deleteFile(String fileUrl) async {
    try {
      // Note: Implement this when backend has delete endpoint
      // For now, files are kept on server
      print('File delete not implemented: $fileUrl');
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

  /// Download a file from the server
  Future<void> downloadFile(String fileId, String fileName) async {
    try {
      final url = '${await _getBaseUrl()}/files/$fileId';
      // For now, just construct the download URL
      // In a real app, you might want to use url_launcher or download the file
      print('Download file from: $url');
      // TODO: Implement actual download logic
    } catch (e) {
      print('Error downloading file: $e');
      rethrow;
    }
  }

  Future<String> _getBaseUrl() async {
    // Use the same base URL configuration as ApiService
    return ApiConfig.getBaseUrl();
  }
}
