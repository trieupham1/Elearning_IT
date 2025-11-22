// models/user_settings.dart
class UserSettings {
  final String id;
  final String userId;
  final String theme; // 'light' or 'dark'

  UserSettings({required this.id, required this.userId, required this.theme});

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      theme: json['theme'] ?? 'light',
    );
  }

  Map<String, dynamic> toJson() {
    return {'theme': theme};
  }

  UserSettings copyWith({String? theme}) {
    return UserSettings(id: id, userId: userId, theme: theme ?? this.theme);
  }

  static UserSettings defaultSettings() {
    return UserSettings(id: '', userId: '', theme: 'light');
  }
}
