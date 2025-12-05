// screens/instructor/assignment_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/assignment_tracking.dart';
import '../../services/assignment_service.dart';
import '../../utils/download_helper.dart';

class AssignmentTrackingScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentTrackingScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentTrackingScreen> createState() =>
      _AssignmentTrackingScreenState();
}

class _AssignmentTrackingScreenState extends State<AssignmentTrackingScreen> {
  final AssignmentService _assignmentService = AssignmentService();

  AssignmentTracking? _trackingData;
  List<StudentTrackingData> _filteredStudents = [];
  String _searchQuery = '';
  String _filter = 'all'; // all, submitted, not_submitted, late, graded
  String _sortBy = 'name'; // name, group, date, grade, status
  bool _sortAscending = true;

  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
  }

  Future<void> _loadTrackingData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _assignmentService.getTrackingData(
        widget.assignmentId,
      );
      setState(() {
        _trackingData = data;
        _filteredStudents = data.students;
        _isLoading = false;
      });
      _applyFiltersAndSort();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tracking data: $e')),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    if (_trackingData == null) return;

    List<StudentTrackingData> filtered = List.from(_trackingData!.students);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((student) {
        return student.studentName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (student.studentEmail?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false) ||
            (student.groupName?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }).toList();
    }

    // Apply filter
    switch (_filter) {
      case 'submitted':
        filtered = filtered.where((s) => s.hasSubmitted).toList();
        break;
      case 'not_submitted':
        filtered = filtered.where((s) => !s.hasSubmitted).toList();
        break;
      case 'late':
        filtered = filtered
            .where(
              (s) =>
                  s.hasSubmitted &&
                  s.latestSubmission != null &&
                  s.latestSubmission!.isLate,
            )
            .toList();
        break;
      case 'graded':
        filtered = filtered
            .where(
              (s) =>
                  s.hasSubmitted &&
                  s.latestSubmission != null &&
                  s.latestSubmission!.isGraded,
            )
            .toList();
        break;
    }

    // Apply sort
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.studentName.compareTo(b.studentName);
          break;
        case 'group':
          comparison = (a.groupName ?? '').compareTo(b.groupName ?? '');
          break;
        case 'date':
          if (a.latestSubmission == null && b.latestSubmission == null) {
            comparison = 0;
          } else if (a.latestSubmission == null) {
            comparison = 1;
          } else if (b.latestSubmission == null) {
            comparison = -1;
          } else {
            comparison = a.latestSubmission!.submittedAt.compareTo(
              b.latestSubmission!.submittedAt,
            );
          }
          break;
        case 'grade':
          final aGrade = a.latestSubmission?.grade ?? -1;
          final bGrade = b.latestSubmission?.grade ?? -1;
          comparison = aGrade.compareTo(bGrade);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredStudents = filtered;
    });
  }

  Future<void> _exportCSV() async {
    if (_trackingData == null) return;

    setState(() => _isExporting = true);
    try {
      final csvData = await _assignmentService.exportTrackingCSV(
        widget.assignmentId,
      );

      final fileName = 'assignment_${_trackingData!.assignmentInfo.title.replaceAll(' ', '_')}_tracking.csv';

      // Use platform-specific download helper
      await downloadCSV(csvData, fileName);

      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported successfully')),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e')));
      }
    }
  }

  Future<void> _showGradeDialog(StudentTrackingData student) async {
    if (student.latestSubmission == null) return;

    final gradeController = TextEditingController(
      text: student.latestSubmission!.grade?.toString() ?? '',
    );
    final feedbackController = TextEditingController(
      text: student.latestSubmission!.feedback ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grade - ${student.studentName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Submission Info
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Attempt ${student.latestSubmission!.attemptNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (student.latestSubmission!.isLate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LATE',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(student.latestSubmission!.submittedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Submitted Files Section
                if (student.latestSubmission!.files.isNotEmpty) ...[
                  const Text(
                    'Submitted Files:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: student.latestSubmission!.files.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade300),
                      itemBuilder: (context, index) {
                        final file = student.latestSubmission!.files[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.attach_file,
                            color: Colors.blue.shade700,
                          ),
                          title: Text(
                            file.fileName,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            _formatFileSize(file.fileSize),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.download, size: 20),
                            tooltip: 'Download',
                            onPressed: () =>
                                _downloadFile(file.fileUrl, file.fileName),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Grade Input
                TextField(
                  controller: gradeController,
                  decoration: InputDecoration(
                    labelText:
                        'Grade (0-${_trackingData!.assignmentInfo.points})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.grade),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Feedback Input
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Feedback (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final grade = double.tryParse(gradeController.text);
              if (grade == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid grade')),
                );
                return;
              }
              if (grade < 0 || grade > _trackingData!.assignmentInfo.points) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Grade must be between 0 and ${_trackingData!.assignmentInfo.points}',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'grade': grade,
                'feedback': feedbackController.text,
              });
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _gradeSubmission(
        student.allSubmissions.last.id,
        result['grade'],
        result['feedback'],
      );
    }

    gradeController.dispose();
    feedbackController.dispose();
  }

  Future<void> _gradeSubmission(
    String submissionId,
    double grade,
    String feedback,
  ) async {
    try {
      await _assignmentService.gradeSubmission(
        submissionId: submissionId,
        grade: grade,
        feedback: feedback,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grade saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload data
      await _loadTrackingData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving grade: $e')));
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trackingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Tracking')),
        body: const Center(child: Text('No data available')),
      );
    }

    final stats = _trackingData!.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Tracking'),
        actions: [
          if (_isExporting)
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
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportCSV,
              tooltip: 'Export CSV',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrackingData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trackingData!.assignmentInfo.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard(
                      'Total Students',
                      stats.totalStudents.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Submitted',
                      '${stats.submitted} (${stats.submissionRate.toStringAsFixed(0)}%)',
                      Icons.assignment_turned_in,
                      Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Not Submitted',
                      stats.notSubmitted.toString(),
                      Icons.assignment_late,
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatCard(
                      'Late',
                      stats.lateSubmissions.toString(),
                      Icons.warning,
                      Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Graded',
                      '${stats.graded} (${stats.gradingProgress.toStringAsFixed(0)}%)',
                      Icons.grade,
                      Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Avg Grade',
                      stats.averageGrade ?? 'N/A',
                      Icons.analytics,
                      Colors.indigo,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or group...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                              _applyFiltersAndSort();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _applyFiltersAndSort();
                  },
                ),
                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _filter == 'all',
                        onSelected: (selected) {
                          setState(() => _filter = 'all');
                          _applyFiltersAndSort();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Submitted'),
                        selected: _filter == 'submitted',
                        onSelected: (selected) {
                          setState(() => _filter = 'submitted');
                          _applyFiltersAndSort();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Not Submitted'),
                        selected: _filter == 'not_submitted',
                        onSelected: (selected) {
                          setState(() => _filter = 'not_submitted');
                          _applyFiltersAndSort();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Late'),
                        selected: _filter == 'late',
                        onSelected: (selected) {
                          setState(() => _filter = 'late');
                          _applyFiltersAndSort();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Graded'),
                        selected: _filter == 'graded',
                        onSelected: (selected) {
                          setState(() => _filter = 'graded');
                          _applyFiltersAndSort();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sort Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Text(
                  'Sort by: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'group', child: Text('Group')),
                    DropdownMenuItem(
                      value: 'date',
                      child: Text('Submission Date'),
                    ),
                    DropdownMenuItem(value: 'grade', child: Text('Grade')),
                    DropdownMenuItem(value: 'status', child: Text('Status')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                      _applyFiltersAndSort();
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  onPressed: () {
                    setState(() => _sortAscending = !_sortAscending);
                    _applyFiltersAndSort();
                  },
                  tooltip: _sortAscending ? 'Ascending' : 'Descending',
                ),
                const Spacer(),
                Text(
                  '${_filteredStudents.length} students',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: _filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No students found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];
                      return _buildStudentCard(student);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }

  Widget _buildStudentCard(StudentTrackingData student) {
    Color statusColor;
    IconData statusIcon;

    if (!student.hasSubmitted) {
      statusColor = Colors.orange;
      statusIcon = Icons.assignment_late;
    } else if (student.latestSubmission!.isGraded) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (student.latestSubmission!.isLate) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.assignment_turned_in;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          student.studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (student.studentEmail != null)
              Text(
                student.studentEmail!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Row(
              children: [
                if (student.groupName != null) ...[
                  Icon(Icons.group, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    student.groupName!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                ],
                if (student.hasSubmitted &&
                    student.latestSubmission != null) ...[
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(student.latestSubmission!.submittedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            if (student.submissionCount > 1)
              Text(
                'Attempt ${student.latestSubmission!.attemptNumber} of ${student.submissionCount}',
                style: const TextStyle(fontSize: 12, color: Colors.purple),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (student.hasSubmitted && student.latestSubmission != null) ...[
              if (student.latestSubmission!.isGraded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${student.latestSubmission!.grade!.toStringAsFixed(1)}/${_trackingData!.assignmentInfo.points}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _showGradeDialog(student),
                  icon: const Icon(Icons.grade, size: 16),
                  label: const Text('Grade'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'No Submission',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: student.hasSubmitted ? () => _showGradeDialog(student) : null,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      print('DEBUG: Original fileUrl: $fileUrl');

      // Fix malformed URLs that have /api/api/
      String correctedUrl = fileUrl;
      if (fileUrl.contains('/api/api/')) {
        correctedUrl = fileUrl.replaceAll('/api/api/', '/api/');
        print('DEBUG: Fixed duplicate /api/api/ -> /api/');
      }

      print('DEBUG: Attempting to download file from URL: $correctedUrl');
      final uri = Uri.parse(correctedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $correctedUrl';
      }
    } catch (e) {
      print('DEBUG: Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading file: $e')));
      }
    }
  }
}
