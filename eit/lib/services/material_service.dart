import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/material.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class MaterialService extends ApiService {
  // Get all materials for a course
  Future<List<Material>> getMaterialsForCourse(String courseId) async {
    final response = await get('/materials/course/$courseId');
    final data = parseResponse(response);
    final List<dynamic> materials = data is List ? data as List<dynamic> : <dynamic>[];
    return materials.map((json) => Material.fromJson(json)).toList();
  }

  // Get single material
  Future<Material> getMaterial(String materialId) async {
    final response = await get('/materials/$materialId');
    final data = parseResponse(response);
    return Material.fromJson(data);
  }

  // Create new material
  Future<Material> createMaterial(Map<String, dynamic> materialData) async {
    final response = await post('/materials', body: materialData);
    final data = parseResponse(response);
    return Material.fromJson(data);
  }

  // Update material
  Future<Material> updateMaterial(String materialId, Map<String, dynamic> materialData) async {
    final response = await put('/materials/$materialId', body: materialData);
    final data = parseResponse(response);
    return Material.fromJson(data);
  }

  // Delete material
  Future<void> deleteMaterial(String materialId) async {
    await delete('/materials/$materialId');
  }

  // Upload file for material
  Future<Map<String, dynamic>> uploadMaterialFile(File file) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw ApiException('No authentication token found');
      }

      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/files/upload'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return parseResponse(response);
      } else {
        throw ApiException('Failed to upload file: ${response.body}', response.statusCode);
      }
    } catch (e) {
      throw ApiException('Error uploading file: $e');
    }
  }

  // Upload file bytes for material (web support)
  Future<Map<String, dynamic>> uploadMaterialFileBytes(Uint8List bytes, String fileName) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw ApiException('No authentication token found');
      }

      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/files/upload'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return parseResponse(response);
      } else {
        throw ApiException('Failed to upload file: ${response.body}', response.statusCode);
      }
    } catch (e) {
      throw ApiException('Error uploading file: $e');
    }
  }

  // Track material view
  Future<void> trackMaterialView(String materialId) async {
    await post('/materials/$materialId/view');
  }

  // Track material download
  Future<void> trackMaterialDownload(String materialId, String fileName) async {
    await post('/materials/$materialId/download', body: {
      'fileName': fileName,
    });
  }

  // Get material tracking data (instructor only)
  Future<Map<String, dynamic>> getMaterialTracking(String materialId) async {
    final response = await get('/materials/$materialId/analytics');
    return parseResponse(response);
  }

  // Get all materials tracking for course (instructor only)
  Future<List<Map<String, dynamic>>> getCourseMaterialsTracking(String courseId) async {
    final response = await get('/materials/course/$courseId/analytics');
    final data = parseResponse(response);
    final List<Map<String, dynamic>> result = [];
    
    // Handle both direct object and list responses
    if (data.containsKey('materials')) {
      final materialsData = data['materials'];
      if (materialsData is List) {
        for (final item in materialsData) {
          if (item is Map<String, dynamic>) {
            result.add(item);
          }
        }
      }
    }
    return result;
  }

  // Export material tracking as CSV
  Future<String> exportMaterialTracking(String materialId) async {
    final response = await get('/materials/$materialId/analytics');
    return response.body;
  }

  // Export all course materials tracking as CSV
  Future<String> exportCourseTracking(String courseId) async {
    final response = await get('/classwork/materials/course/$courseId/export');
    return response.body;
  }
}