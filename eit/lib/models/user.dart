import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role;
  final String? profilePicture;
  final String? studentId;
  final String? department;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.profilePicture,
    this.studentId,
    this.department,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim().isEmpty
      ? username
      : '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper to parse DateTime safely
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      username: json['username']?.toString() ?? 'user',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      profilePicture: json['profilePicture']?.toString(),
      studentId: json['studentId']?.toString(),
      department: json['department']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': profilePicture,
      'studentId': studentId,
      'department': department,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

@JsonSerializable()
class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class LoginResponse {
  final String token;
  final User user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

@JsonSerializable()
class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String? firstName;
  final String? lastName;
  final String role;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.firstName,
    this.lastName,
    required this.role,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}
