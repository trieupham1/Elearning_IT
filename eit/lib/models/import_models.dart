// Helper class for CSV import preview and validation
class ImportPreviewItem<T> {
  final T data;
  final ImportStatus status;
  final String? message;
  final int rowNumber;

  ImportPreviewItem({
    required this.data,
    required this.status,
    this.message,
    required this.rowNumber,
  });
}

enum ImportStatus {
  willBeAdded, // New item, will be imported
  alreadyExists, // Duplicate, will be skipped
  error, // Validation error
  updated, // Will update existing item
}

class ImportResult<T> {
  final int totalRows;
  final int added;
  final int skipped;
  final int errors;
  final List<ImportPreviewItem<T>> items;

  ImportResult({
    required this.totalRows,
    required this.added,
    required this.skipped,
    required this.errors,
    required this.items,
  });

  String get summary =>
      'Total: $totalRows | Added: $added | Skipped: $skipped | Errors: $errors';
}

// Semester CSV data model
class SemesterCsvData {
  final String code;
  final String name;

  SemesterCsvData({required this.code, required this.name});

  factory SemesterCsvData.fromCsvRow(List<String> row) {
    return SemesterCsvData(code: row[0].trim(), name: row[1].trim());
  }

  Map<String, dynamic> toJson() => {'code': code, 'name': name};
}

// Course CSV data model
class CourseCsvData {
  final String code;
  final String name;
  final int sessions; // 10 or 15
  final String semesterCode;

  CourseCsvData({
    required this.code,
    required this.name,
    required this.sessions,
    required this.semesterCode,
  });

  factory CourseCsvData.fromCsvRow(List<String> row) {
    return CourseCsvData(
      code: row[0].trim(),
      name: row[1].trim(),
      sessions: int.tryParse(row[2].trim()) ?? 15,
      semesterCode: row[3].trim(),
    );
  }

  String? validate() {
    if (code.isEmpty) return 'Code is required';
    if (name.isEmpty) return 'Name is required';
    if (sessions != 10 && sessions != 15) return 'Sessions must be 10 or 15';
    if (semesterCode.isEmpty) return 'Semester code is required';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'sessions': sessions,
    'semesterCode': semesterCode,
  };
}

// Group CSV data model
class GroupCsvData {
  final String name;
  final String courseCode;

  GroupCsvData({required this.name, required this.courseCode});

  factory GroupCsvData.fromCsvRow(List<String> row) {
    return GroupCsvData(name: row[0].trim(), courseCode: row[1].trim());
  }

  Map<String, dynamic> toJson() => {'name': name, 'courseCode': courseCode};
}

// Student CSV data model
class StudentCsvData {
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String studentId;
  final String password;
  final String? department;
  final String? phoneNumber;
  final int? year;

  StudentCsvData({
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.studentId,
    required this.password,
    this.department,
    this.phoneNumber,
    this.year,
  });

  factory StudentCsvData.fromCsvRow(List<String> row) {
    return StudentCsvData(
      username: row[0].trim(),
      email: row[1].trim(),
      firstName: row[2].trim(),
      lastName: row[3].trim(),
      studentId: row[4].trim(),
      password: row.length > 5 && row[5].trim().isNotEmpty
          ? row[5].trim()
          : 'student123',
      department: row.length > 6 && row[6].trim().isNotEmpty
          ? row[6].trim()
          : 'Information Technology',
      phoneNumber: row.length > 7 && row[7].trim().isNotEmpty
          ? row[7].trim()
          : null,
      year: row.length > 8 && row[8].trim().isNotEmpty
          ? int.tryParse(row[8].trim())
          : null,
    );
  }

  String? validate() {
    if (username.isEmpty) return 'Username is required';
    if (email.isEmpty) return 'Email is required';
    if (!email.contains('@')) return 'Invalid email format';
    if (firstName.isEmpty) return 'First name is required';
    if (lastName.isEmpty) return 'Last name is required';
    if (studentId.isEmpty) return 'Student ID is required';
    if (year != null && (year! < 1 || year! > 6))
      return 'Year must be between 1 and 6';
    return null;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'studentId': studentId,
      'password': password,
      'role': 'student',
    };

    if (department != null) json['department'] = department!;
    if (phoneNumber != null) json['phoneNumber'] = phoneNumber!;
    if (year != null) json['year'] = year!;

    return json;
  }

  @override
  String toString() {
    return '$firstName $lastName ($username) - $studentId';
  }
}

// Student-Group Assignment CSV data model
class StudentGroupAssignmentCsvData {
  final String studentId;
  final String groupName;
  final String courseCode;

  StudentGroupAssignmentCsvData({
    required this.studentId,
    required this.groupName,
    required this.courseCode,
  });

  factory StudentGroupAssignmentCsvData.fromCsvRow(List<String> row) {
    return StudentGroupAssignmentCsvData(
      studentId: row[0].trim(),
      groupName: row[1].trim(),
      courseCode: row[2].trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'groupName': groupName,
    'courseCode': courseCode,
  };
}
