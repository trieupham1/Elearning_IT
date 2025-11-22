class Quiz {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int duration; // in minutes
  final int maxAttempts;
  final DateTime? openDate;
  final DateTime? closeDate;
  final bool allowRetakes;
  final bool shuffleQuestions;
  final bool showResultsImmediately;
  final QuestionStructure questionStructure;
  final List<dynamic> selectedQuestions; // Can be either String IDs or Question objects
  final List<String> categories;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Quiz({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.duration,
    required this.maxAttempts,
    this.openDate,
    this.closeDate,
    required this.allowRetakes,
    required this.shuffleQuestions,
    required this.showResultsImmediately,
    required this.questionStructure,
    required this.selectedQuestions,
    required this.categories,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  static String? _extractStringFromObjectOrString(dynamic value) {
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      return value['_id'] ?? value['id'] ?? '';
    }
    return null;
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['_id'] ?? json['id'] ?? '',
      courseId: json['courseId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'] ?? 60,
      maxAttempts: json['maxAttempts'] ?? 1,
      openDate: json['openDate'] != null ? DateTime.parse(json['openDate']) : null,
      closeDate: json['closeDate'] != null ? DateTime.parse(json['closeDate']) : null,
      allowRetakes: json['allowRetakes'] ?? false,
      shuffleQuestions: json['shuffleQuestions'] ?? false,
      showResultsImmediately: json['showResultsImmediately'] ?? false,
      questionStructure: QuestionStructure.fromJson(json['questionStructure'] ?? {}),
      selectedQuestions: json['selectedQuestions'] ?? [],
      categories: List<String>.from(json['categories'] ?? []),
      status: json['status'] ?? 'draft',
      createdBy: _extractStringFromObjectOrString(json['createdBy']) ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'duration': duration,
      'maxAttempts': maxAttempts,
      'openDate': openDate?.toIso8601String(),
      'closeDate': closeDate?.toIso8601String(),
      'allowRetakes': allowRetakes,
      'shuffleQuestions': shuffleQuestions,
      'showResultsImmediately': showResultsImmediately,
      'questionStructure': questionStructure.toJson(),
      'selectedQuestions': selectedQuestions,
      'categories': categories,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isActive {
    final now = DateTime.now();
    if (openDate != null && now.isBefore(openDate!)) return false;
    if (closeDate != null && now.isAfter(closeDate!)) return false;
    return status == 'active';
  }

  bool get hasStarted {
    if (openDate == null) return true;
    return DateTime.now().isAfter(openDate!);
  }

  bool get hasEnded {
    if (closeDate == null) return false;
    return DateTime.now().isAfter(closeDate!);
  }

  int get totalQuestions {
    // If we have selectedQuestions, use that count, otherwise use questionStructure
    if (selectedQuestions.isNotEmpty) {
      return selectedQuestions.length;
    }
    return questionStructure.easy + questionStructure.medium + questionStructure.hard;
  }
}

class QuestionStructure {
  final int easy;
  final int medium;
  final int hard;

  const QuestionStructure({
    required this.easy,
    required this.medium,
    required this.hard,
  });

  factory QuestionStructure.fromJson(Map<String, dynamic> json) {
    return QuestionStructure(
      easy: json['easy'] ?? 0,
      medium: json['medium'] ?? 0,
      hard: json['hard'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'easy': easy,
      'medium': medium,
      'hard': hard,
    };
  }
}

class QuizAttempt {
  final String id;
  final String quizId;
  final String studentId;
  final int attemptNumber;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? submissionTime;
  final int timeSpent; // in seconds
  final int duration; // quiz duration in minutes
  final List<Map<String, dynamic>> questions; // Full question data with answers
  final int totalQuestions;
  final int correctAnswers;
  final int score; // percentage score
  final int pointsEarned;
  final int totalPoints;
  final String status; // 'in_progress', 'completed', 'submitted', 'auto_submitted', 'expired'
  final String? ipAddress;
  final String? userAgent;

  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.attemptNumber,
    required this.startTime,
    this.endTime,
    this.submissionTime,
    required this.timeSpent,
    required this.duration,
    required this.questions,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.pointsEarned,
    required this.totalPoints,
    required this.status,
    this.ipAddress,
    this.userAgent,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['_id'] ?? json['id'] ?? '',
      quizId: json['quizId'] ?? '',
      studentId: json['studentId'] ?? '',
      attemptNumber: json['attemptNumber'] ?? 1,
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      submissionTime: json['submissionTime'] != null ? DateTime.parse(json['submissionTime']) : null,
      timeSpent: json['timeSpent'] ?? 0,
      duration: json['duration'] ?? 60,
      questions: List<Map<String, dynamic>>.from(json['questions'] ?? []),
      totalQuestions: json['totalQuestions'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      score: json['score'] ?? 0,
      pointsEarned: json['pointsEarned'] ?? 0,
      totalPoints: json['totalPoints'] ?? 100,
      status: json['status'] ?? 'in_progress',
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'quizId': quizId,
      'studentId': studentId,
      'attemptNumber': attemptNumber,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'submissionTime': submissionTime?.toIso8601String(),
      'timeSpent': timeSpent,
      'duration': duration,
      'questions': questions,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'score': score,
      'pointsEarned': pointsEarned,
      'totalPoints': totalPoints,
      'status': status,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  double get percentage => totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
  bool get isCompleted => status == 'completed' || status == 'submitted' || status == 'auto_submitted';
  bool get isInProgress => status == 'in_progress';
  
  int get remainingTimeSeconds {
    if (!isInProgress) return 0;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final maxTime = duration * 60;
    return (maxTime - elapsed).clamp(0, maxTime);
  }
}

class Answer {
  final String questionId;
  final List<String> selectedChoices;
  final bool isCorrect;

  const Answer({
    required this.questionId,
    required this.selectedChoices,
    required this.isCorrect,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      questionId: json['questionId'] ?? '',
      selectedChoices: List<String>.from(json['selectedChoices'] ?? []),
      isCorrect: json['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'selectedChoices': selectedChoices,
      'isCorrect': isCorrect,
    };
  }
}