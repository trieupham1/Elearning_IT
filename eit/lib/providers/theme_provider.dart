// providers/theme_provider.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../config/theme.dart';

class ThemeProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  String _themeMode = 'light'; // 'light' or 'dark'
  bool _isSaving = false;
  bool _isInitialized = false;

  String get themeMode => _themeMode;
  bool get isSaving => _isSaving;
  bool get isInitialized => _isInitialized;

  ThemeData get themeData {
    if (_themeMode == 'dark') {
      return _buildDarkTheme();
    }
    return AppTheme.lightTheme; // Use the original light theme
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue.shade700,
      scaffoldBackgroundColor: const Color(
        0xFF1E1E1E,
      ), // Softer dark background
      colorScheme: const ColorScheme.dark(
        primary: Colors.blue,
        secondary: Colors.blueAccent,
        surface: Color(0xFF2D2D2D), // Slightly lighter for cards/surfaces
        background: Color(0xFF1E1E1E),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2D2D2D),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white),
      ),
    );
  }

  // Load theme from backend on app startup
  Future<void> loadTheme() async {
    try {
      final settings = await _settingsService.getSettings();
      _themeMode = settings.theme;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
      _themeMode = 'light'; // Default to light on error
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Set theme and save to backend
  Future<void> setTheme(String newTheme) async {
    if (_themeMode == newTheme || _isSaving) return;

    // Update UI immediately for better UX
    _themeMode = newTheme;
    notifyListeners();

    // Save to backend
    _isSaving = true;
    notifyListeners();

    try {
      final currentSettings = await _settingsService.getSettings();
      final updatedSettings = currentSettings.copyWith(theme: newTheme);
      await _settingsService.updateSettings(updatedSettings);
    } catch (e) {
      print('Error saving theme: $e');
      // Theme is already updated locally, so user sees the change even if save fails
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
