import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/question.dart';
import '../../services/quiz_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_overlay.dart';

class CreateQuizScreen extends StatefulWidget {
  final String courseId;

  const CreateQuizScreen({
    Key? key,
    required this.courseId,
  }) : super(key: key);

  @override
  _CreateQuizScreenState createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quizService = QuizService();
  final _authService = AuthService();
  bool _isLoading = false;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _maxAttemptsController = TextEditingController(text: '1');
  final _totalPointsController = TextEditingController(text: '100');

  // Date/Time variables
  DateTime? _openDate;
  TimeOfDay? _openTime;
  DateTime? _closeDate;
  TimeOfDay? _closeTime;

  // Settings
  bool _randomizeQuestions = true;
  bool _allowRetakes = false;
  bool _showResultsImmediately = false;
  bool _isActive = true;

  // Question structure
  int _easyQuestions = 0;
  int _mediumQuestions = 0;
  int _hardQuestions = 0;

  // Available questions
  List<Question> _availableQuestions = [];
  List<Question> _selectedQuestions = [];
  bool _loadedQuestions = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultDates();
    _loadAvailableQuestions();
  }

  void _initializeDefaultDates() {
    // Default open date: now
    _openDate = DateTime.now();
    _openTime = TimeOfDay.now();
    
    // Default close date: 7 days from now
    _closeDate = DateTime.now().add(const Duration(days: 7));
    _closeTime = const TimeOfDay(hour: 23, minute: 59);
  }

  Future<void> _loadAvailableQuestions() async {
    try {
      print('🔍 Loading questions for courseId: ${widget.courseId}');
      print('🌐 Making API call to: /questions/course/${widget.courseId}');
      
      final questions = await _quizService.getQuestionsForCourse(widget.courseId);
      print('📊 Loaded ${questions.length} questions from API');
      print('🔍 Questions received: ${questions.map((q) => q.id).toList()}');
      
      setState(() {
        _availableQuestions = questions;
        _loadedQuestions = true;
      });
      
      if (questions.isEmpty) {
        print('⚠️ No questions found for course: ${widget.courseId}');
        print('🔍 This could mean:');
        print('   1. CourseId mismatch: ${widget.courseId}');
        print('   2. Network/API error');
        print('   3. No questions exist for this course');
      } else {
        print('✅ Questions loaded successfully:');
        for (var i = 0; i < questions.length && i < 3; i++) {
          print('   - ${questions[i].questionText.substring(0, 50)}...');
        }
      }
    } catch (e) {
      print('❌ Error loading questions: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e.toString().contains('404')) {
        print('💡 404 error suggests courseId not found: ${widget.courseId}');
      }
      setState(() {
        _loadedQuestions = true;
      });
    }
  }

  Future<void> _createQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate questions
    if (_selectedQuestions.isEmpty && (_easyQuestions + _mediumQuestions + _hardQuestions) == 0) {
      _showErrorSnackBar('Please select questions or specify question structure');
      return;
    }

    // Validate dates
    if (_openDate == null || _closeDate == null || _openTime == null || _closeTime == null) {
      _showErrorSnackBar('Please set both open and close dates/times');
      return;
    }

    final openDateTime = DateTime(
      _openDate!.year,
      _openDate!.month,
      _openDate!.day,
      _openTime!.hour,
      _openTime!.minute,
    );

    final closeDateTime = DateTime(
      _closeDate!.year,
      _closeDate!.month,
      _closeDate!.day,
      _closeTime!.hour,
      _closeTime!.minute,
    );

    if (closeDateTime.isBefore(openDateTime)) {
      _showErrorSnackBar('Close date must be after open date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }
      
      final quizData = {
        'courseId': widget.courseId,
        'createdBy': currentUser.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'duration': int.parse(_durationController.text),
        'maxAttempts': int.parse(_maxAttemptsController.text),
        'openDate': openDateTime.toIso8601String(),
        'closeDate': closeDateTime.toIso8601String(),
        'questionStructure': {
          'easy': _easyQuestions,
          'medium': _mediumQuestions,
          'hard': _hardQuestions,
        },
        'randomizeQuestions': _randomizeQuestions,
        'selectedQuestions': _selectedQuestions.map((q) => q.id).toList(),
        'totalPoints': int.parse(_totalPointsController.text),
        'isActive': _isActive,
        'status': _isActive ? 'active' : 'draft',
        'allowRetakes': _allowRetakes,
        'shuffleQuestions': _randomizeQuestions,
        'showResultsImmediately': _showResultsImmediately,
        'categories': [],
      };

      print('🔧 Creating quiz with data: $quizData');
      final createdQuiz = await _quizService.createQuiz(quizData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Return the created quiz
      Navigator.pop(context, createdQuiz);
    } catch (e) {
      _showErrorSnackBar('Failed to create quiz: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isOpenDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isOpenDate ? (_openDate ?? DateTime.now()) : (_closeDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isOpenDate) {
          _openDate = picked;
        } else {
          _closeDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? (_openTime ?? TimeOfDay.now()) : (_closeTime ?? const TimeOfDay(hour: 23, minute: 59)),
    );
    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  void _showQuestionSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildQuestionSelector(),
    );
  }

  Widget _buildQuestionSelector() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Questions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!_loadedQuestions)
            const Center(child: CircularProgressIndicator())
          else if (_availableQuestions.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.quiz,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No questions available for this course.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create questions first, or use the question structure below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.pushNamed(
                        context,
                        '/create-question',
                        arguments: {
                          'courseId': widget.courseId,
                          'courseName': 'Course',
                        },
                      );
                      if (result == true) {
                        // Reload questions after creating new one
                        _loadAvailableQuestions();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Questions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _availableQuestions.length,
                itemBuilder: (context, index) {
                  final question = _availableQuestions[index];
                  final isSelected = _selectedQuestions.contains(question);
                  
                  return Card(
                    color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedQuestions.remove(question);
                          } else {
                            _selectedQuestions.add(question);
                          }
                        });
                      },
                      title: Text(
                        question.questionText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          _buildDifficultyChip(question.difficulty),
                          if (question.category != null && question.category!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(question.category!),
                              labelStyle: const TextStyle(fontSize: 12),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ],
                      ),
                      trailing: isSelected 
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : const Icon(Icons.circle_outlined),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = Colors.green;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'hard':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        difficulty.toUpperCase(),
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createQuiz,
            child: const Text(
              'CREATE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information
                _buildSectionHeader('Basic Information'),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a quiz title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Quiz Configuration
                _buildSectionHeader('Quiz Configuration'),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter duration';
                          }
                          final duration = int.tryParse(value);
                          if (duration == null || duration <= 0) {
                            return 'Please enter a valid duration';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxAttemptsController,
                        decoration: const InputDecoration(
                          labelText: 'Max Attempts',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter max attempts';
                          }
                          final attempts = int.tryParse(value);
                          if (attempts == null || attempts <= 0) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _totalPointsController,
                  decoration: const InputDecoration(
                    labelText: 'Total Points',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter total points';
                    }
                    final points = int.tryParse(value);
                    if (points == null || points <= 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Availability Schedule
                _buildSectionHeader('Availability Schedule'),
                const SizedBox(height: 16),
                
                // Open Date/Time
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Open Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _openDate != null
                                ? DateFormat('MMM dd, yyyy').format(_openDate!)
                                : 'Select Date',
                            style: TextStyle(
                              color: _openDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Open Time',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _openTime != null
                                ? _openTime!.format(context)
                                : 'Select Time',
                            style: TextStyle(
                              color: _openTime != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Close Date/Time
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Close Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _closeDate != null
                                ? DateFormat('MMM dd, yyyy').format(_closeDate!)
                                : 'Select Date',
                            style: TextStyle(
                              color: _closeDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Close Time',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _closeTime != null
                                ? _closeTime!.format(context)
                                : 'Select Time',
                            style: TextStyle(
                              color: _closeTime != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Questions Selection
                _buildSectionHeader('Questions'),
                const SizedBox(height: 16),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected Questions: ${_selectedQuestions.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showQuestionSelector,
                              icon: const Icon(Icons.add),
                              label: const Text('Select Questions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedQuestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _selectedQuestions.map((question) {
                              return Chip(
                                label: Text(
                                  question.questionText.length > 30
                                      ? '${question.questionText.substring(0, 30)}...'
                                      : question.questionText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedQuestions.remove(question);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Question Structure (alternative to selecting specific questions)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Or specify question structure:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Questions will be randomly selected based on difficulty',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _easyQuestions.toString(),
                                decoration: InputDecoration(
                                  labelText: 'Easy Questions',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.circle, color: Colors.green, size: 16),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _easyQuestions = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _mediumQuestions.toString(),
                                decoration: InputDecoration(
                                  labelText: 'Medium Questions',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.circle, color: Colors.orange, size: 16),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _mediumQuestions = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _hardQuestions.toString(),
                                decoration: InputDecoration(
                                  labelText: 'Hard Questions',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.circle, color: Colors.red, size: 16),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _hardQuestions = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Total: ${_easyQuestions + _mediumQuestions + _hardQuestions} questions',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
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
                const SizedBox(height: 24),

                // Options
                _buildSectionHeader('Options'),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Randomize Questions'),
                  subtitle: const Text('Questions will appear in random order for each student'),
                  value: _randomizeQuestions,
                  onChanged: (value) {
                    setState(() {
                      _randomizeQuestions = value;
                    });
                  },
                ),
                
                SwitchListTile(
                  title: const Text('Allow Retakes'),
                  subtitle: const Text('Students can retake the quiz multiple times'),
                  value: _allowRetakes,
                  onChanged: (value) {
                    setState(() {
                      _allowRetakes = value;
                    });
                  },
                ),
                
                SwitchListTile(
                  title: const Text('Show Results Immediately'),
                  subtitle: const Text('Students see their results as soon as they submit'),
                  value: _showResultsImmediately,
                  onChanged: (value) {
                    setState(() {
                      _showResultsImmediately = value;
                    });
                  },
                ),
                
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Students can see and access this quiz'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Create Quiz',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.red.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _maxAttemptsController.dispose();
    _totalPointsController.dispose();
    super.dispose();
  }
}