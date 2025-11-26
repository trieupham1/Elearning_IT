import 'package:flutter/material.dart';
import '../../services/question_service.dart';
import '../../services/auth_service.dart';

class CreateQuestionScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  
  const CreateQuestionScreen({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionService = QuestionService();
  final _authService = AuthService();
  
  // Controllers
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointsController = TextEditingController(text: '1');
  final _categoryController = TextEditingController();
  
  // Multiple choice options
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  
  // Question properties
  String _questionType = 'multiple_choice';
  String _difficulty = 'medium';
  int _correctAnswerIndex = 0; // Default to Option A
  bool _isLoading = false;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    _categoryController.dispose();
    _tagController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate multiple choice options
    if (_questionType == 'multiple_choice') {
      final nonEmptyOptions = _optionControllers.where((c) => c.text.trim().isNotEmpty).toList();
      if (nonEmptyOptions.length < 2) {
        _showErrorSnackBar('Please provide at least 2 options for multiple choice questions');
        return;
      }
      if (_correctAnswerIndex >= nonEmptyOptions.length) {
        _showErrorSnackBar('Please select a valid correct answer');
        return;
      }
      // Check if the selected correct answer option is not empty
      if (_optionControllers[_correctAnswerIndex].text.trim().isEmpty) {
        _showErrorSnackBar('The selected correct answer option cannot be empty');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Prepare choices for multiple choice
      List<Map<String, dynamic>> choices = [];
      if (_questionType == 'multiple_choice') {
        final nonEmptyOptions = _optionControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        
        for (int i = 0; i < nonEmptyOptions.length; i++) {
          choices.add({
            'text': nonEmptyOptions[i],
            'isCorrect': i == _correctAnswerIndex,
          });
        }
      }

      final questionData = {
        'courseId': widget.courseId,
        'createdBy': currentUser.id,
        'questionText': _questionController.text.trim(),
        'choices': choices,
        'difficulty': _difficulty,
        'explanation': _explanationController.text.trim().isEmpty 
            ? null 
            : _explanationController.text.trim(),
        'category': _categoryController.text.trim().isEmpty 
            ? null 
            : _categoryController.text.trim(),
        'tags': _tags,
      };

      print('🔧 Creating question with data: $questionData');
      await _questionService.createQuestion(questionData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      print('❌ Error creating question: $e');
      _showErrorSnackBar('Failed to create question: ${e.toString()}');
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Answer Options'),
        const SizedBox(height: 8),
        // Instructions for users
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
                  'Type or paste your answer options below. Select the radio button to mark the correct answer.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_optionControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Radio<int>(
                  value: index,
                  groupValue: _correctAnswerIndex,
                  onChanged: (value) {
                    setState(() {
                      _correctAnswerIndex = value!;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _optionControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Option ${String.fromCharCode(65 + index)}',
                      hintText: 'Type or paste your answer here...',
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _correctAnswerIndex == index ? Colors.green : Colors.grey.shade300,
                          width: _correctAnswerIndex == index ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _correctAnswerIndex == index ? Colors.green : Colors.blue,
                          width: 2,
                        ),
                      ),
                      prefixIcon: Icon(
                        _correctAnswerIndex == index ? Icons.check_circle : Icons.edit,
                        color: _correctAnswerIndex == index ? Colors.green : Colors.grey,
                      ),
                      suffixIcon: _optionControllers[index].text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _optionControllers[index].clear();
                                });
                              },
                            )
                          : null,
                    ),
                    maxLines: 2,
                    validator: index < 2 ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Option ${String.fromCharCode(65 + index)} is required';
                      }
                      return null;
                    } : null,
                    onChanged: (value) {
                      // Trigger rebuild to show/hide clear button
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Correct answer: Option ${String.fromCharCode(65 + _correctAnswerIndex)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tags (Optional)'),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Add tag',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addTag,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Question - ${widget.courseName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Details
              _buildSectionHeader('Question Details'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question Text *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.help_outline),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Question text is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Question Type
              DropdownButtonFormField<String>(
                value: _questionType,
                decoration: const InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.quiz),
                ),
                items: const [
                  DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
                  DropdownMenuItem(value: 'true_false', child: Text('True/False')),
                  DropdownMenuItem(value: 'short_answer', child: Text('Short Answer')),
                ],
                onChanged: (value) {
                  setState(() {
                    _questionType = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Multiple Choice Options (if applicable)
              if (_questionType == 'multiple_choice') ...[
                _buildMultipleChoiceOptions(),
                const SizedBox(height: 24),
              ],
              
              // Question Settings
              _buildSectionHeader('Question Settings'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.trending_up),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _difficulty = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pointsController,
                      decoration: const InputDecoration(
                        labelText: 'Points',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.star),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Points required';
                        }
                        final points = int.tryParse(value);
                        if (points == null || points <= 0) {
                          return 'Invalid points';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 24),
              
              // Tags
              _buildTagSection(),
              const SizedBox(height: 24),
              
              // Explanation
              _buildSectionHeader('Explanation (Optional)'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _explanationController,
                decoration: const InputDecoration(
                  labelText: 'Explanation',
                  hintText: 'Provide an explanation for the correct answer...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lightbulb_outline),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Question',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}