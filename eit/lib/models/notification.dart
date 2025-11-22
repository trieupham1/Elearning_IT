class NotificationModel {
  final String id;
  final String userId;
  final String
  type; // material, announcement, assignment, comment, message, quiz, submission, quiz_attempt, course_invite
  final String title;
  final String message;
  final Map<String, dynamic>?
  data; // Additional data (courseId, assignmentId, etc.)
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get icon based on notification type
  String get iconName {
    switch (type) {
      case 'material':
        return 'folder';
      case 'announcement':
        return 'campaign';
      case 'assignment':
        return 'assignment';
      case 'comment':
        return 'comment';
      case 'message':
        return 'message';
      case 'quiz':
        return 'quiz';
      case 'submission':
        return 'assignment_turned_in';
      case 'quiz_attempt':
        return 'assignment_turned_in';
      case 'course_invite':
        return 'school';
      default:
        return 'notifications';
    }
  }

  // Get color based on notification type
  String get colorHex {
    switch (type) {
      case 'material':
        return '#2196F3'; // Blue
      case 'announcement':
        return '#FF9800'; // Orange
      case 'assignment':
        return '#F44336'; // Red
      case 'comment':
        return '#9C27B0'; // Purple
      case 'message':
        return '#4CAF50'; // Green
      case 'quiz':
        return '#FF5722'; // Deep Orange
      case 'submission':
        return '#00BCD4'; // Cyan
      case 'quiz_attempt':
        return '#00BCD4'; // Cyan
      case 'course_invite':
        return '#3F51B5'; // Indigo
      default:
        return '#757575'; // Grey
    }
  }
}

// Notification types enum
enum NotificationType {
  material('material', 'Material'),
  announcement('announcement', 'Announcement'),
  assignment('assignment', 'Assignment'),
  comment('comment', 'Comment'),
  message('message', 'Message'),
  quiz('quiz', 'Quiz'),
  submission('submission', 'Submission'),
  quizAttempt('quiz_attempt', 'Quiz Attempt'),
  courseInvite('course_invite', 'Course Invitation'),
  courseJoinRequest('course_join_request', 'Course Join Request');

  final String value;
  final String displayName;

  const NotificationType(this.value, this.displayName);
}
