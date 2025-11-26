import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';

class QuizTakingScreen extends StatefulWidget {
  final String quizId;
  final String? attemptId; // null means start new attempt

  const QuizTakingScreen({super.key, required this.quizId, this.attemptId});

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final QuizService _quizService = QuizService();
  final PageController _pageController = PageController();

  QuizAttempt? _attempt;
  bool _isLoading = true;
  String? _error;

  // Timer related
  Timer? _timer;
  int _remainingSeconds = 0;

  // Navigation
  int _currentQuestionIndex = 0;
  Map<String, int> _questionTimeSpent = {}; // questionId -> seconds
  DateTime? _questionStartTime;

  // UI state
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeQuizAttempt();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeQuizAttempt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      QuizAttempt attempt;

      if (widget.attemptId != null) {
        // Resume existing attempt
        attempt = await _quizService.getQuizAttempt(widget.attemptId!);
        if (attempt.status != 'in_progress') {
          throw Exception('This quiz attempt is no longer active');
        }
      } else {
        // Start new attempt
        attempt = await _quizService.startQuizAttempt(widget.quizId);
      }

      setState(() {
        _attempt = attempt;
        _isLoading = false;
      });

      _startTimer();
      _startQuestionTimer();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    if (_attempt == null) return;

    final startTime = _attempt!.startTime;
    final durationMs = _attempt!.duration * 60 * 1000;
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    _remainingSeconds = ((durationMs - elapsed) / 1000).round();

    if (_remainingSeconds <= 0) {
      _autoSubmit();
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _autoSubmit();
      }
    });
  }

  void _startQuestionTimer() {
    _questionStartTime = DateTime.now();
  }

  void _saveQuestionTime() {
    if (_questionStartTime == null || _attempt == null) return;

    final currentQuestion = _attempt!.questions[_currentQuestionIndex];
    final questionId = currentQuestion['questionId'].toString();
    final timeSpent = DateTime.now().difference(_questionStartTime!).inSeconds;

    _questionTimeSpent[questionId] =
        (_questionTimeSpent[questionId] ?? 0) + timeSpent;
  }

  Future<void> _saveAnswer(List<String> selectedAnswers) async {
    if (_attempt == null) return;

    final currentQuestion = _attempt!.questions[_currentQuestionIndex];
    final questionId = currentQuestion['questionId'].toString();

    try {
      await _quizService.saveQuestionAnswer(
        _attempt!.id,
        questionId,
        selectedAnswers,
        timeSpent: _questionTimeSpent[questionId] ?? 0,
      );

      // Update local state
      setState(() {
        currentQuestion['selectedAnswer'] = selectedAnswers;
      });
    } catch (e) {
      print('Error saving answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save answer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _attempt!.questions.length - 1) {
      _saveQuestionTime();
      setState(() {
        _currentQuestionIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startQuestionTimer();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _saveQuestionTime();
      setState(() {
        _currentQuestionIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startQuestionTimer();
    }
  }

  // Method removed - not currently used but can be added back for question navigation

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _attempt == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      _saveQuestionTime();
      _timer?.cancel();

      print('🚀 Submitting quiz attempt: ${_attempt!.id}');
      final result = await _quizService.submitQuizAttempt(_attempt!.id);
      print('✅ Quiz submitted successfully. Result: ${result.id}');
      print('📊 Score: ${result.score}, Status: ${result.status}');

      if (mounted) {
        print('🧭 Navigating to quiz result screen...');
        Navigator.of(
          context,
        ).pushReplacementNamed('/quiz-result', arguments: result);
        print('✅ Navigation command sent');
      } else {
        print('⚠️ Widget not mounted, cannot navigate');
      }
    } catch (e) {
      print('❌ Error submitting quiz: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit quiz: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autoSubmit() async {
    if (_isSubmitting) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time is up! Submitting quiz automatically...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );

    await _submitQuiz();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_attempt?.quizId.toString() ?? 'Quiz'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back navigation during quiz
        actions: [
          if (_remainingSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  color: _remainingSeconds < 300
                      ? Colors.white
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : _attempt == null
          ? const Center(child: Text('No quiz attempt found'))
          : _buildQuizContent(),
      bottomNavigationBar: _attempt != null ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load quiz',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeQuizAttempt,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    return Column(
      children: [
        // Progress indicator
        _buildProgressIndicator(),

        // Question content
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              _saveQuestionTime();
              setState(() {
                _currentQuestionIndex = index;
              });
              _startQuestionTimer();
            },
            itemCount: _attempt!.questions.length,
            itemBuilder: (context, index) {
              return _buildQuestionCard(_attempt!.questions[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final totalQuestions = _attempt!.questions.length;
    final answered = _attempt!.questions
        .where(
          (q) =>
              q['selectedAnswer'] != null &&
              (q['selectedAnswer'] as List).isNotEmpty,
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$answered/$totalQuestions answered',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / totalQuestions,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionText = question['questionText'] ?? '';
    final choices = question['choices'] as List<dynamic>? ?? [];
    final selectedAnswer = question['selectedAnswer'] as List<dynamic>? ?? [];
    final difficulty = question['difficulty'] ?? 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getDifficultyColor(difficulty).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getDifficultyColor(difficulty).withOpacity(0.3),
              ),
            ),
            child: Text(
              difficulty.toUpperCase(),
              style: TextStyle(
                color: _getDifficultyColor(difficulty),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Question text
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                questionText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Answer choices
          ...choices.asMap().entries.map((entry) {
            final choice = entry.value;
            final choiceText = choice['text'] ?? '';
            final isSelected = selectedAnswer.contains(choiceText);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Radio<String>(
                  value: choiceText,
                  groupValue: selectedAnswer.isNotEmpty
                      ? selectedAnswer.first
                      : null,
                  onChanged: (value) {
                    if (value != null) {
                      _saveAnswer([value]);
                    }
                  },
                  activeColor: Colors.red.shade700,
                ),
                title: Text(
                  choiceText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  _saveAnswer([choiceText]);
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBottomNavigation() {
    final totalQuestions = _attempt!.questions.length;
    final answered = _attempt!.questions
        .where(
          (q) =>
              q['selectedAnswer'] != null &&
              (q['selectedAnswer'] as List).isNotEmpty,
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentQuestionIndex > 0)
            ElevatedButton.icon(
              onPressed: _previousQuestion,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
            ),

          const Spacer(),

          // Submit button (always visible)
          ElevatedButton.icon(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (answered < totalQuestions) {
                      _showSubmitConfirmation();
                    } else {
                      _submitQuiz();
                    }
                  },
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),

          const Spacer(),

          // Next button
          if (_currentQuestionIndex < totalQuestions - 1)
            ElevatedButton.icon(
              onPressed: _nextQuestion,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  void _showSubmitConfirmation() {
    final totalQuestions = _attempt!.questions.length;
    final answered = _attempt!.questions
        .where(
          (q) =>
              q['selectedAnswer'] != null &&
              (q['selectedAnswer'] as List).isNotEmpty,
        )
        .length;
    final unanswered = totalQuestions - answered;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unanswered > 0) ...[
              Text(
                'You have $unanswered unanswered question${unanswered == 1 ? '' : 's'}.',
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 8),
            ],
            const Text('Are you sure you want to submit your quiz?'),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submitQuiz();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
