// screens/instructor/create_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/assignment.dart';
import '../../models/group.dart';
import '../../services/assignment_service.dart';
import '../../services/group_service.dart';
import '../../services/file_service.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final String courseId;
  final Assignment? assignment; // For editing existing assignment

  const CreateAssignmentScreen({
    super.key,
    required this.courseId,
    this.assignment,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final AssignmentService _assignmentService = AssignmentService();
  final FileService _fileService = FileService();

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController(
    text: '100',
  );
  final TextEditingController _maxAttemptsController = TextEditingController(
    text: '1',
  );
  final TextEditingController _maxFileSizeController = TextEditingController(
    text: '10',
  );

  // Date/Time fields
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _deadlineTime = const TimeOfDay(hour: 23, minute: 59);
  DateTime? _lateDeadline;
  TimeOfDay? _lateDeadlineTime;

  // Settings
  bool _allowLateSubmission = false;
  List<String> _selectedGroups = [];
  List<Group> _availableGroups = [];
  List<String> _selectedFileTypes = [];
  List<AssignmentAttachment> _attachments = [];

  // File type options
  final List<String> _fileTypeOptions = [
    '.pdf',
    '.doc',
    '.docx',
    '.txt',
    '.jpg',
    '.jpeg',
    '.png',
    '.zip',
    '.rar',
  ];

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _initializeForEdit();
  }

  void _initializeForEdit() {
    if (widget.assignment != null) {
      final assignment = widget.assignment!;
      _titleController.text = assignment.title;
      _descriptionController.text = assignment.description ?? '';
      _pointsController.text = assignment.points.toString();
      _maxAttemptsController.text = assignment.maxAttempts.toString();
      _maxFileSizeController.text = (assignment.maxFileSize / (1024 * 1024))
          .toString();

      _startDate = assignment.startDate;
      _startTime = TimeOfDay.fromDateTime(assignment.startDate);
      _deadline = assignment.deadline;
      _deadlineTime = TimeOfDay.fromDateTime(assignment.deadline);

      _allowLateSubmission = assignment.allowLateSubmission;
      if (assignment.lateDeadline != null) {
        _lateDeadline = assignment.lateDeadline;
        _lateDeadlineTime = TimeOfDay.fromDateTime(assignment.lateDeadline!);
      }

      _selectedGroups = assignment.groupIds;
      _selectedFileTypes = assignment.allowedFileTypes;
      _attachments = assignment.attachments;
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await GroupService.getGroupsByCourse(widget.courseId);
      setState(() {
        _availableGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading groups: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await _fileService.pickFile();
      if (result != null) {
        // Upload file
        final uploadedFile = await _fileService.uploadFile(result);
        setState(() {
          _attachments.add(
            AssignmentAttachment(
              fileName: uploadedFile['fileName'],
              fileUrl: uploadedFile['fileUrl'],
              fileSize: uploadedFile['fileSize'],
              mimeType: uploadedFile['mimeType'],
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
      }
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation
    final startDateTime = _combineDateAndTime(_startDate, _startTime);
    final deadlineDateTime = _combineDateAndTime(_deadline, _deadlineTime);
    DateTime? lateDeadlineDateTime;

    if (_allowLateSubmission &&
        _lateDeadline != null &&
        _lateDeadlineTime != null) {
      lateDeadlineDateTime = _combineDateAndTime(
        _lateDeadline!,
        _lateDeadlineTime!,
      );

      if (lateDeadlineDateTime.isBefore(deadlineDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Late deadline must be after the deadline'),
          ),
        );
        return;
      }
    }

    if (deadlineDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deadline must be after start date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final maxFileSize =
          (double.parse(_maxFileSizeController.text) * 1024 * 1024).toInt();

      if (widget.assignment == null) {
        // Create new
        await _assignmentService.createAssignment(
          courseId: widget.courseId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          groupIds: _selectedGroups,
          startDate: startDateTime,
          deadline: deadlineDateTime,
          allowLateSubmission: _allowLateSubmission,
          lateDeadline: lateDeadlineDateTime,
          maxAttempts: int.parse(_maxAttemptsController.text),
          allowedFileTypes: _selectedFileTypes,
          maxFileSize: maxFileSize,
          attachments: _attachments,
          points: int.parse(_pointsController.text),
        );
      } else {
        // Update existing
        await _assignmentService.updateAssignment(widget.assignment!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'groupIds': _selectedGroups,
          'startDate': startDateTime.toIso8601String(),
          'deadline': deadlineDateTime.toIso8601String(),
          'allowLateSubmission': _allowLateSubmission,
          'lateDeadline': lateDeadlineDateTime?.toIso8601String(),
          'maxAttempts': int.parse(_maxAttemptsController.text),
          'allowedFileTypes': _selectedFileTypes,
          'maxFileSize': maxFileSize,
          'attachments': _attachments.map((a) => a.toJson()).toList(),
          'points': int.parse(_pointsController.text),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.assignment == null
                  ? 'Assignment created successfully'
                  : 'Assignment updated successfully',
            ),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving assignment: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _maxAttemptsController.dispose();
    _maxFileSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assignment == null ? 'Create Assignment' : 'Edit Assignment',
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveAssignment,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Title *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),

                  // Points
                  TextFormField(
                    controller: _pointsController,
                    decoration: const InputDecoration(
                      labelText: 'Points *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.grade),
                      suffixText: 'pts',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter points';
                      }
                      final points = int.tryParse(value);
                      if (points == null || points <= 0) {
                        return 'Points must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Date/Time Section
                  Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  // Start Date & Time
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Date'),
                          subtitle: Text(
                            '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                          ),
                          leading: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() => _startDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(_startTime.format(context)),
                          leading: const Icon(Icons.access_time),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (time != null) {
                              setState(() => _startTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Deadline Date & Time
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Deadline'),
                          subtitle: Text(
                            '${_deadline.day}/${_deadline.month}/${_deadline.year}',
                          ),
                          leading: const Icon(Icons.event_busy),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _deadline,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() => _deadline = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListTile(
                          title: const Text('Time'),
                          subtitle: Text(_deadlineTime.format(context)),
                          leading: const Icon(Icons.alarm),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _deadlineTime,
                            );
                            if (time != null) {
                              setState(() => _deadlineTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Allow Late Submission
                  SwitchListTile(
                    title: const Text('Allow Late Submission'),
                    subtitle: const Text(
                      'Students can submit after the deadline',
                    ),
                    value: _allowLateSubmission,
                    onChanged: (value) {
                      setState(() {
                        _allowLateSubmission = value;
                        if (value && _lateDeadline == null) {
                          _lateDeadline = _deadline.add(
                            const Duration(days: 2),
                          );
                          _lateDeadlineTime = _deadlineTime;
                        }
                      });
                    },
                  ),

                  // Late Deadline (conditional)
                  if (_allowLateSubmission) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Late Deadline'),
                            subtitle: Text(
                              _lateDeadline != null
                                  ? '${_lateDeadline!.day}/${_lateDeadline!.month}/${_lateDeadline!.year}'
                                  : 'Not set',
                            ),
                            leading: const Icon(Icons.event_available),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate:
                                    _lateDeadline ??
                                    _deadline.add(const Duration(days: 2)),
                                firstDate: _deadline,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() => _lateDeadline = date);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ListTile(
                            title: const Text('Time'),
                            subtitle: Text(
                              _lateDeadlineTime?.format(context) ?? 'Not set',
                            ),
                            leading: const Icon(Icons.alarm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _lateDeadlineTime ?? _deadlineTime,
                              );
                              if (time != null) {
                                setState(() => _lateDeadlineTime = time);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Submission Settings
                  Text(
                    'Submission Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  // Max Attempts
                  TextFormField(
                    controller: _maxAttemptsController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Attempts *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat),
                      helperText: 'Number of times a student can submit',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter maximum attempts';
                      }
                      final attempts = int.tryParse(value);
                      if (attempts == null || attempts <= 0) {
                        return 'Attempts must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Max File Size
                  TextFormField(
                    controller: _maxFileSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum File Size *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storage),
                      suffixText: 'MB',
                      helperText: 'Maximum size per file',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter maximum file size';
                      }
                      final size = double.tryParse(value);
                      if (size == null || size <= 0) {
                        return 'Size must be greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Allowed File Types
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.file_present),
                            const SizedBox(width: 8),
                            Text(
                              'Allowed File Types',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Leave empty to allow all file types',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _fileTypeOptions.map((type) {
                            final isSelected = _selectedFileTypes.contains(
                              type,
                            );
                            return FilterChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedFileTypes.add(type);
                                  } else {
                                    _selectedFileTypes.remove(type);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Group Selection
                  Text(
                    'Target Groups',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leave empty to assign to all students',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _availableGroups.isEmpty
                        ? const Text('No groups available')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableGroups.map((group) {
                              final isSelected = _selectedGroups.contains(
                                group.id,
                              );
                              return FilterChip(
                                label: Text(group.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedGroups.add(group.id);
                                    } else {
                                      _selectedGroups.remove(group.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Attachments
                  Text(
                    'Attachments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Add File'),
                  ),
                  const SizedBox(height: 12),
                  if (_attachments.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _attachments.map((attachment) {
                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(attachment.fileName),
                            subtitle: Text(
                              _formatFileSize(attachment.fileSize),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _attachments.remove(attachment);
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
