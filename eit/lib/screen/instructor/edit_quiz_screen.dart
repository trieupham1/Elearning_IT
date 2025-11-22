import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';

class EditQuizScreen extends StatefulWidget {
  final Quiz quiz;

  const EditQuizScreen({super.key, required this.quiz});

  @override
  State<EditQuizScreen> createState() => _EditQuizScreenState();
}

class _EditQuizScreenState extends State<EditQuizScreen> {
  final QuizService _quizService = QuizService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _maxAttemptsController;
  
  bool _allowRetakes = false;
  bool _shuffleQuestions = false;
  bool _showResultsImmediately = false;
  String _status = 'draft';
  DateTime? _openDate;
  DateTime? _closeDate;
  
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    _titleController = TextEditingController(text: widget.quiz.title);
    _descriptionController = TextEditingController(text: widget.quiz.description);
    _durationController = TextEditingController(text: widget.quiz.duration.toString());
    _maxAttemptsController = TextEditingController(
      text: widget.quiz.maxAttempts == -1 ? '' : widget.quiz.maxAttempts.toString()
    );
    
    _allowRetakes = widget.quiz.allowRetakes;
    _shuffleQuestions = widget.quiz.shuffleQuestions;
    _showResultsImmediately = widget.quiz.showResultsImmediately;
    _status = widget.quiz.status;
    _openDate = widget.quiz.openDate;
    _closeDate = widget.quiz.closeDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _maxAttemptsController.dispose();
    super.dispose();
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'duration': int.parse(_durationController.text),
        'maxAttempts': _maxAttemptsController.text.isEmpty 
            ? -1 
            : int.parse(_maxAttemptsController.text),
        'allowRetakes': _allowRetakes,
        'shuffleQuestions': _shuffleQuestions,
        'showResultsImmediately': _showResultsImmediately,
        'status': _status,
        'openDate': _openDate?.toIso8601String(),
        'closeDate': _closeDate?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      print('💾 EditQuiz: Saving quiz changes');
      print('💾 EditQuiz: Update data: $updateData');

      await _quizService.updateQuiz(widget.quiz.id, updateData);

      print('✅ EditQuiz: Successfully saved quiz changes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      print('❌ EditQuiz: Error saving quiz: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving quiz: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, {required bool isOpenDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isOpenDate 
          ? (_openDate ?? DateTime.now())
          : (_closeDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isOpenDate) {
            _openDate = selectedDateTime;
          } else {
            _closeDate = selectedDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Quiz'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveQuiz,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              
              _buildSettingsSection(),
              const SizedBox(height: 24),
              
              _buildSchedulingSection(),
              const SizedBox(height: 24),
              
              _buildStatusSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Quiz Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.quiz),
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
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quiz Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter duration';
                      }
                      final duration = int.tryParse(value);
                      if (duration == null || duration <= 0) {
                        return 'Please enter valid duration';
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
                      labelText: 'Max Attempts (empty for unlimited)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final attempts = int.tryParse(value);
                        if (attempts == null || attempts <= 0) {
                          return 'Please enter valid number';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
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
              title: const Text('Shuffle Questions'),
              subtitle: const Text('Questions will appear in random order'),
              value: _shuffleQuestions,
              onChanged: (value) {
                setState(() {
                  _shuffleQuestions = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Show Results Immediately'),
              subtitle: const Text('Show results after quiz completion'),
              value: _showResultsImmediately,
              onChanged: (value) {
                setState(() {
                  _showResultsImmediately = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scheduling',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Open Date'),
              subtitle: Text(
                _openDate != null
                    ? DateFormat('MMM dd, yyyy \'at\' HH:mm').format(_openDate!)
                    : 'Not set - available immediately',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_openDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _openDate = null;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _selectDate(context, isOpenDate: true),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Close Date'),
              subtitle: Text(
                _closeDate != null
                    ? DateFormat('MMM dd, yyyy \'at\' HH:mm').format(_closeDate!)
                    : 'Not set - available indefinitely',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_closeDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _closeDate = null;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _selectDate(context, isOpenDate: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quiz Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              items: [
                DropdownMenuItem(
                  value: 'draft',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Draft'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'active',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Active'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'inactive',
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Inactive'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _status = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            Text(
              _getStatusDescription(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDescription() {
    switch (_status) {
      case 'draft':
        return 'Quiz is in draft mode and not visible to students.';
      case 'active':
        return 'Quiz is active and available to students according to the schedule.';
      case 'inactive':
        return 'Quiz is inactive and temporarily unavailable to students.';
      default:
        return '';
    }
  }
}