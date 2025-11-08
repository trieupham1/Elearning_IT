// models/assignment_submission.dart
class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? groupId;
  final String? groupName;
  final int attemptNumber;
  final List<SubmissionFile> files;
  final DateTime submittedAt;
  final bool isLate;
  final double? grade;
  final String? feedback;
  final DateTime? gradedAt;
  final String? gradedBy;
  final String? gradedByName;
  final String status; // 'submitted', 'graded', 'returned'
  final DateTime createdAt;
  final DateTime updatedAt;

  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.groupId,
    this.groupName,
    required this.attemptNumber,
    required this.files,
    required this.submittedAt,
    required this.isLate,
    this.grade,
    this.feedback,
    this.gradedAt,
    this.gradedBy,
    this.gradedByName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmission(
      id: json['_id'] ?? json['id'] ?? '',
      assignmentId: json['assignmentId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? 'Unknown',
      studentEmail: json['studentEmail'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      attemptNumber: json['attemptNumber'] ?? 1,
      files:
          (json['files'] as List<dynamic>?)
              ?.map((f) => SubmissionFile.fromJson(f))
              .toList() ??
          [],
      submittedAt: DateTime.parse(json['submittedAt']),
      isLate: json['isLate'] ?? false,
      grade: json['grade']?.toDouble(),
      feedback: json['feedback'],
      gradedAt: json['gradedAt'] != null
          ? DateTime.parse(json['gradedAt'])
          : null,
      gradedBy: json['gradedBy'],
      gradedByName: json['gradedByName'],
      status: json['status'] ?? 'submitted',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'assignmentId': assignmentId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'groupId': groupId,
      'groupName': groupName,
      'attemptNumber': attemptNumber,
      'files': files.map((f) => f.toJson()).toList(),
      'submittedAt': submittedAt.toIso8601String(),
      'isLate': isLate,
      'grade': grade,
      'feedback': feedback,
      'gradedAt': gradedAt?.toIso8601String(),
      'gradedBy': gradedBy,
      'gradedByName': gradedByName,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isGraded => grade != null;

  String get statusDisplay {
    if (isGraded) return 'Graded';
    if (isLate) return 'Submitted Late';
    return 'Submitted';
  }
}

class SubmissionFile {
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String mimeType;

  SubmissionFile({
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
  });

  factory SubmissionFile.fromJson(Map<String, dynamic> json) {
    return SubmissionFile(
      fileName: json['fileName'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
