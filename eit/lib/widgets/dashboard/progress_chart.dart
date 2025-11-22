import 'package:flutter/material.dart';
import '../../models/dashboard_summary.dart';

class ProgressChart extends StatelessWidget {
  final List<QuizScore> quizScores;

  const ProgressChart({super.key, required this.quizScores});

  @override
  Widget build(BuildContext context) {
    if (quizScores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No quiz results yet',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

  final maxScore = quizScores.map((s) => s.percentage).reduce((a, b) => a > b ? a : b);
  // Prevent division by zero when all scores are 0. Use a fallback denominator of 1
  // so computed heights become 0 instead of NaN.
  final denom = (maxScore <= 0) ? 1.0 : maxScore;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Quiz Scores',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220, // Increased height to prevent overflow
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: quizScores.map((score) {
                final percentage = score.percentage;
                // Use denom (never zero) to avoid NaN heights when maxScore == 0
                final height = (percentage / denom) * 140; // Reduced bar height
                final color = _getScoreColor(percentage);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min, // Important: prevents overflow
                      children: [
                        // Score text
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Bar
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                color,
                                color.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Quiz title with fixed height
                        SizedBox(
                          height: 36,
                          child: Text(
                            score.quizTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 70) return Colors.amber;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}

