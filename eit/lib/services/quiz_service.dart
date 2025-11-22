import '../models/quiz.dart';
import '../models/question.dart';
import 'api_service.dart';

class QuizService extends ApiService {
  // Quiz methods
  Future<List<Quiz>> getQuizzesForCourse(String courseId) async {
    final response = await get('/quizzes/course/$courseId');
    final data = parseResponse(response);
    final List<dynamic> quizzes = data is List ? data : data['quizzes'] ?? [];
    return quizzes.map((json) => Quiz.fromJson(json)).toList();
  }

  Future<Quiz> getQuiz(String quizId) async {
    print('🔍 QuizService: Fetching quiz with ID: $quizId');
    print('🌐 QuizService: Request URL will be: /quizzes/$quizId');
    try {
      final response = await get('/quizzes/$quizId');
      print('📥 QuizService: Response received for quiz $quizId - Status: ${response.statusCode}');
      final data = parseResponse(response);
      print('📊 QuizService: Successfully parsed data for quiz $quizId');
      return Quiz.fromJson(data);
    } catch (e) {
      print('❌ QuizService: Error fetching quiz $quizId: $e');
      // Let's also log the full response body if it's an ApiException
      if (e.toString().contains('Raw response:')) {
        print('💡 QuizService: This looks like a 404 - quiz with ID $quizId does not exist in database');
      }
      rethrow;
    }
  }

  Future<Quiz> createQuiz(Map<String, dynamic> quizData) async {
    final response = await post('/quizzes', body: quizData);
    final data = parseResponse(response);
    return Quiz.fromJson(data);
  }

  Future<Quiz> updateQuiz(String quizId, Map<String, dynamic> quizData) async {
    final response = await put('/quizzes/$quizId', body: quizData);
    final data = parseResponse(response);
    return Quiz.fromJson(data);
  }

  Future<Quiz> updateQuizSettings(String quizId, Map<String, dynamic> settings) async {
    print('⚙️ QuizService: Updating quiz settings for quiz: $quizId');
    final response = await put('/quizzes/$quizId/settings', body: settings);
    final data = parseResponse(response);
    print('✅ QuizService: Quiz settings updated successfully');
    return Quiz.fromJson(data);
  }

  Future<void> deleteQuiz(String quizId) async {
    await delete('/quizzes/$quizId');
  }

  Future<Map<String, dynamic>> getQuizResults(String quizId) async {
    final response = await get('/quizzes/$quizId/results');
    return parseResponse(response);
  }

  // Question methods
  Future<List<Question>> getQuestionsForCourse(String courseId, {
    String? difficulty,
    String? category,
  }) async {
    String endpoint = '/questions/course/$courseId';
    if (difficulty != null || category != null) {
      final queryParams = <String, String>{};
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (category != null) queryParams['category'] = category;
      
      final uri = Uri.parse(endpoint);
      final uriWithQuery = uri.replace(queryParameters: queryParams);
      endpoint = uriWithQuery.toString().replaceFirst(uri.origin, '');
    }
    
    print('🌐 QuizService: Making API call to $endpoint');
    
    final response = await get(endpoint);
    print('📡 QuizService: Response status: ${response.statusCode}');
    print('📡 QuizService: Response body length: ${response.body.length}');
    print('📡 QuizService: Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
    
    final data = parseResponse(response);
    print('🔍 QuizService: Parsed data type: ${data.runtimeType}');
    print('🔍 QuizService: Data is List: ${data is List}');
    
    if (data is List) {
      print('📊 QuizService: Direct list with ${data.length} items');
    } else {
      print('📊 QuizService: Object data: ${data.keys}');
      print('📊 QuizService: Has questions key: ${data.containsKey('questions')}');
      if (data.containsKey('questions')) {
        print('📊 QuizService: Questions array length: ${data['questions']?.length ?? 0}');
      }
    }
    
    final List<dynamic> questions = data is List ? data : (data['questions'] ?? data['data'] ?? []);
    print('🔍 QuizService: Final questions array length: ${questions.length}');
    
    if (questions.isNotEmpty) {
      print('📝 QuizService: First question sample: ${questions[0].runtimeType}');
      print('📝 QuizService: First question keys: ${questions[0] is Map ? questions[0].keys : 'Not a map'}');
    }
    
    try {
      final result = questions.map((json) => Question.fromJson(json)).toList();
      print('✅ QuizService: Successfully parsed ${result.length} questions');
      return result;
    } catch (e) {
      print('❌ QuizService: Error parsing questions: $e');
      print('❌ QuizService: Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<Question> getQuestion(String questionId) async {
    final response = await get('/questions/$questionId');
    final data = parseResponse(response);
    return Question.fromJson(data);
  }

  Future<Question> createQuestion(Map<String, dynamic> questionData) async {
    final response = await post('/questions', body: questionData);
    final data = parseResponse(response);
    return Question.fromJson(data);
  }

  Future<Question> updateQuestion(String questionId, Map<String, dynamic> questionData) async {
    final response = await put('/questions/$questionId', body: questionData);
    final data = parseResponse(response);
    return Question.fromJson(data);
  }

  Future<void> deleteQuestion(String questionId) async {
    await delete('/questions/$questionId');
  }

  Future<List<Question>> getRandomQuestions(
    String courseId, {
    int easy = 0,
    int medium = 0,
    int hard = 0,
  }) async {
    final queryParams = {
      'easy': easy.toString(),
      'medium': medium.toString(),
      'hard': hard.toString(),
    };
    
    final uri = Uri.parse('/questions/course/$courseId/random');
    final uriWithQuery = uri.replace(queryParameters: queryParams);
    String endpoint = uriWithQuery.toString();
    
    final response = await get(endpoint);
    final data = parseResponse(response);
    final List<dynamic> questions = data is List ? data : data['questions'] ?? [];
    return questions.map((json) => Question.fromJson(json)).toList();
  }

  // Quiz attempt methods
  Future<QuizAttempt> startQuizAttempt(String quizId) async {
    print('🚀 QuizService: Starting quiz attempt for quiz: $quizId');
    final response = await post('/quiz-attempts/start', body: {'quizId': quizId});
    final data = parseResponse(response);
    print('✅ QuizService: Quiz attempt started successfully');
    return QuizAttempt.fromJson(data);
  }

  Future<QuizAttempt> getQuizAttempt(String attemptId) async {
    print('📋 QuizService: Getting quiz attempt: $attemptId');
    final response = await get('/quiz-attempts/$attemptId');
    final data = parseResponse(response);
    return QuizAttempt.fromJson(data);
  }

  Future<void> saveQuestionAnswer(String attemptId, String questionId, List<String> selectedAnswer, {int timeSpent = 0}) async {
    print('💾 QuizService: Saving answer for question: $questionId');
    await put('/quiz-attempts/$attemptId/answer', body: {
      'questionId': questionId,
      'selectedAnswer': selectedAnswer,
      'timeSpent': timeSpent,
    });
    print('✅ QuizService: Answer saved successfully');
  }

  Future<QuizAttempt> submitQuizAttempt(String attemptId) async {
    print('📤 QuizService: Submitting quiz attempt: $attemptId');
    final response = await post('/quiz-attempts/$attemptId/submit');
    final data = parseResponse(response);
    print('✅ QuizService: Quiz attempt submitted successfully');
    return QuizAttempt.fromJson(data);
  }

  Future<List<QuizAttempt>> getStudentAttempts(String quizId) async {
    print('📊 QuizService: Getting student attempts for quiz: $quizId');
    final response = await get('/quiz-attempts/quiz/$quizId/student');
    final data = parseResponse(response);
    final List<dynamic> attempts = data is List ? data : data['attempts'] ?? [];
    return attempts.map((json) => QuizAttempt.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getAllQuizAttempts(String quizId) async {
    print('📊 QuizService: Getting all attempts for quiz: $quizId (instructor)');
    final response = await get('/quiz-attempts/quiz/$quizId/all');
    return parseResponse(response);
  }

  Future<String> exportQuizResults(String quizId) async {
    print('📊 QuizService: Exporting quiz results for quiz: $quizId');
    final response = await get('/quizzes/$quizId/export');
    // Return the CSV content directly
    return response.body;
  }

  Future<void> autoCloseExpiredQuizzes() async {
    print('🔒 QuizService: Auto-closing expired quizzes');
    final response = await post('/quizzes/auto-close');
    final data = parseResponse(response);
    print('✅ QuizService: Auto-close completed - ${data['closed']} quizzes closed');
  }

  Future<Map<String, dynamic>?> getStudentQuizAttempt(String quizId) async {
    print('🎯 QuizService: Getting student attempt for quiz: $quizId');
    try {
      final response = await get('/quiz-attempts/quiz/$quizId/student');
      final data = parseResponse(response);
      print('✅ QuizService: Student attempt found for quiz: $quizId');
      return data;
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        print('ℹ️ QuizService: No attempt found for quiz: $quizId');
        return null;
      }
      print('❌ QuizService: Error getting student attempt: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getAllStudentQuizAttempts(String quizId) async {
    print('📊 QuizService: Getting ALL student attempts for quiz (INSTRUCTOR VIEW): $quizId');
    print('🔗 QuizService: Making request to: /quiz-attempts/quiz/$quizId/all');
    try {
      final response = await get('/quiz-attempts/quiz/$quizId/all');
      final data = parseResponse(response);
      print('✅ QuizService: Found ${data['totalAttempts']} attempts for quiz: $quizId');
      return data;
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        print('ℹ️ QuizService: No attempts found for quiz: $quizId');
        return null;
      }
      print('❌ QuizService: Error getting all student attempts: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAttemptDetails(String attemptId) async {
    print('🔍 QuizService: Getting detailed attempt: $attemptId');
    try {
      final response = await get('/quiz-attempts/$attemptId/details');
      final data = parseResponse(response);
      print('✅ QuizService: Got detailed attempt with ${data['questions']?.length ?? 0} questions');
      return data;
    } catch (e) {
      print('❌ QuizService: Error getting attempt details: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentAllAttempts(String studentId, String quizId) async {
    print('📋 QuizService: Getting all attempts for student: $studentId, quiz: $quizId');
    try {
      final response = await get('/quiz-attempts/student/$studentId/quiz/$quizId');
      final data = parseResponse(response);
      print('✅ QuizService: Got ${data['attempts']?.length ?? 0} attempts for student');
      return List<Map<String, dynamic>>.from(data['attempts'] ?? []);
    } catch (e) {
      print('❌ QuizService: Error getting student attempts: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getMyQuizAttempts(String quizId) async {
    print('🎯 QuizService: Getting MY quiz attempts (student view): $quizId');
    try {
      final response = await get('/quiz-attempts/quiz/$quizId/student/all');
      final data = parseResponse(response);
      print('✅ QuizService: Found ${data['totalAttempts']} of my attempts for quiz: $quizId');
      return data;
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        print('ℹ️ QuizService: No attempts found for quiz: $quizId');
        return null;
      }
      print('❌ QuizService: Error getting my quiz attempts: $e');
      rethrow;
    }
  }
}