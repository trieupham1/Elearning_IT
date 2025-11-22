// screens/student/assignment_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../models/assignment_submission.dart';
import '../../services/assignment_service.dart';
import '../../services/file_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentDetailScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final FileService _fileService = FileService();

  Assignment? _assignment;
  List<AssignmentSubmission> _mySubmissions = [];
  List<SubmissionFile> _selectedFiles = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final assignment = await _assignmentService.getAssignment(
        widget.assignmentId,
      );
      final submissions = await _assignmentService.getMySubmissions(
        widget.assignmentId,
      );

      setState(() {
        _assignment = assignment;
        _mySubmissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading assignment: $e')));
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await _fileService.pickFile();
      if (result != null) {
        // Validate file
        if (_assignment != null) {
          // Check file size
          if (result.size > _assignment!.maxFileSize) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File too large. Maximum size: ${_formatFileSize(_assignment!.maxFileSize)}',
                ),
              ),
            );
            return;
          }

          // Check file type
          if (_assignment!.allowedFileTypes.isNotEmpty) {
            final ext = '.${result.name.split('.').last.toLowerCase()}';
            if (!_assignment!.allowedFileTypes.contains(ext)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'File type not allowed. Allowed types: ${_assignment!.allowedFileTypes.join(", ")}',
                  ),
                ),
              );
              return;
            }
          }
        }

        // Upload file
        final uploadedFile = await _fileService.uploadFile(result);
        setState(() {
          _selectedFiles.add(
            SubmissionFile(
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

  Future<void> _submitAssignment() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one file')),
      );
      return;
    }

    // Confirm submission
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Assignment'),
        content: Text(
          'Are you sure you want to submit this assignment?\n\nAttempt ${_mySubmissions.length + 1} of ${_assignment?.maxAttempts ?? 1}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      await _assignmentService.submitAssignment(
        assignmentId: widget.assignmentId,
        files: _selectedFiles,
      );

      setState(() {
        _selectedFiles.clear();
        _isSubmitting = false;
      });

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting assignment: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'late submission open':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      case 'upcoming':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment')),
        body: const Center(child: Text('Assignment not found')),
      );
    }

    final assignment = _assignment!;
    final latestSubmission = _mySubmissions.isNotEmpty
        ? _mySubmissions.last
        : null;
    final canSubmit = _assignmentService.canSubmit(
      assignment,
      _mySubmissions.length,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Assignment Title & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.grade, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${assignment.points} points',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(assignment.status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  assignment.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submission Status Card
          _buildSubmissionStatusCard(latestSubmission),
          const SizedBox(height: 24),

          // Deadlines Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Deadlines',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildDeadlineRow('Start Date', assignment.startDate),
                  const SizedBox(height: 8),
                  _buildDeadlineRow(
                    'Due Date',
                    assignment.deadline,
                    isDeadline: true,
                  ),
                  if (assignment.allowLateSubmission &&
                      assignment.lateDeadline != null) ...[
                    const SizedBox(height: 8),
                    _buildDeadlineRow(
                      'Late Deadline',
                      assignment.lateDeadline!,
                      isLate: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          _assignmentService.getTimeRemaining(
                            assignment.deadline,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          if (assignment.description != null &&
              assignment.description!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(assignment.description!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Instructor Attachments
          if (assignment.attachments.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Attachments',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...assignment.attachments.map(
                      (file) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(file.fileName),
                        subtitle: Text(_formatFileSize(file.fileSize)),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () =>
                              _downloadFile(file.fileUrl, file.fileName),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submission Requirements
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rule, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        'Submission Requirements',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildRequirementRow(
                    'Maximum Attempts',
                    '${assignment.maxAttempts}',
                  ),
                  _buildRequirementRow(
                    'Max File Size',
                    _formatFileSize(assignment.maxFileSize),
                  ),
                  if (assignment.allowedFileTypes.isNotEmpty)
                    _buildRequirementRow(
                      'Allowed File Types',
                      assignment.allowedFileTypes.join(', '),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submission Section
          if (canSubmit) ...[
            Text(
              'Your Submission',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Attempt ${_mySubmissions.length + 1} of ${assignment.maxAttempts}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // File Upload Area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text(
                    'Add files to submit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max ${_formatFileSize(assignment.maxFileSize)} per file',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add File'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selected Files List
            if (_selectedFiles.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Files (${_selectedFiles.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    ..._selectedFiles.map(
                      (file) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(file.fileName),
                        subtitle: Text(_formatFileSize(file.fileSize)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _selectedFiles.remove(file);
                                  });
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAssignment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Assignment',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _mySubmissions.length >= assignment.maxAttempts
                          ? 'You have used all ${assignment.maxAttempts} attempts'
                          : 'Submission is not available at this time',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Previous Submissions
          if (_mySubmissions.isNotEmpty) ...[
            Text(
              'Previous Submissions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._mySubmissions.reversed.map(
              (submission) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: submission.isGraded
                        ? Colors.green
                        : Colors.blue,
                    child: Text(
                      '#${submission.attemptNumber}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text('Attempt ${submission.attemptNumber}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(submission.submittedAt)),
                      Row(
                        children: [
                          if (submission.isLate)
                            Container(
                              margin: const EdgeInsets.only(right: 8, top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LATE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: submission.isGraded
                                  ? Colors.green
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              submission.statusDisplay.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: submission.isGraded
                      ? Chip(
                          label: Text(
                            '${submission.grade!.toStringAsFixed(1)}/${assignment.points}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Files
                          const Text(
                            'Submitted Files:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...submission.files.map(
                            (file) => ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(file.fileName),
                              subtitle: Text(_formatFileSize(file.fileSize)),
                              trailing: IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () =>
                                    _downloadFile(file.fileUrl, file.fileName),
                              ),
                            ),
                          ),

                          // Grade & Feedback
                          if (submission.isGraded) ...[
                            const Divider(),
                            const Text(
                              'Grade & Feedback:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.grade,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${submission.grade!.toStringAsFixed(1)} / ${assignment.points}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (submission.feedback != null &&
                                      submission.feedback!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Feedback:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(submission.feedback!),
                                  ],
                                  if (submission.gradedAt != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Graded on ${_formatDateTime(submission.gradedAt!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSubmissionStatusCard(AssignmentSubmission? latestSubmission) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (latestSubmission == null) {
      statusColor = Colors.orange;
      statusText = 'No Submission';
      statusIcon = Icons.assignment_late;
    } else if (latestSubmission.isGraded) {
      statusColor = Colors.green;
      statusText = 'Graded';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.blue;
      statusText = 'Submitted';
      statusIcon = Icons.assignment_turned_in;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, size: 40, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submission Status',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (latestSubmission != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Submitted on ${_formatDateTime(latestSubmission.submittedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (latestSubmission != null && latestSubmission.isGraded)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Grade',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      '${latestSubmission.grade!.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/ ${_assignment!.points}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineRow(
    String label,
    DateTime dateTime, {
    bool isDeadline = false,
    bool isLate = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isDeadline ? FontWeight.bold : FontWeight.normal,
              color: isLate ? Colors.orange : null,
            ),
          ),
        ),
        Text(
          _formatDateTime(dateTime),
          style: TextStyle(
            fontWeight: isDeadline ? FontWeight.bold : FontWeight.normal,
            color: isLate ? Colors.orange : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
