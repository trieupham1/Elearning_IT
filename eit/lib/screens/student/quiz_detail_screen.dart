import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';


class QuizDetailScreen extends StatefulWidget {
  final String quizId;

  const QuizDetailScreen({super.key, required this.quizId});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final QuizService _quizService = QuizService();
  Quiz? _quiz;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _studentAttempt;
  Map<String, dynamic>? _allAttempts;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void didUpdateWidget(QuizDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload quiz if the quizId changed
    if (oldWidget.quizId != widget.quizId) {
      _loadQuiz();
    }
  }

  Future<void> _loadQuiz() async {
      setState(() {
        _isLoading = true;
        _error = null;
        _studentAttempt = null; // Clear cached attempt data
        _allAttempts = null; // Clear cached all attempts data
      });    try {
      final quiz = await _quizService.getQuiz(widget.quizId);
      print('📊 Quiz loaded: ${quiz.title}');
      print('🔗 Selected questions count: ${quiz.selectedQuestions.length}');
      print('🔍 First question type: ${quiz.selectedQuestions.isNotEmpty ? quiz.selectedQuestions.first.runtimeType : 'N/A'}');
      print('🎯 Quiz allowRetakes: ${quiz.allowRetakes}');
      print('🎯 Quiz maxAttempts: ${quiz.maxAttempts}');
      
      // Check if student has already attempted this quiz
      Map<String, dynamic>? attempt;
      Map<String, dynamic>? allAttempts;
      try {
        // Get latest attempt for quick status check
        attempt = await _quizService.getStudentQuizAttempt(widget.quizId);
        if (attempt != null) {
          print('🎯 Student attempt found: ${attempt.keys}');
          print('🎯 Attempt state: ${attempt['state']}');
          print('🎯 Attempt score: ${attempt['score']}/${attempt['maxScore']}');
          
          // Get all attempts for detailed display (my attempts only)
          allAttempts = await _quizService.getMyQuizAttempts(widget.quizId);
          if (allAttempts != null) {
            print('📊 All my attempts loaded: ${allAttempts['totalAttempts']} total');
          }
        } else {
          print('ℹ️ No previous attempt found');
        }
      } catch (e) {
        print('ℹ️ No previous attempt found: $e');
        attempt = null;
        allAttempts = null;
      }
      
      setState(() {
        _quiz = quiz;
        _studentAttempt = attempt;
        _allAttempts = allAttempts;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading quiz: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Details'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _quiz == null
                  ? const Center(child: Text('Quiz not found'))
                  : _buildQuizContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load quiz',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadQuiz,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final quiz = _quiz!;
    
    return RefreshIndicator(
      onRefresh: _loadQuiz,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz Header
          _buildQuizHeader(quiz),
          const SizedBox(height: 24),

          // Quiz Info Cards
          _buildQuizInfoCards(quiz),
          const SizedBox(height: 24),

          // Quiz Status and Actions
          _buildQuizActions(quiz),
          const SizedBox(height: 24),

          // Quiz Description
          if (quiz.description.isNotEmpty) ...[
            _buildSectionTitle('Description'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  quiz.description,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Quiz Structure
          _buildQuizStructure(quiz),
          const SizedBox(height: 24),

          // Student's Quiz Results (if attempted)
          if (_allAttempts != null) ...[
            _buildAllStudentResults(_allAttempts!),
            const SizedBox(height: 24),
          ] else if (_studentAttempt != null) ...[
            _buildStudentResult(_studentAttempt!),
            const SizedBox(height: 24),
          ],

          // Quiz questions are only visible to instructors
        ],
      ),
      ),
    );
  }

  Widget _buildQuizHeader(Quiz quiz) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  child: const Icon(Icons.quiz, color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quiz.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQuizStatus(quiz),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizStatus(Quiz quiz) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!quiz.hasStarted) {
      statusText = 'Not Started';
      statusColor = Colors.grey;
      statusIcon = Icons.schedule;
    } else if (quiz.hasEnded) {
      statusText = 'Ended';
      statusColor = Colors.grey;
      statusIcon = Icons.lock;
    } else {
      statusText = 'Available';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizInfoCards(Quiz quiz) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.timer,
            title: 'Duration',
            value: '${quiz.duration} min',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.help,
            title: 'Questions',
            value: quiz.totalQuestions.toString(),
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.repeat,
            title: 'Attempts',
            value: _getAttemptsDisplayValue(),
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizActions(Quiz quiz) {
    if (!quiz.hasStarted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.schedule,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Quiz will be available on:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                quiz.openDate != null
                    ? DateFormat('MMM dd, yyyy \'at\' HH:mm').format(quiz.openDate!)
                    : 'Not scheduled',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (quiz.hasEnded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.lock,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'This quiz has ended',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              if (quiz.closeDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ended on: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(quiz.closeDate!)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Check if student has already attempted the quiz
    bool hasAttempted = _studentAttempt != null;
    
    // Check if retakes are allowed based on backend response
    bool canRetake = false;
    if (hasAttempted) {
      // Use canRetake from backend response if available
      canRetake = _studentAttempt!['canRetake'] ?? false;
      print('🔄 Backend says canRetake: $canRetake');
      print('🔍 Student attempt data: ${_studentAttempt!.keys}');
    } else {
      // No attempt yet, student can take the quiz
      canRetake = true;
    }

    print('📊 Final decision: hasAttempted=$hasAttempted, canRetake=$canRetake');

    if (hasAttempted && !canRetake) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Quiz Completed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have already completed this quiz.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getAttemptStatusMessage(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canRetake ? _startQuiz : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canRetake ? Colors.red.shade700 : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              hasAttempted ? 'Retake Quiz' : 'Start Quiz',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          canRetake 
              ? 'Once you start, you have ${quiz.duration} minutes to complete the quiz.'
              : _getAttemptStatusMessage(),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQuizStructure(Quiz quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quiz Structure'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (quiz.questionStructure.easy > 0)
                  _buildStructureRow(
                    'Easy Questions',
                    quiz.questionStructure.easy,
                    Colors.green,
                  ),
                if (quiz.questionStructure.medium > 0)
                  _buildStructureRow(
                    'Medium Questions',
                    quiz.questionStructure.medium,
                    Colors.orange,
                  ),
                if (quiz.questionStructure.hard > 0)
                  _buildStructureRow(
                    'Hard Questions',
                    quiz.questionStructure.hard,
                    Colors.red,
                  ),
                const Divider(),
                _buildStructureRow(
                  'Total Questions',
                  quiz.totalQuestions,
                  Colors.blue,
                  isTotal: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStructureRow(String label, int count, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Quiz questions preview moved to instructor quiz management screen

  Widget _buildAllStudentResults(Map<String, dynamic> allAttemptsData) {
    final List<dynamic> attempts = allAttemptsData['attempts'] ?? [];
    final double finalGrade = (allAttemptsData['finalGrade'] ?? 0.0).toDouble();
    final bool canRetake = allAttemptsData['canRetake'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Summary of your previous attempts'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Attempt',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'State',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Marks / ${attempts.isNotEmpty ? attempts.first['maxScore'].toStringAsFixed(1) : '100.0'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Grade / 10.00',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Review',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Data rows for each attempt
                ...attempts.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final Map<String, dynamic> attempt = entry.value;
                  final bool isLatest = attempt['isLatest'] ?? false;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLatest 
                          ? Colors.blue.shade50 
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: isLatest 
                          ? Border.all(color: Colors.blue.shade200)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Text(
                                    '${attempt['attemptNumber'] ?? (index + 1)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isLatest ? Colors.blue.shade700 : Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (isLatest) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Latest',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                attempt['state'] ?? 'Finished',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                (attempt['score'] ?? 0).toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                (attempt['grade'] ?? 0.0).toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: (attempt['grade'] ?? 0.0) >= 5.0 
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Not permitted',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Submitted ${DateFormat('EEEE, dd MMMM yyyy, h:mm a').format(DateTime.parse(attempt['submittedAt']))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 20),
                
                // Final grade section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your final grade for this quiz is ${finalGrade.toStringAsFixed(2)}/10.00.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on ${attempts.length} attempt${attempts.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        canRetake 
                            ? 'You can attempt this quiz again'
                            : 'No more attempts are allowed',
                        style: TextStyle(
                          fontSize: 14,
                          color: canRetake 
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 160,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Back to the course',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentResult(Map<String, dynamic> attempt) {
    final score = attempt['score'] ?? 0;
    final maxScore = attempt['maxScore'] ?? 20;
    final grade = maxScore > 0 ? (score / maxScore * 10) : 0;
    final submittedAt = attempt['submittedAt'] != null 
        ? DateTime.parse(attempt['submittedAt'])
        : DateTime.now();
    final state = attempt['state'] ?? 'Finished';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Summary of your previous attempts'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'State',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Marks / ${maxScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Grade / 10.00',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Review',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Data row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submitted ${DateFormat('EEEE, dd MMMM yyyy, h:mm a').format(submittedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          score.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          grade.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Not permitted',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Final grade section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your final grade for this quiz is ${grade.toStringAsFixed(2)}/10.00.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No more attempts are allowed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 160,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Back to the course',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getAttemptsDisplayValue() {
    final quiz = _quiz!;
    
    // Use all attempts data if available
    if (_allAttempts != null) {
      final totalAttempts = _allAttempts!['totalAttempts'] ?? 0;
      if (quiz.maxAttempts == -1) {
        return totalAttempts > 0 ? '$totalAttempts / ∞' : 'Unlimited';
      } else {
        return '$totalAttempts / ${quiz.maxAttempts}';
      }
    }
    
    // Fallback to single attempt data
    if (_studentAttempt == null) {
      return quiz.maxAttempts == -1 ? 'Unlimited' : quiz.maxAttempts.toString();
    }
    
    final totalAttempts = _studentAttempt!['totalAttempts'] ?? 1;
    if (quiz.maxAttempts == -1) {
      return '$totalAttempts / ∞';
    } else {
      return '$totalAttempts / ${quiz.maxAttempts}';
    }
  }

  String _getAttemptStatusMessage() {
    if (_studentAttempt == null) return 'No attempts yet.';
    
    final quiz = _quiz!;
    final totalAttempts = _studentAttempt!['totalAttempts'] ?? 1;
    final maxAttempts = quiz.maxAttempts;
    final allowRetakes = quiz.allowRetakes;
    
    if (!allowRetakes) {
      return 'No more attempts are allowed.';
    }
    
    if (maxAttempts > 0 && totalAttempts >= maxAttempts) {
      return 'Maximum attempts ($maxAttempts) reached.';
    }
    
    return 'You can retake this quiz.';
  }

  void _startQuiz() {
    Navigator.of(context).pushNamed(
      '/quiz-taking',
      arguments: {
        'quizId': widget.quizId,
        'attemptId': null, // Start new attempt
      },
    );
  }
}