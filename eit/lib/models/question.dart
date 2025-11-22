class Question {
  final String id;
  
  final String courseId;
  final String questionText;
  final List<Choice> choices;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String? explanation;
  final String? category;
  final List<String> tags;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Question({
    required this.id,
    required this.courseId,
    required this.questionText,
    required this.choices,
    required this.difficulty,
    this.explanation,
    this.category,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    // Handle createdBy field - it could be a String (ID) or an Object (populated)
    String createdById = '';
    if (json['createdBy'] != null) {
      if (json['createdBy'] is String) {
        createdById = json['createdBy'];
      } else if (json['createdBy'] is Map<String, dynamic>) {
        // If it's populated, extract the _id
        createdById = json['createdBy']['_id'] ?? '';
      }
    }

    // Handle courseId - ensure it's a String
    String courseIdString = '';
    if (json['courseId'] != null) {
      if (json['courseId'] is String) {
        courseIdString = json['courseId'];
      } else {
        courseIdString = json['courseId'].toString();
      }
    }
    
    return Question(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      courseId: courseIdString,
      questionText: json['questionText'] ?? '',
      choices: (json['choices'] as List<dynamic>?)?.map((e) => Choice.fromJson(e)).toList() ?? [],
      difficulty: json['difficulty'] ?? 'easy',
      explanation: json['explanation']?.toString(),
      category: json['category']?.toString(),
      tags: List<String>.from(json['tags'] ?? []),
      createdBy: createdById,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'courseId': courseId,
      'questionText': questionText,
      'choices': choices.map((e) => e.toJson()).toList(),
      'difficulty': difficulty,
      'explanation': explanation,
      'category': category,
      'tags': tags,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  List<Choice> get correctChoices => choices.where((choice) => choice.isCorrect).toList();
  bool get isMultipleChoice => correctChoices.length > 1;
}

class Choice {
  final String text;
  final bool isCorrect;

  const Choice({
    required this.text,
    required this.isCorrect,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      text: json['text'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCorrect': isCorrect,
    };
  }
}