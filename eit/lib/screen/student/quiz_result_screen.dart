import 'package:flutter/material.dart';
import '../../models/quiz.dart';

class QuizResultScreen extends StatelessWidget {
  final QuizAttempt attempt;

  const QuizResultScreen({super.key, required this.attempt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results header
            _buildResultsHeader(),
            const SizedBox(height: 24),

            // Score breakdown
            _buildScoreBreakdown(),
            const SizedBox(height: 24),

            // Question results
            _buildQuestionResults(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildResultsHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getScoreColor().withOpacity(0.1),
                border: Border.all(
                  color: _getScoreColor(),
                  width: 4,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${attempt.score}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(),
                      ),
                    ),
                    Text(
                      _getScoreLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getScoreColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Quiz Completed!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'You scored ${attempt.correctAnswers} out of ${attempt.totalQuestions} questions correctly',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown() {
    final timeMinutes = (attempt.timeSpent / 60).floor();
    final timeSeconds = attempt.timeSpent % 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildBreakdownRow(
              'Questions Answered',
              '${attempt.totalQuestions}',
              Icons.quiz,
              Colors.blue,
            ),
            _buildBreakdownRow(
              'Correct Answers',
              '${attempt.correctAnswers}',
              Icons.check_circle,
              Colors.green,
            ),
            _buildBreakdownRow(
              'Incorrect Answers',
              '${attempt.totalQuestions - attempt.correctAnswers}',
              Icons.cancel,
              Colors.red,
            ),
            _buildBreakdownRow(
              'Time Taken',
              '${timeMinutes}m ${timeSeconds}s',
              Icons.timer,
              Colors.orange,
            ),
            _buildBreakdownRow(
              'Points Earned',
              '${attempt.pointsEarned}/${attempt.totalPoints}',
              Icons.star,
              Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
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

  Widget _buildQuestionResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Review',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ...attempt.questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionReviewCard(index + 1, question);
        }).toList(),
      ],
    );
  }

  Widget _buildQuestionReviewCard(int number, Map<String, dynamic> question) {
    final questionText = question['questionText'] ?? '';
    final choices = question['choices'] as List<dynamic>? ?? [];
    final selectedAnswer = question['selectedAnswer'] as List<dynamic>? ?? [];
    final isCorrect = question['isCorrect'] ?? false;
    final difficulty = question['difficulty'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCorrect ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Question $number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(difficulty).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getDifficultyColor(difficulty).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    difficulty.toUpperCase(),
                    style: TextStyle(
                      color: _getDifficultyColor(difficulty),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Question text
            Text(
              questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            
            // Answer choices
            ...choices.map((choice) {
              final choiceText = choice['text'] ?? '';
              final isChoiceCorrect = choice['isCorrect'] ?? false;
              final wasSelected = selectedAnswer.contains(choiceText);
              
              Color backgroundColor = Colors.transparent;
              Color borderColor = Colors.grey.shade300;
              Color textColor = Colors.black87;
              
              if (isChoiceCorrect) {
                backgroundColor = Colors.green.withOpacity(0.1);
                borderColor = Colors.green;
                textColor = Colors.green.shade700;
              } else if (wasSelected && !isChoiceCorrect) {
                backgroundColor = Colors.red.withOpacity(0.1);
                borderColor = Colors.red;
                textColor = Colors.red.shade700;
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      isChoiceCorrect
                          ? Icons.check_circle
                          : wasSelected
                              ? Icons.cancel
                              : Icons.radio_button_unchecked,
                      color: isChoiceCorrect
                          ? Colors.green
                          : wasSelected
                              ? Colors.red
                              : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        choiceText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: wasSelected || isChoiceCorrect
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
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
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home),
              label: const Text('Back to Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to quiz detail
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor() {
    if (attempt.score >= 80) return Colors.green;
    if (attempt.score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel() {
    if (attempt.score >= 80) return 'EXCELLENT';
    if (attempt.score >= 60) return 'GOOD';
    return 'NEEDS WORK';
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
}