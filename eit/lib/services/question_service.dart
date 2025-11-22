import 'dart:convert';
import 'api_service.dart';

class QuestionService extends ApiService {
  // Get all questions for a course (question bank)
  Future<List<dynamic>> getCourseQuestions(String courseId, {
    String? difficulty,
    String? category,
  }) async {
    try {
      print('🔍 QuestionService: Fetching questions for course $courseId');
      
      final Map<String, String> queryParams = {};
      if (difficulty != null && difficulty.isNotEmpty) {
        queryParams['difficulty'] = difficulty;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      
      String endpoint = '/questions/course/$courseId';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint += '?$queryString';
      }
      
      print('🔍 QuestionService: Request endpoint: $endpoint');
      
      final response = await get(endpoint);
      print('🔍 QuestionService: Response status: ${response.statusCode}');
      print('🔍 QuestionService: Response body (first 200 chars): ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> questions = json.decode(response.body);
        print('✅ QuestionService: Successfully fetched ${questions.length} questions');
        return questions;
      } else if (response.statusCode == 404) {
        print('⚠️ QuestionService: No questions found for course $courseId (404)');
        // Return empty list instead of throwing error for 404
        return [];
      } else {
        print('❌ QuestionService: Failed to fetch questions - ${response.statusCode}');
        throw Exception('Failed to fetch questions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ QuestionService: Error fetching questions: $e');
      if (e.toString().contains('404')) {
        // If it's a 404 error, return empty list
        print('⚠️ QuestionService: Treating 404 as empty question bank');
        return [];
      }
      rethrow;
    }
  }

  // Get questions available to add to quiz (not already in quiz)
  Future<List<dynamic>> getAvailableQuestions(String courseId, List<dynamic> selectedQuestionIds) async {
    try {
      print('🔍 QuestionService: Fetching available questions for course $courseId');
      print('🔍 QuestionService: Selected question IDs: $selectedQuestionIds');
      
      final allQuestions = await getCourseQuestions(courseId);
      print('🔍 QuestionService: Total questions in course: ${allQuestions.length}');
      
      // Filter out questions already selected in the quiz
      final availableQuestions = allQuestions.where((question) {
        final questionId = question['_id'] ?? question['id'];
        final isSelected = selectedQuestionIds.any((selectedId) {
          if (selectedId is Map<String, dynamic>) {
            return selectedId['_id'] == questionId || selectedId['id'] == questionId;
          } else if (selectedId is String) {
            return selectedId == questionId;
          }
          return false;
        });
        return !isSelected;
      }).toList();
      
      print('✅ QuestionService: Available questions: ${availableQuestions.length}');
      return availableQuestions;
    } catch (e) {
      print('❌ QuestionService: Error fetching available questions: $e');
      rethrow;
    }
  }

  // Get single question by ID
  Future<Map<String, dynamic>> getQuestion(String questionId) async {
    try {
      print('🔍 QuestionService: Fetching question $questionId');
      
      final response = await get('/questions/$questionId');
      
      if (response.statusCode == 200) {
        final question = json.decode(response.body);
        print('✅ QuestionService: Successfully fetched question');
        return question;
      } else {
        print('❌ QuestionService: Failed to fetch question - ${response.statusCode}');
        throw Exception('Failed to fetch question: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ QuestionService: Error fetching question: $e');
      rethrow;
    }
  }

  // Create new question
  Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> questionData) async {
    try {
      print('🔍 QuestionService: Creating new question');
      print('🔍 QuestionService: Question data: $questionData');
      
      final response = await post('/questions', body: questionData);
      
      if (response.statusCode == 201) {
        final question = json.decode(response.body);
        print('✅ QuestionService: Successfully created question');
        return question;
      } else {
        print('❌ QuestionService: Failed to create question - ${response.statusCode}');
        throw Exception('Failed to create question: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ QuestionService: Error creating question: $e');
      rethrow;
    }
  }

  // Update question
  Future<Map<String, dynamic>> updateQuestion(String questionId, Map<String, dynamic> questionData) async {
    try {
      print('🔍 QuestionService: Updating question $questionId');
      
      final response = await put('/questions/$questionId', body: questionData);
      
      if (response.statusCode == 200) {
        final question = json.decode(response.body);
        print('✅ QuestionService: Successfully updated question');
        return question;
      } else {
        print('❌ QuestionService: Failed to update question - ${response.statusCode}');
        throw Exception('Failed to update question: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ QuestionService: Error updating question: $e');
      rethrow;
    }
  }

  // Delete question
  Future<void> deleteQuestion(String questionId) async {
    try {
      print('🔍 QuestionService: Deleting question $questionId');
      
      final response = await delete('/questions/$questionId');
      
      if (response.statusCode == 200) {
        print('✅ QuestionService: Successfully deleted question');
      } else {
        print('❌ QuestionService: Failed to delete question - ${response.statusCode}');
        throw Exception('Failed to delete question: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ QuestionService: Error deleting question: $e');
      rethrow;
    }
  }
}