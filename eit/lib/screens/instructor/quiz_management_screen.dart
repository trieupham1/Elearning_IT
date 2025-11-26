import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import 'quiz_results_screen.dart';
import 'edit_quiz_screen.dart';
import 'manage_questions_screen.dart';

class QuizManagementScreen extends StatefulWidget {
  final String quizId;

  const QuizManagementScreen({super.key, required this.quizId});

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> with SingleTickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  late TabController _tabController;
  Quiz? _quiz;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadQuiz();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quiz = await _quizService.getQuiz(widget.quizId);
      setState(() {
        _quiz = quiz;
        _isLoading = false;
      });
    } catch (e) {
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
        title: const Text('Quiz Management'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_quiz != null)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Quiz'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Duplicate Quiz'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Quiz', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
            Tab(text: 'Results', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Settings', icon: Icon(Icons.settings_outlined)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _quiz == null
                  ? const Center(child: Text('Quiz not found'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildResultsTab(),
                        _buildSettingsTab(),
                      ],
                    ),
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

  Widget _buildOverviewTab() {
    final quiz = _quiz!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz Header
          _buildQuizHeader(quiz),
          const SizedBox(height: 24),

          // Quick Stats
          _buildQuickStats(quiz),
          const SizedBox(height: 24),

          // Quiz Details
          _buildQuizDetails(quiz),
          const SizedBox(height: 24),

          // Quiz Structure
          _buildQuizStructure(quiz),
          const SizedBox(height: 24),

          // Quiz Questions Preview (for instructors)
          _buildQuizQuestions(quiz),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick results overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 48,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quiz Results Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View detailed results and statistics for "${_quiz!.title}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizResultsScreen(
                              quizId: widget.quizId,
                              quizTitle: _quiz!.title,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Detailed Results'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quick actions
          _buildSectionTitle('Quick Actions'),
          const SizedBox(height: 16),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.green),
                  title: const Text('Export Results'),
                  subtitle: const Text('Download results as CSV file'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizResultsScreen(
                          quizId: widget.quizId,
                          quizTitle: _quiz!.title,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                  title: const Text('Cleanup Expired Attempts'),
                  subtitle: const Text('Auto-submit expired in-progress attempts'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _cleanupExpiredAttempts,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.blue),
                  title: const Text('Refresh Results'),
                  subtitle: const Text('Reload latest quiz attempt data'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizResultsScreen(
                          quizId: widget.quizId,
                          quizTitle: _quiz!.title,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final quiz = _quiz!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Quiz Settings'),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSettingItem(
                    'Duration',
                    '${quiz.duration} minutes',
                    Icons.timer,
                  ),
                  const Divider(),
                  _buildSettingItem(
                    'Max Attempts',
                    quiz.maxAttempts == -1 ? 'Unlimited' : quiz.maxAttempts.toString(),
                    Icons.repeat,
                  ),
                  const Divider(),
                  _buildSettingItem(
                    'Allow Retakes',
                    quiz.allowRetakes ? 'Yes' : 'No',
                    Icons.refresh,
                  ),
                  const Divider(),
                  _buildSettingItem(
                    'Shuffle Questions',
                    quiz.shuffleQuestions ? 'Yes' : 'No',
                    Icons.shuffle,
                  ),
                  const Divider(),
                  _buildSettingItem(
                    'Show Results Immediately',
                    quiz.showResultsImmediately ? 'Yes' : 'No',
                    Icons.visibility,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Availability'),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSettingItem(
                    'Open Date',
                    quiz.openDate != null 
                        ? DateFormat('MMM dd, yyyy \'at\' HH:mm').format(quiz.openDate!)
                        : 'Not set',
                    Icons.calendar_today,
                  ),
                  const Divider(),
                  _buildSettingItem(
                    'Close Date',
                    quiz.closeDate != null 
                        ? DateFormat('MMM dd, yyyy \'at\' HH:mm').format(quiz.closeDate!)
                        : 'Not set',
                    Icons.event_busy,
                  ),
                  const Divider(),
                  _buildSettingItem(
                    'Status',
                    quiz.status.toUpperCase(),
                    Icons.info,
                  ),
                ],
              ),
            ),
          ),
        ],
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
            if (quiz.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                quiz.description,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(Quiz quiz) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Questions',
            value: quiz.totalQuestions.toString(),
            icon: Icons.help_outline,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Duration',
            value: '${quiz.duration}m',
            icon: Icons.timer,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Attempts',
            value: '0', // TODO: Get actual attempt count
            icon: Icons.people,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
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

  Widget _buildQuizDetails(Quiz quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quiz Details'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Created', DateFormat('MMM dd, yyyy').format(quiz.createdAt)),
                const Divider(),
                _buildDetailRow('Last Updated', DateFormat('MMM dd, yyyy').format(quiz.updatedAt)),
                const Divider(),
                _buildDetailRow('Categories', quiz.categories.isEmpty ? 'None' : quiz.categories.join(', ')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizStructure(Quiz quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Question Structure'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (quiz.questionStructure.easy > 0)
                  _buildStructureRow('Easy Questions', quiz.questionStructure.easy, Colors.green),
                if (quiz.questionStructure.medium > 0)
                  _buildStructureRow('Medium Questions', quiz.questionStructure.medium, Colors.orange),
                if (quiz.questionStructure.hard > 0)
                  _buildStructureRow('Hard Questions', quiz.questionStructure.hard, Colors.red),
                const Divider(),
                _buildStructureRow('Total Questions', quiz.totalQuestions, Colors.blue, isTotal: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
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

  Widget _buildSettingItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'edit':
        _editQuizSettings();
        break;
      case 'duplicate':
        _duplicateQuiz();
        break;
      case 'delete':
        _deleteQuiz();
        break;
    }
  }

  Future<void> _editQuizSettings() async {
    try {
      print('🔧 Opening quiz editor for quiz: ${widget.quizId}');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditQuizScreen(quiz: _quiz!),
        ),
      );
      
      print('🔧 Quiz editor result: $result');
      if (result == true) {
        // Settings were updated, reload the quiz
        _loadQuiz();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error opening quiz editor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open quiz editor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _duplicateQuiz() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quiz duplication will be implemented soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deleteQuiz() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Are you sure you want to delete "${_quiz!.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _quizService.deleteQuiz(_quiz!.id);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting quiz: $e')),
          );
        }
      }
    }
  }

  void _cleanupExpiredAttempts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cleaning up expired attempts...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _removeQuestionFromQuiz(dynamic question, int questionNumber) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Question'),
        content: Text('Are you sure you want to remove Question $questionNumber from this quiz?\n\nNote: This will only remove it from the quiz, not delete it from the question bank.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && _quiz != null) {
      try {
        // Get question ID
        String questionId;
        if (question is Map<String, dynamic>) {
          questionId = question['_id'] ?? question['id'] ?? '';
        } else if (question is String) {
          questionId = question;
        } else {
          throw Exception('Invalid question format');
        }

        // Remove question from the quiz's selectedQuestions list
        final updatedSelectedQuestions = List<dynamic>.from(_quiz!.selectedQuestions);
        updatedSelectedQuestions.removeWhere((q) {
          if (q is Map<String, dynamic>) {
            return q['_id'] == questionId || q['id'] == questionId;
          } else if (q is String) {
            return q == questionId;
          }
          return false;
        });

        // Update the quiz with the new questions list
        final updatedQuiz = Quiz(
          id: _quiz!.id,
          title: _quiz!.title,
          description: _quiz!.description,
          courseId: _quiz!.courseId,
          duration: _quiz!.duration,
          maxAttempts: _quiz!.maxAttempts,
          allowRetakes: _quiz!.allowRetakes,
          shuffleQuestions: _quiz!.shuffleQuestions,
          showResultsImmediately: _quiz!.showResultsImmediately,
          openDate: _quiz!.openDate,
          closeDate: _quiz!.closeDate,
          status: _quiz!.status,
          categories: _quiz!.categories,
          selectedQuestions: updatedSelectedQuestions,
          questionStructure: _quiz!.questionStructure,
          createdBy: _quiz!.createdBy,
          createdAt: _quiz!.createdAt,
          updatedAt: DateTime.now(),
        );

        // Save the updated quiz
        await _quizService.updateQuiz(_quiz!.id, {
          'selectedQuestions': updatedSelectedQuestions,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Update local state
        setState(() {
          _quiz = updatedQuiz;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Question $questionNumber removed from quiz successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Error removing question from quiz: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove question: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildQuizQuestions(Quiz quiz) {
    if (quiz.selectedQuestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Quiz Questions'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No questions linked to this quiz',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to add questions screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Add questions feature coming soon!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Questions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Quiz Questions'),
            TextButton.icon(
              onPressed: () async {
                try {
                  print('🔧 Opening manage questions screen for quiz: ${widget.quizId}');
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageQuestionsScreen(quiz: _quiz!),
                    ),
                  );
                  
                  print('🔧 Manage questions result: $result');
                  if (result == true) {
                    // Questions were updated, reload the quiz
                    _loadQuiz();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quiz questions updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('❌ Error opening manage questions screen: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to open question manager: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Manage Questions'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.quiz,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${quiz.selectedQuestions.length} Questions Available',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...quiz.selectedQuestions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  return _buildQuestionPreview(index + 1, question);
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionPreview(int number, dynamic question) {
    String questionText = 'Question $number';
    String difficulty = 'Unknown';
    Color difficultyColor = Colors.grey;

    // Handle both cases: populated question objects and just IDs
    if (question is Map<String, dynamic>) {
      // Populated question object
      questionText = question['questionText'] ?? 'Question $number';
      difficulty = question['difficulty'] ?? 'Unknown';
    } else if (question is String) {
      // Just an ID - we'll show a generic preview
      questionText = 'Question $number (ID: ${question.substring(0, 8)}...)';
      difficulty = 'Unknown';
    }
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'medium':
        difficultyColor = Colors.orange;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              number.toString(),
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questionText.length > 60 
                      ? '${questionText.substring(0, 60)}...'
                      : questionText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    difficulty.toUpperCase(),
                    style: TextStyle(
                      color: difficultyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Add action buttons for instructors
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit question feature coming soon!'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                  break;
                case 'delete':
                  _removeQuestionFromQuiz(question, number);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit, size: 16),
                  title: Text('Edit Question'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red, size: 16),
                  title: Text('Remove Question', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 16),
          ),
        ],
      ),
    );
  }
}