import 'dart:convert';
import 'dart:io';
import '../models/announcement.dart';
import '../models/announcement_tracking.dart';
import 'api_service.dart';

class AnnouncementService {
  final ApiService _apiService = ApiService();

  /// Get all announcements for a course
  /// Students see filtered announcements, instructors see all
  Future<List<Announcement>> getAnnouncements(String courseId) async {
    try {
      final response = await _apiService.get(
        '/announcements?courseId=$courseId',
      );

      print('Announcements Response Status: ${response.statusCode}');
      print('Announcements Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Announcement.fromJson(json)).toList();
      } else {
        print('Error: Status code ${response.statusCode}');
        throw ApiException('Failed to load announcements', response.statusCode);
      }
    } catch (e, stackTrace) {
      print('Error loading announcements: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get a single announcement by ID
  Future<Announcement> getAnnouncement(String announcementId) async {
    try {
      final response = await _apiService.get('/announcements/$announcementId');

      if (response.statusCode == 200) {
        return Announcement.fromJson(json.decode(response.body));
      } else {
        throw ApiException('Failed to load announcement', response.statusCode);
      }
    } catch (e) {
      print('Error loading announcement: $e');
      rethrow;
    }
  }

  /// Create a new announcement (instructor only)
  Future<Announcement> createAnnouncement({
    required String courseId,
    required String title,
    required String content,
    List<String>? groupIds,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final response = await _apiService.post(
        '/announcements',
        body: {
          'courseId': courseId,
          'title': title,
          'content': content,
          'groupIds': groupIds ?? [],
          'attachments': attachments ?? [],
        },
      );

      if (response.statusCode == 201) {
        return Announcement.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to create announcement',
          response.statusCode,
        );
      }
    } catch (e) {
      print('Error creating announcement: $e');
      rethrow;
    }
  }

  /// Update an existing announcement (instructor only)
  Future<Announcement> updateAnnouncement({
    required String announcementId,
    String? title,
    String? content,
    List<String>? groupIds,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;
      if (groupIds != null) body['groupIds'] = groupIds;
      if (attachments != null) body['attachments'] = attachments;

      final response = await _apiService.put(
        '/announcements/$announcementId',
        body: body,
      );

      if (response.statusCode == 200) {
        return Announcement.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to update announcement',
          response.statusCode,
        );
      }
    } catch (e) {
      print('Error updating announcement: $e');
      rethrow;
    }
  }

  /// Delete an announcement (instructor only)
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      final response = await _apiService.delete(
        '/announcements/$announcementId',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ApiException(
          'Failed to delete announcement',
          response.statusCode,
        );
      }
    } catch (e) {
      print('Error deleting announcement: $e');
      rethrow;
    }
  }

  /// Add a comment to an announcement
  Future<Announcement> addComment({
    required String announcementId,
    required String text,
  }) async {
    try {
      final response = await _apiService.post(
        '/announcements/$announcementId/comments',
        body: {'text': text},
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Announcement.fromJson(json.decode(response.body));
      } else {
        throw ApiException('Failed to add comment', response.statusCode);
      }
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  /// Track that a user viewed an announcement
  /// Prevents duplicate tracking - only records first view
  Future<void> trackView(String announcementId) async {
    try {
      final response = await _apiService.post(
        '/announcements/$announcementId/view',
        body: {},
      );

      if (response.statusCode != 200) {
        throw ApiException('Failed to track view', response.statusCode);
      }
    } catch (e) {
      print('Error tracking view: $e');
      // Don't rethrow - view tracking failure shouldn't block UI
    }
  }

  /// Track that a user downloaded a file
  /// Allows multiple downloads - tracks each download separately
  Future<void> trackDownload({
    required String announcementId,
    required String fileName,
  }) async {
    try {
      final response = await _apiService.post(
        '/announcements/$announcementId/download',
        body: {'fileName': fileName},
      );

      if (response.statusCode != 200) {
        throw ApiException('Failed to track download', response.statusCode);
      }
    } catch (e) {
      print('Error tracking download: $e');
      // Don't rethrow - download tracking failure shouldn't block download
    }
  }

  /// Get detailed tracking analytics (instructor only)
  /// Returns view and download statistics with student details
  Future<AnnouncementTracking> getTracking(String announcementId) async {
    try {
      final response = await _apiService.get(
        '/announcements/$announcementId/tracking',
      );

      if (response.statusCode == 200) {
        return AnnouncementTracking.fromJson(json.decode(response.body));
      } else {
        throw ApiException('Failed to load tracking data', response.statusCode);
      }
    } catch (e) {
      print('Error loading tracking data: $e');
      rethrow;
    }
  }

  /// Export tracking data as CSV (instructor only)
  /// Returns the CSV content as a string
  Future<String> exportTrackingCSV(String announcementId) async {
    try {
      final response = await _apiService.get(
        '/announcements/$announcementId/export',
      );

      if (response.statusCode == 200) {
        return response.body; // CSV content
      } else {
        throw ApiException(
          'Failed to export tracking data',
          response.statusCode,
        );
      }
    } catch (e) {
      print('Error exporting tracking data: $e');
      rethrow;
    }
  }

  /// Save CSV file to device (helper method)
  Future<File> saveCSVFile(String csvContent, String fileName) async {
    try {
      // Get downloads directory
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);
      return file;
    } catch (e) {
      print('Error saving CSV file: $e');
      rethrow;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
