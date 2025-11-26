// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Section Header
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),

              // Theme Selector Card
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Light Mode'),
                      subtitle: const Text('Default light theme'),
                      value: 'light',
                      groupValue: themeProvider.themeMode,
                      onChanged: themeProvider.isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                themeProvider.setTheme(value);
                              }
                            },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Easy on the eyes in low light'),
                      value: 'dark',
                      groupValue: themeProvider.themeMode,
                      onChanged: themeProvider.isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                themeProvider.setTheme(value);
                              }
                            },
                    ),
                  ],
                ),
              ),

              // Saving indicator
              if (themeProvider.isSaving)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Saving...'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
