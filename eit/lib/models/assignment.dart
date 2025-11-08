// models/assignment.dart
class Assignment {
  final String id;
  final String courseId;
  final String createdBy;
  final String createdByName;
  final String title;
  final String? description;
  final List<String> groupIds;
  final DateTime startDate;
  final DateTime deadline;
  final bool allowLateSubmission;
  final DateTime? lateDeadline;
  final int maxAttempts;
  final List<String> allowedFileTypes;
  final int maxFileSize;
  final List<AssignmentAttachment> attachments;
  final int points;
  final List<ViewRecord> viewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.id,
    required this.courseId,
    required this.createdBy,
    required this.createdByName,
    required this.title,
    this.description,
    required this.groupIds,
    required this.startDate,
    required this.deadline,
    required this.allowLateSubmission,
    this.lateDeadline,
    required this.maxAttempts,
    required this.allowedFileTypes,
    required this.maxFileSize,
    required this.attachments,
    required this.points,
    required this.viewedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['_id'] ?? json['id'] ?? '',
      courseId: json['courseId'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdByName: json['createdByName'] ?? 'Unknown',
      title: json['title'] ?? '',
      description: json['description'],
      groupIds: List<String>.from(json['groupIds'] ?? []),
      startDate: DateTime.parse(json['startDate']),
      deadline: DateTime.parse(json['deadline']),
      allowLateSubmission: json['allowLateSubmission'] ?? false,
      lateDeadline: json['lateDeadline'] != null
          ? DateTime.parse(json['lateDeadline'])
          : null,
      maxAttempts: json['maxAttempts'] ?? 1,
      allowedFileTypes: List<String>.from(json['allowedFileTypes'] ?? []),
      maxFileSize: json['maxFileSize'] ?? 10485760,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((a) => AssignmentAttachment.fromJson(a))
              .toList() ??
          [],
      points: json['points'] ?? 100,
      viewedBy:
          (json['viewedBy'] as List<dynamic>?)
              ?.map((v) => ViewRecord.fromJson(v))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'courseId': courseId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'title': title,
      'description': description,
      'groupIds': groupIds,
      'startDate': startDate.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'allowLateSubmission': allowLateSubmission,
      'lateDeadline': lateDeadline?.toIso8601String(),
      'maxAttempts': maxAttempts,
      'allowedFileTypes': allowedFileTypes,
      'maxFileSize': maxFileSize,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'points': points,
      'viewedBy': viewedBy.map((v) => v.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isAvailable {
    final now = DateTime.now();
    return now.isAfter(startDate) || now.isAtSameMomentAs(startDate);
  }

  bool get isOverdue {
    return DateTime.now().isAfter(deadline);
  }

  bool get canSubmitLate {
    if (!allowLateSubmission) return false;
    if (lateDeadline == null) return true;
    return DateTime.now().isBefore(lateDeadline!);
  }

  String get status {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 'Upcoming';
    if (now.isAfter(deadline)) {
      if (allowLateSubmission &&
          (lateDeadline == null || now.isBefore(lateDeadline!))) {
        return 'Late Submission Open';
      }
      return 'Closed';
    }
    return 'Open';
  }
}

class AssignmentAttachment {
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String mimeType;

  AssignmentAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
  });

  factory AssignmentAttachment.fromJson(Map<String, dynamic> json) {
    return AssignmentAttachment(
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
}

class ViewRecord {
  final String userId;
  final DateTime viewedAt;

  ViewRecord({required this.userId, required this.viewedAt});

  factory ViewRecord.fromJson(Map<String, dynamic> json) {
    return ViewRecord(
      userId: json['userId'] ?? '',
      viewedAt: DateTime.parse(json['viewedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'viewedAt': viewedAt.toIso8601String()};
  }
}
