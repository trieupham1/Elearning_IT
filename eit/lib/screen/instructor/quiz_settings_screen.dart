import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import '../../widgets/loading_overlay.dart';

class QuizSettingsScreen extends StatefulWidget {
  final String quizId;
  final Quiz? quiz;

  const QuizSettingsScreen({
    Key? key,
    required this.quizId,
    this.quiz,
  }) : super(key: key);

  @override
  _QuizSettingsScreenState createState() => _QuizSettingsScreenState();
}

class _QuizSettingsScreenState extends State<QuizSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quizService = QuizService();
  bool _isLoading = false;
  Quiz? _quiz;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _maxAttemptsController = TextEditingController();
  final _totalPointsController = TextEditingController();

  // Date/Time variables
  DateTime? _openDate;
  TimeOfDay? _openTime;
  DateTime? _closeDate;
  TimeOfDay? _closeTime;

  // Settings
  bool _randomizeQuestions = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    print('🔧 QuizSettingsScreen initialized with quizId: ${widget.quizId}');
    if (widget.quiz != null) {
      print('🔧 Using provided quiz data: ${widget.quiz!.title}');
      _initializeWithQuiz(widget.quiz!);
    } else {
      print('🔧 Loading quiz from API...');
      _loadQuiz();
    }
  }

  void _initializeWithQuiz(Quiz quiz) {
    _quiz = quiz;
    _titleController.text = quiz.title;
    _descriptionController.text = quiz.description;
    _durationController.text = quiz.duration.toString();
    _maxAttemptsController.text = quiz.maxAttempts.toString();
    _totalPointsController.text = '100'; // Default since model doesn't have totalPoints
    _randomizeQuestions = quiz.shuffleQuestions;
    _isActive = quiz.status == 'active';

    // Parse dates and times
    if (quiz.openDate != null) {
      _openDate = quiz.openDate;
      _openTime = TimeOfDay.fromDateTime(quiz.openDate!);
    }
    if (quiz.closeDate != null) {
      _closeDate = quiz.closeDate;
      _closeTime = TimeOfDay.fromDateTime(quiz.closeDate!);
    }
    
    print('🔧 Quiz settings initialized:');
    print('   - Title: ${quiz.title}');
    print('   - Duration: ${quiz.duration}');
    print('   - Max Attempts: ${quiz.maxAttempts}');
    print('   - Status: ${quiz.status}');
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    try {
      final quiz = await _quizService.getQuiz(widget.quizId);
      _initializeWithQuiz(quiz);
    } catch (e) {
      _showErrorSnackBar('Failed to load quiz: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

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
      final updatedQuiz = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'duration': int.parse(_durationController.text),
        'maxAttempts': int.parse(_maxAttemptsController.text),
        'totalPoints': int.parse(_totalPointsController.text),
        'openDate': openDateTime.toIso8601String(),
        'closeDate': closeDateTime.toIso8601String(),
        'randomizeQuestions': _randomizeQuestions,
        'isActive': _isActive,
        'status': _isActive ? 'active' : 'draft',
      };

      print('🔧 Saving quiz settings: $updatedQuiz');
      await _quizService.updateQuizSettings(widget.quizId, updatedQuiz);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz settings updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true); // Return true to indicate changes were made
    } catch (e) {
      _showErrorSnackBar('Failed to update quiz settings: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _quiz == null && !_isLoading
            ? const Center(child: Text('Quiz not found'))
            : SingleChildScrollView(
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
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Save Settings',
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
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
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