// models/assignment_tracking.dart
import 'assignment_submission.dart';

class AssignmentTracking {
  final AssignmentInfo assignmentInfo;
  final TrackingStats stats;
  final List<StudentTrackingData> students;

  AssignmentTracking({
    required this.assignmentInfo,
    required this.stats,
    required this.students,
  });

  factory AssignmentTracking.fromJson(Map<String, dynamic> json) {
    return AssignmentTracking(
      assignmentInfo: AssignmentInfo.fromJson(json['assignment']),
      stats: TrackingStats.fromJson(json['stats']),
      students: (json['students'] as List<dynamic>)
          .map((s) => StudentTrackingData.fromJson(s))
          .toList(),
    );
  }
}

class AssignmentInfo {
  final String id;
  final String title;
  final int points;
  final DateTime deadline;

  AssignmentInfo({
    required this.id,
    required this.title,
    required this.points,
    required this.deadline,
  });

  factory AssignmentInfo.fromJson(Map<String, dynamic> json) {
    return AssignmentInfo(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      points: json['points'] ?? 100,
      deadline: DateTime.parse(json['deadline']),
    );
  }
}

class TrackingStats {
  final int totalStudents;
  final int submitted;
  final int notSubmitted;
  final int lateSubmissions;
  final int graded;
  final String? averageGrade;

  TrackingStats({
    required this.totalStudents,
    required this.submitted,
    required this.notSubmitted,
    required this.lateSubmissions,
    required this.graded,
    this.averageGrade,
  });

  factory TrackingStats.fromJson(Map<String, dynamic> json) {
    return TrackingStats(
      totalStudents: json['totalStudents'] ?? 0,
      submitted: json['submitted'] ?? 0,
      notSubmitted: json['notSubmitted'] ?? 0,
      lateSubmissions: json['lateSubmissions'] ?? 0,
      graded: json['graded'] ?? 0,
      averageGrade: json['averageGrade'],
    );
  }

  double get submissionRate {
    if (totalStudents == 0) return 0;
    return (submitted / totalStudents) * 100;
  }

  double get gradingProgress {
    if (submitted == 0) return 0;
    return (graded / submitted) * 100;
  }
}

class StudentTrackingData {
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? groupId;
  final String? groupName;
  final bool hasSubmitted;
  final int submissionCount;
  final LatestSubmissionData? latestSubmission;
  final List<SubmissionSummary> allSubmissions;

  StudentTrackingData({
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.groupId,
    this.groupName,
    required this.hasSubmitted,
    required this.submissionCount,
    this.latestSubmission,
    required this.allSubmissions,
  });

  factory StudentTrackingData.fromJson(Map<String, dynamic> json) {
    return StudentTrackingData(
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? 'Unknown',
      studentEmail: json['studentEmail'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      hasSubmitted: json['hasSubmitted'] ?? false,
      submissionCount: json['submissionCount'] ?? 0,
      latestSubmission: json['latestSubmission'] != null
          ? LatestSubmissionData.fromJson(json['latestSubmission'])
          : null,
      allSubmissions:
          (json['allSubmissions'] as List<dynamic>?)
              ?.map((s) => SubmissionSummary.fromJson(s))
              .toList() ??
          [],
    );
  }

  String get status {
    if (!hasSubmitted) return 'Not Submitted';
    if (latestSubmission == null) return 'Not Submitted';
    if (latestSubmission!.isLate) return 'Late';
    return 'Submitted';
  }

  String get gradeDisplay {
    if (latestSubmission == null || latestSubmission!.grade == null) {
      return '-';
    }
    return latestSubmission!.grade!.toStringAsFixed(1);
  }
}

class LatestSubmissionData {
  final int attemptNumber;
  final DateTime submittedAt;
  final bool isLate;
  final double? grade;
  final String status;
  final String? feedback;
  final List<SubmissionFile> files;

  LatestSubmissionData({
    required this.attemptNumber,
    required this.submittedAt,
    required this.isLate,
    this.grade,
    required this.status,
    this.feedback,
    this.files = const [],
  });

  factory LatestSubmissionData.fromJson(Map<String, dynamic> json) {
    return LatestSubmissionData(
      attemptNumber: json['attemptNumber'] ?? 1,
      submittedAt: DateTime.parse(json['submittedAt']),
      isLate: json['isLate'] ?? false,
      grade: json['grade']?.toDouble(),
      status: json['status'] ?? 'submitted',
      feedback: json['feedback'],
      files:
          (json['files'] as List<dynamic>?)
              ?.map((f) => SubmissionFile.fromJson(f))
              .toList() ??
          [],
    );
  }

  bool get isGraded => grade != null;
}

class SubmissionSummary {
  final String id;
  final int attemptNumber;
  final DateTime submittedAt;
  final bool isLate;
  final double? grade;
  final String status;

  SubmissionSummary({
    required this.id,
    required this.attemptNumber,
    required this.submittedAt,
    required this.isLate,
    this.grade,
    required this.status,
  });

  factory SubmissionSummary.fromJson(Map<String, dynamic> json) {
    return SubmissionSummary(
      id: json['id'] ?? '',
      attemptNumber: json['attemptNumber'] ?? 1,
      submittedAt: DateTime.parse(json['submittedAt']),
      isLate: json['isLate'] ?? false,
      grade: json['grade']?.toDouble(),
      status: json['status'] ?? 'submitted',
    );
  }
}
