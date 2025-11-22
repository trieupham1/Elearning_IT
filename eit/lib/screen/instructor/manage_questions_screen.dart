import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import '../../services/question_service.dart';
import 'create_question_screen.dart';

class ManageQuestionsScreen extends StatefulWidget {
  final Quiz quiz;

  const ManageQuestionsScreen({super.key, required this.quiz});

  @override
  State<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends State<ManageQuestionsScreen> {
  final QuizService _quizService = QuizService();
  final QuestionService _questionService = QuestionService();
  
  List<dynamic> _availableQuestions = [];
  List<dynamic> _selectedQuestions = [];
  bool _isLoading = true;
  String? _error;
  String _selectedDifficulty = 'all';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _selectedQuestions = List.from(widget.quiz.selectedQuestions);
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 ManageQuestions: Loading questions for course ${widget.quiz.courseId}');
      
      // Get available questions not already in quiz
      final availableQuestions = await _questionService.getAvailableQuestions(
        widget.quiz.courseId,
        _selectedQuestions,
      );
      
      setState(() {
        _availableQuestions = availableQuestions;
        _isLoading = false;
      });
      
      print('✅ ManageQuestions: Loaded ${availableQuestions.length} available questions');
      
      if (availableQuestions.isEmpty) {
        print('⚠️ ManageQuestions: No questions found in question bank for this course');
      }
    } catch (e) {
      print('❌ ManageQuestions: Error loading questions: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    try {
      print('💾 ManageQuestions: Saving changes to quiz');
      
      // Update the quiz with new selected questions
      await _quizService.updateQuiz(widget.quiz.id, {
        'selectedQuestions': _selectedQuestions,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ ManageQuestions: Successfully saved changes');
      
      // Show success message and return
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz questions updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      print('❌ ManageQuestions: Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addQuestion(dynamic question) {
    setState(() {
      _selectedQuestions.add(question);
      _availableQuestions.removeWhere((q) {
        final qId = q['_id'] ?? q['id'];
        final questionId = question['_id'] ?? question['id'];
        return qId == questionId;
      });
    });
  }

  void _removeQuestion(dynamic question) {
    setState(() {
      _selectedQuestions.removeWhere((q) {
        if (q is Map<String, dynamic>) {
          final qId = q['_id'] ?? q['id'];
          final questionId = question['_id'] ?? question['id'];
          return qId == questionId;
        } else if (q is String) {
          final questionId = question['_id'] ?? question['id'];
          return q == questionId;
        }
        return false;
      });
      _availableQuestions.add(question);
    });
  }

  List<dynamic> get _filteredAvailableQuestions {
    return _availableQuestions.where((question) {
      if (_selectedDifficulty != 'all' && question['difficulty'] != _selectedDifficulty) {
        return false;
      }
      if (_selectedCategory != 'all' && question['category'] != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Quiz Questions'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              'Save Changes',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildHeader(),
                    _buildFilters(),
                    Expanded(
                      child: _buildQuestionsList(),
                    ),
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
            'Failed to load questions',
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
            onPressed: _loadQuestions,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.quiz.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatChip(
                'Selected: ${_selectedQuestions.length}',
                Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                'Available: ${_filteredAvailableQuestions.length}',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color is MaterialColor ? color.shade700 : color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Difficulties')),
                DropdownMenuItem(value: 'easy', child: Text('Easy')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'hard', child: Text('Hard')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Categories')),
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'theory', child: Text('Theory')),
                DropdownMenuItem(value: 'practical', child: Text('Practical')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: const TabBar(
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.red,
              tabs: [
                Tab(text: 'Available Questions', icon: Icon(Icons.add_circle_outline)),
                Tab(text: 'Selected Questions', icon: Icon(Icons.check_circle_outline)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAvailableQuestionsList(),
                _buildSelectedQuestionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableQuestionsList() {
    final filteredQuestions = _filteredAvailableQuestions;
    
    if (filteredQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _availableQuestions.isEmpty 
                  ? 'No questions in question bank'
                  : 'No available questions',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _availableQuestions.isEmpty 
                  ? 'Create questions in the question bank first, then add them to your quiz.'
                  : 'All questions from this course are already added to the quiz.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_availableQuestions.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    // Navigate to create question screen
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateQuestionScreen(
                          courseId: widget.quiz.courseId,
                          courseName: widget.quiz.title, // Use quiz title as course context
                        ),
                      ),
                    );
                    
                    // If question was created successfully, reload questions
                    if (result == true) {
                      await _loadQuestions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Question created successfully! You can now add it to your quiz.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    print('❌ Error navigating to create question: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error opening question creator: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Questions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredQuestions.length,
      itemBuilder: (context, index) {
        final question = filteredQuestions[index];
        return _buildQuestionCard(question, isSelected: false);
      },
    );
  }

  Widget _buildSelectedQuestionsList() {
    if (_selectedQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No questions selected',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add questions from the available questions tab.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedQuestions.length,
      itemBuilder: (context, index) {
        final question = _selectedQuestions[index];
        return _buildQuestionCard(question, isSelected: true, questionNumber: index + 1);
      },
    );
  }

  Widget _buildQuestionCard(dynamic question, {required bool isSelected, int? questionNumber}) {
    String questionText = 'Question';
    String difficulty = 'Unknown';
    Color difficultyColor = Colors.grey;
    List<dynamic> choices = [];

    // Handle both populated question objects and just IDs
    if (question is Map<String, dynamic>) {
      questionText = question['questionText'] ?? 'Question';
      difficulty = question['difficulty'] ?? 'Unknown';
      choices = question['choices'] ?? [];
    } else if (question is String) {
      questionText = 'Question (ID: ${question.substring(0, 8)}...)';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (questionNumber != null) ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      questionNumber.toString(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: difficultyColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    difficulty.toUpperCase(),
                    style: TextStyle(
                      color: difficultyColor is MaterialColor ? difficultyColor.shade700 : difficultyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (choices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Choices: ${choices.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isSelected)
                  ElevatedButton.icon(
                    onPressed: () => _removeQuestion(question),
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _addQuestion(question),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}