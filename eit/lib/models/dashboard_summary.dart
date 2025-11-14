class DashboardSummary {
  final int totalCourses;
  final AssignmentStats assignmentStats;
  final QuizStats quizStats;
  final List<UpcomingDeadline> upcomingDeadlines;
  final List<RecentActivity> recentActivities;
  final double overallProgress;
  final int notificationCount;

  DashboardSummary({
    required this.totalCourses,
    required this.assignmentStats,
    required this.quizStats,
    required this.upcomingDeadlines,
    required this.recentActivities,
    required this.overallProgress,
    this.notificationCount = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalCourses: json['totalCourses'] ?? 0,
      assignmentStats: AssignmentStats.fromJson(json['assignmentStats'] ?? {}),
      quizStats: QuizStats.fromJson(json['quizStats'] ?? {}),
      upcomingDeadlines:
          (json['upcomingDeadlines'] as List<dynamic>?)
              ?.map((e) => UpcomingDeadline.fromJson(e))
              .toList() ??
          [],
      recentActivities:
          (json['recentActivities'] as List<dynamic>?)
              ?.map((e) => RecentActivity.fromJson(e))
              .toList() ??
          [],
      overallProgress: (json['overallProgress'] ?? 0.0).toDouble(),
      notificationCount: json['notificationCount'] ?? 0,
    );
  }

  // Mock data for testing
  static DashboardSummary mock() {
    return DashboardSummary(
      totalCourses: 5,
      assignmentStats: AssignmentStats.mock(),
      quizStats: QuizStats.mock(),
      upcomingDeadlines: UpcomingDeadline.mockList(),
      recentActivities: RecentActivity.mockList(),
      overallProgress: 72.5,
      notificationCount: 3,
    );
  }
}

class AssignmentStats {
  final int total;
  final int submitted;
  final int pending;
  final int late;
  final int graded;

  AssignmentStats({
    required this.total,
    required this.submitted,
    required this.pending,
    required this.late,
    required this.graded,
  });

  factory AssignmentStats.fromJson(Map<String, dynamic> json) {
    return AssignmentStats(
      total: json['total'] ?? 0,
      submitted: json['submitted'] ?? 0,
      pending: json['pending'] ?? 0,
      late: json['late'] ?? 0,
      graded: json['graded'] ?? 0,
    );
  }

  static AssignmentStats mock() {
    return AssignmentStats(
      total: 15,
      submitted: 10,
      pending: 3,
      late: 2,
      graded: 8,
    );
  }
}

class QuizStats {
  final int total;
  final int completed;
  final int pending;
  final double averageScore;
  final List<QuizScore> recentScores;

  QuizStats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.averageScore,
    required this.recentScores,
  });

  factory QuizStats.fromJson(Map<String, dynamic> json) {
    return QuizStats(
      total: json['total'] ?? 0,
      completed: json['completed'] ?? 0,
      pending: json['pending'] ?? 0,
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
      recentScores:
          (json['recentScores'] as List<dynamic>?)
              ?.map((e) => QuizScore.fromJson(e))
              .toList() ??
          [],
    );
  }

  static QuizStats mock() {
    return QuizStats(
      total: 8,
      completed: 6,
      pending: 2,
      averageScore: 85.5,
      recentScores: QuizScore.mockList(),
    );
  }
}

class QuizScore {
  final String quizId;
  final String quizTitle;
  final String courseTitle;
  final double score;
  final double maxScore;
  final DateTime completedAt;

  QuizScore({
    required this.quizId,
    required this.quizTitle,
    required this.courseTitle,
    required this.score,
    required this.maxScore,
    required this.completedAt,
  });

  double get percentage => (score / maxScore) * 100;

  factory QuizScore.fromJson(Map<String, dynamic> json) {
    return QuizScore(
      quizId: json['quizId'] ?? '',
      quizTitle: json['quizTitle'] ?? '',
      courseTitle: json['courseTitle'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      maxScore: (json['maxScore'] ?? 100.0).toDouble(),
      completedAt: DateTime.parse(
        json['completedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static List<QuizScore> mockList() {
    return [
      QuizScore(
        quizId: '1',
        quizTitle: 'Midterm Exam',
        courseTitle: 'Data Structures',
        score: 85,
        maxScore: 100,
        completedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      QuizScore(
        quizId: '2',
        quizTitle: 'Chapter 5 Quiz',
        courseTitle: 'Algorithms',
        score: 92,
        maxScore: 100,
        completedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      QuizScore(
        quizId: '3',
        quizTitle: 'Final Assessment',
        courseTitle: 'Web Development',
        score: 78,
        maxScore: 100,
        completedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ];
  }
}

class UpcomingDeadline {
  final String id;
  final String title;
  final String courseTitle;
  final String type; // 'assignment' or 'quiz'
  final DateTime deadline;
  final String status; // 'pending', 'submitted', 'late'

  UpcomingDeadline({
    required this.id,
    required this.title,
    required this.courseTitle,
    required this.type,
    required this.deadline,
    required this.status,
  });

  int get daysUntilDue => deadline.difference(DateTime.now()).inDays;
  int get hoursUntilDue => deadline.difference(DateTime.now()).inHours;
  bool get isOverdue => DateTime.now().isAfter(deadline);
  bool get isUrgent => hoursUntilDue < 24 && !isOverdue;

  factory UpcomingDeadline.fromJson(Map<String, dynamic> json) {
    return UpcomingDeadline(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      courseTitle: json['courseTitle'] ?? '',
      type: json['type'] ?? 'assignment',
      deadline: DateTime.parse(
        json['deadline'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'pending',
    );
  }

  static List<UpcomingDeadline> mockList() {
    final now = DateTime.now();
    return [
      UpcomingDeadline(
        id: '1',
        title: 'Lab Report #3',
        courseTitle: 'Physics',
        type: 'assignment',
        deadline: now.add(const Duration(hours: 18)),
        status: 'pending',
      ),
      UpcomingDeadline(
        id: '2',
        title: 'Chapter 8 Quiz',
        courseTitle: 'Data Structures',
        type: 'quiz',
        deadline: now.add(const Duration(days: 2)),
        status: 'pending',
      ),
      UpcomingDeadline(
        id: '3',
        title: 'Project Proposal',
        courseTitle: 'Software Engineering',
        type: 'assignment',
        deadline: now.add(const Duration(days: 5)),
        status: 'pending',
      ),
      UpcomingDeadline(
        id: '4',
        title: 'Final Exam',
        courseTitle: 'Algorithms',
        type: 'quiz',
        deadline: now.add(const Duration(days: 10)),
        status: 'pending',
      ),
      UpcomingDeadline(
        id: '5',
        title: 'Homework Set 5',
        courseTitle: 'Mathematics',
        type: 'assignment',
        deadline: now.add(const Duration(days: 14)),
        status: 'pending',
      ),
    ];
  }
}

class RecentActivity {
  final String id;
  final String title;
  final String type; // 'assignment_graded', 'quiz_completed', 'announcement'
  final String courseTitle;
  final String message;
  final DateTime timestamp;
  final double? score;

  RecentActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.courseTitle,
    required this.message,
    required this.timestamp,
    this.score,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      courseTitle: json['courseTitle'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
    );
  }

  static List<RecentActivity> mockList() {
    return [
      RecentActivity(
        id: '1',
        title: 'Lab Report #2 Graded',
        type: 'assignment_graded',
        courseTitle: 'Physics',
        message: 'Excellent work on the experiment analysis!',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        score: 95,
      ),
      RecentActivity(
        id: '2',
        title: 'Midterm Exam Completed',
        type: 'quiz_completed',
        courseTitle: 'Data Structures',
        message: 'Score: 85/100',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        score: 85,
      ),
      RecentActivity(
        id: '3',
        title: 'New Assignment Posted',
        type: 'announcement',
        courseTitle: 'Web Development',
        message: 'Project Phase 2 has been assigned',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }
}
