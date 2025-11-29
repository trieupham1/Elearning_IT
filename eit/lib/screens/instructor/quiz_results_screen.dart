import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
// Note: dart:html import removed for mobile compatibility
// Web download functionality is disabled for mobile builds
import '../../services/quiz_service.dart';

class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizResultsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final QuizService _quizService = QuizService();
  
  Map<String, dynamic>? _resultsData;
  bool _isLoading = true;
  String? _error;
  
  // Filter and sort options
  String _sortBy = 'submissionTime'; // submissionTime, score, studentName
  bool _sortAscending = false;
  String _filterStatus = 'all'; // all, completed, in_progress
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use the grouped student results endpoint
      final results = await _quizService.getAllStudentQuizAttempts(widget.quizId);
      
      setState(() {
        _resultsData = results ?? {
          'totalAttempts': 0,
          'uniqueStudents': 0,
          'completedAttempts': 0,
          'averageScore': 0,
          'attempts': []
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getFilteredAndSortedAttempts() {
    if (_resultsData == null) return [];
    
    List<dynamic> attempts = List.from(_resultsData!['attempts'] ?? []);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      attempts = attempts.where((attempt) {
        final student = attempt['studentId'];
        final firstName = student?['firstName'] ?? '';
        final lastName = student?['lastName'] ?? '';
        final username = student?['username'] ?? '';
        final email = student?['email'] ?? '';
        
        final studentName = '$firstName $lastName'.trim();
        final displayName = studentName.isNotEmpty ? studentName : username;
        
        final query = _searchQuery.toLowerCase();
        return displayName.toLowerCase().contains(query) || email.toLowerCase().contains(query);
      }).toList();
    }
    
    // Sort attempts
    attempts.sort((a, b) {
      dynamic aValue, bValue;
      
      switch (_sortBy) {
        case 'studentName':
          final aStudent = a['studentId'];
          final bStudent = b['studentId'];
          aValue = '${aStudent?['firstName'] ?? ''} ${aStudent?['lastName'] ?? ''}'.trim();
          if (aValue.isEmpty) aValue = aStudent?['username'] ?? '';
          bValue = '${bStudent?['firstName'] ?? ''} ${bStudent?['lastName'] ?? ''}'.trim();
          if (bValue.isEmpty) bValue = bStudent?['username'] ?? '';
          break;
        case 'score':
          aValue = a['score'] ?? 0;
          bValue = b['score'] ?? 0;
          break;
        case 'submissionTime':
        default:
          aValue = a['submissionTime'] ?? '';
          bValue = b['submissionTime'] ?? '';
          break;
      }
      
      int comparison = 0;
      if (aValue is String && bValue is String) {
        comparison = aValue.compareTo(bValue);
      } else if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return attempts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Results: ${widget.quizTitle}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadResults,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Results',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cleanup',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('Cleanup Expired'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Quiz Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildResultsContent(),
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
            'Failed to load results',
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
            onPressed: _loadResults,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    final attempts = _getFilteredAndSortedAttempts();
    
    return Column(
      children: [
        // Summary cards
        _buildSummaryCards(),
        
        // Filters and search
        _buildFiltersAndSearch(),
        
        // Results list
        Expanded(
          child: attempts.isEmpty
              ? _buildEmptyState()
              : _buildAttemptsList(attempts),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    if (_resultsData == null) return const SizedBox();
    
    final totalAttempts = _resultsData!['totalAttempts'] ?? 0;
    final uniqueStudents = _resultsData!['uniqueStudents'] ?? 0;
    final completedAttempts = _resultsData!['completedAttempts'] ?? 0;
    final averageScore = _resultsData!['averageScore'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Attempts',
              totalAttempts.toString(),
              Icons.quiz,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Students',
              uniqueStudents.toString(),
              Icons.people,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Completed',
              completedAttempts.toString(),
              Icons.check_circle,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Avg Score',
              '${averageScore}%',
              Icons.star,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
                fontSize: 20,
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by student name or email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Filter and sort options
          Row(
            children: [
              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterStatus,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Sort by
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'submissionTime', child: Text('Submission Time')),
                    DropdownMenuItem(value: 'score', child: Text('Score')),
                    DropdownMenuItem(value: 'studentName', child: Text('Student Name')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              
              // Sort direction
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                tooltip: _sortAscending ? 'Ascending' : 'Descending',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No quiz attempts found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Students haven\'t taken this quiz yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsList(List<dynamic> studentResults) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: studentResults.length,
      itemBuilder: (context, index) {
        final studentResult = studentResults[index];
        return _buildStudentResultCard(studentResult);
      },
    );
  }

  Widget _buildStudentResultCard(Map<String, dynamic> attempt) {
    final student = attempt['studentId'] ?? {};
    final firstName = student['firstName'] ?? '';
    final lastName = student['lastName'] ?? '';
    final username = student['username'] ?? '';
    final email = student['email'] ?? 'No email';
    
    String studentName = '$firstName $lastName'.trim();
    if (studentName.isEmpty) {
      studentName = username.isNotEmpty ? username : 'Unknown Student';
    }
    
    final bestScore = attempt['score'] ?? 0;
    final totalAttempts = attempt['totalStudentAttempts'] ?? 1;
    final correctAnswers = attempt['correctAnswers'] ?? 0;
    final totalQuestions = attempt['totalQuestions'] ?? 0;
    final lastSubmission = attempt['submissionTime'];
    final timeSpent = attempt['timeSpent'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with student info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status badge  
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade300,
                    ),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Best Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getScoreColor(bestScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getScoreColor(bestScore).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${bestScore}%',
                    style: TextStyle(
                      color: _getScoreColor(bestScore),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Details row
            Row(
              children: [
                _buildDetailChip(
                  Icons.repeat,
                  totalAttempts > 1 
                      ? '$totalAttempts attempts'
                      : 'Single attempt',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  Icons.check_circle,
                  '$correctAnswers/$totalQuestions correct',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  Icons.timer,
                  _formatDuration(timeSpent),
                  Colors.orange,
                ),
              ],
            ),
            
            // Last submission time
            if (lastSubmission != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Last submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(lastSubmission))}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
            
            // Actions
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _viewAttemptDetails(attempt),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;
    
    switch (status) {
      case 'submitted':
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case 'auto_submitted':
        color = Colors.orange;
        label = 'Auto-submitted';
        icon = Icons.timer;
        break;
      case 'in_progress':
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.play_circle;
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
        icon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportResults();
        break;
      case 'cleanup':
        _cleanupExpiredAttempts();
        break;
      case 'settings':
        _openQuizSettings();
        break;
    }
  }

  Future<void> _exportResults() async {
    try {
      setState(() => _isLoading = true);
      
      final csvContent = await _quizService.exportQuizResults(widget.quizId);
      
      // For web, create a download
      if (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android) {
        // On mobile, show the CSV content or save to downloads
        _showCsvDialog(csvContent);
      } else {
        // For web, trigger download
        _downloadCsv(csvContent);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz results exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export results: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanupExpiredAttempts() async {
    try {
      await _quizService.autoCloseExpiredQuizzes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expired quizzes closed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadResults(); // Refresh the results
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close expired quizzes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewAttemptDetails(Map<String, dynamic> attempt) async {
    try {
      setState(() => _isLoading = true);
      
      final student = attempt['studentId'];
      final studentId = student['_id'].toString();
      final firstName = student['firstName'] ?? '';
      final lastName = student['lastName'] ?? '';
      final username = student['username'] ?? '';
      
      String studentName = '$firstName $lastName'.trim();
      if (studentName.isEmpty) {
        studentName = username.isNotEmpty ? username : 'Unknown Student';
      }
      
      print('🔍 Getting all attempts for student: $studentId, quiz: ${widget.quizId}');
      
      // Get all attempts for this student
      final allAttempts = await _quizService.getStudentAllAttempts(studentId, widget.quizId);
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        if (allAttempts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No attempts found for this student'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        print('✅ Got ${allAttempts.length} attempts for student: $studentName');
        
        // Show attempt selection dialog
        _showAttemptSelectionDialog(studentName, allAttempts);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading student attempts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleExpiredAttempt(Map<String, dynamic> attempt) {
    // TODO: Handle expired attempt checking/auto-submission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking attempt status...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showCsvDialog(String csvContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Export'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              csvContent,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Copy to clipboard functionality could be added here
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _downloadCsv(String csvContent) async {
    try {
      // Create filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final filename = '${widget.quizTitle.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '_')}_results_$timestamp.csv';

      // Note: Web download functionality disabled for mobile builds
      // To enable web support, add conditional imports for dart:html

      // Mobile platforms - use share functionality
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quiz Results CSV Export',
      );

      print('CSV file shared: $filename');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV file "$filename" ready to share!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('CSV download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
      // Fallback to dialog
      _showCsvDialog(csvContent);
    }
  }

  void _showAttemptSelectionDialog(String studentName, List<Map<String, dynamic>> attempts) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Attempt to View',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$studentName • ${attempts.length} attempt${attempts.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Attempts list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    return _buildAttemptSelectionCard(attempt, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttemptSelectionCard(Map<String, dynamic> attempt, int index) {
    final score = attempt['score'] ?? 0;
    final correctAnswers = attempt['correctAnswers'] ?? 0;
    final totalQuestions = attempt['totalQuestions'] ?? 0;
    final timeSpent = attempt['timeSpent'] ?? 0;
    final submissionTime = attempt['submissionTime'];
    final attemptNumber = attempt['attemptNumber'] ?? (index + 1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          Navigator.of(context).pop(); // Close selection dialog
          
          try {
            setState(() => _isLoading = true);
            
            final detailedAttempt = await _quizService.getAttemptDetails(attempt['_id']);
            
            setState(() => _isLoading = false);
            
            if (mounted) {
              _showAttemptDetailsDialog(detailedAttempt);
            }
          } catch (e) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading attempt details: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Attempt number badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Center(
                  child: Text(
                    '#$attemptNumber',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Attempt details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Score: ${score}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(score),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$correctAnswers/$totalQuestions correct',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(timeSpent),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (submissionTime != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, HH:mm').format(DateTime.parse(submissionTime)),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // View arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttemptDetailsDialog(Map<String, dynamic> detailedAttempt) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attempt Details',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${detailedAttempt['student']['name']} • ${detailedAttempt['quiz']['title']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    _buildSummaryItem(
                      'Score',
                      '${detailedAttempt['score']}%',
                      Icons.grade,
                      _getScoreColor(detailedAttempt['score']),
                    ),
                    _buildSummaryItem(
                      'Correct',
                      '${detailedAttempt['correctAnswers']}/${detailedAttempt['totalQuestions']}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildSummaryItem(
                      'Time',
                      _formatDuration(detailedAttempt['timeSpent'] ?? 0),
                      Icons.timer,
                      Colors.orange,
                    ),
                    _buildSummaryItem(
                      'Attempt',
                      '#${detailedAttempt['attemptNumber']}',
                      Icons.repeat,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
              
              // Questions list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: detailedAttempt['questions']?.length ?? 0,
                  itemBuilder: (context, index) {
                    final question = detailedAttempt['questions'][index];
                    return _buildQuestionDetailCard(question, index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionDetailCard(Map<String, dynamic> question, int questionNumber) {
    final isCorrect = question['isCorrect'] ?? false;
    final studentAnswers = List<String>.from(question['studentAnswer'] ?? []);
    final choices = List<Map<String, dynamic>>.from(question['choices'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCorrect ? Icons.check : Icons.close,
                        size: 16,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Question $questionNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildDifficultyChip(question['difficulty'] ?? 'Unknown'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Question text
            Text(
              question['questionText'] ?? 'Question text not available',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Answer choices
            ...choices.asMap().entries.map((entry) {
              final choiceIndex = entry.key;
              final choice = entry.value;
              final choiceText = choice['text'] ?? '';
              final isChoiceCorrect = choice['isCorrect'] ?? false;
              final isStudentChoice = studentAnswers.contains(choiceText);
              
              Color backgroundColor = Colors.grey.shade50;
              Color borderColor = Colors.grey.shade300;
              IconData? icon;
              
              if (isStudentChoice && isChoiceCorrect) {
                // Student chose correct answer
                backgroundColor = Colors.green.shade50;
                borderColor = Colors.green;
                icon = Icons.check_circle;
              } else if (isStudentChoice && !isChoiceCorrect) {
                // Student chose wrong answer
                backgroundColor = Colors.red.shade50;
                borderColor = Colors.red;
                icon = Icons.cancel;
              } else if (!isStudentChoice && isChoiceCorrect) {
                // Correct answer not chosen by student
                backgroundColor = Colors.blue.shade50;
                borderColor = Colors.blue;
                icon = Icons.info;
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Text(
                      String.fromCharCode(65 + choiceIndex), // A, B, C, D
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        choiceText,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: borderColor, size: 20),
                    ],
                  ],
                ),
              );
            }).toList(),
            
            // Time spent on this question
            if (question['timeSpent'] != null && question['timeSpent'] > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Time spent: ${_formatDuration(question['timeSpent'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _openQuizSettings() async {
    try {
      print('🔧 Opening quiz settings for quiz: ${widget.quizId}');
      final result = await Navigator.pushNamed(
        context,
        '/quiz-settings',
        arguments: {
          'quizId': widget.quizId,
        },
      );
      
      print('🔧 Quiz settings result: $result');
      if (result == true) {
        // Settings were updated, refresh the results
        _loadResults();
      }
    } catch (e) {
      print('❌ Error opening quiz settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open quiz settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}