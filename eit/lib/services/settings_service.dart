// services/settings_service.dart
import 'dart:convert';
import '../models/user_settings.dart';
import 'api_service.dart';

class SettingsService {
  final ApiService _apiService = ApiService();

  /// Get user settings
  Future<UserSettings> getSettings() async {
    try {
      final response = await _apiService.get('/settings');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserSettings.fromJson(data);
      } else {
        throw Exception('Failed to load settings');
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Return default settings if failed to load
      return UserSettings.defaultSettings();
    }
  }

  /// Update user settings
  Future<UserSettings> updateSettings(UserSettings settings) async {
    try {
      final response = await _apiService.put(
        '/settings',
        body: settings.toJson(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserSettings.fromJson(data);
      } else {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      print('Error updating settings: $e');
      rethrow;
    }
  }

  /// Reset settings to default
  Future<UserSettings> resetSettings() async {
    try {
      final response = await _apiService.post('/settings/reset', body: {});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserSettings.fromJson(data);
      } else {
        throw Exception('Failed to reset settings');
      }
    } catch (e) {
      print('Error resetting settings: $e');
      rethrow;
    }
  }
}
