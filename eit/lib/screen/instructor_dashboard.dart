import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../services/semester_service.dart';
import '../services/dashboard_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/semester.dart';
import 'course_detail_screen.dart';

class InstructorDashboard extends StatefulWidget {
  const InstructorDashboard({super.key});

  @override
  State<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<InstructorDashboard> {
  final _authService = AuthService();
  final _courseService = CourseService();
  final _semesterService = SemesterService();
  final _dashboardService = DashboardService();
  final _notificationService = NotificationService();

  List<Course> _courses = [];
  List<Semester> _semesters = [];
  Semester? _selectedSemester;
  bool _isLoading = true;
  String? _errorMessage;
  User? _currentUser;

  // Dashboard metrics from API
  int _totalCourses = 0;
  int _totalStudents = 0;
  int _totalAssignments = 0;
  int _totalQuizzes = 0;
  int _notifications = 0;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load current user
      _currentUser = await _authService.getCurrentUser();

      // Load semesters
      final semesters = await _semesterService.getSemesters();

      // Get active semester or first semester
      Semester? activeSemester;
      try {
        activeSemester = semesters.firstWhere((s) => s.isActive);
      } catch (e) {
        activeSemester = semesters.isNotEmpty ? semesters.first : null;
      }

      // Load data for active semester
      if (activeSemester != null) {
        await _loadSemesterData(activeSemester);
      }

      setState(() {
        _semesters = semesters;
        _selectedSemester = activeSemester;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSemesterData(Semester semester) async {
    try {
      // Load courses for selected semester. Prefer using courses included in the
      // instructor dashboard response (dashboardData['courses']) if present to
      // avoid an extra API call.
      List<Course> courses = [];
      if (_dashboardData != null && _dashboardData!['courses'] is List) {
        try {
          final rawCourses = _dashboardData!['courses'] as List<dynamic>;
          courses = rawCourses
              .map((c) => Course.fromJson(c as Map<String, dynamic>))
              .toList();
          print('✅ Using courses from dashboard payload (${courses.length})');
        } catch (e) {
          print('⚠️ Failed to parse courses from dashboard payload: $e');
          // Fallback to API call below
        }
      }

      if (courses.isEmpty) {
        courses = await _courseService.getCourses(semester: semester.id);
      }

      print(
        '=== DEBUG: Loaded ${courses.length} courses for semester ${semester.displayName}',
      );

      // Load dashboard data from API
      Map<String, dynamic>? dashboardData;
      try {
        dashboardData = await _dashboardService.getInstructorDashboardSummary();
        print('✅ Instructor dashboard data loaded from backend');
      } catch (dashboardError) {
        print('⚠️ Failed to load dashboard data: $dashboardError');
      }

      // Load notification count separately using NotificationService
      int notificationCount = 0;
      try {
        notificationCount = await _notificationService.getUnreadCount();
        print('✅ Notification count loaded: $notificationCount');
      } catch (notificationError) {
        print('⚠️ Failed to load notification count: $notificationError');
      }

      setState(() {
        _courses = courses;
        _selectedSemester = semester;
        _dashboardData =
            dashboardData; // store raw dashboard response for additional sections

        // Update stats from dashboard data if available
        if (dashboardData != null) {
          _totalCourses = dashboardData['totalCourses'] ?? courses.length;
          _totalStudents = dashboardData['totalStudents'] ?? 0;
          _totalAssignments = dashboardData['assignmentStats']?['total'] ?? 0;
          // Some backends use 'total' for quizStats; fallback to other keys if present
          _totalQuizzes =
              dashboardData['quizStats']?['total'] ??
              dashboardData['quizStats']?['totalQuizzes'] ??
              0;
          // If the backend returns a 'needGrading' list, we will render it in a dedicated section below
        } else {
          // Fallback to course-based count
          _totalCourses = courses.length;
          Set<String> uniqueStudentIds = {};
          for (var course in courses) {
            if (course.students.isNotEmpty) {
              uniqueStudentIds.addAll(course.students);
            }
          }
          _totalStudents = uniqueStudentIds.length;
          _totalAssignments = 0;
          _totalQuizzes = 0;
        }

        // Use notification service count instead of dashboard API
        _notifications = notificationCount;
      });
    } catch (e) {
      print('Error loading semester data: $e');
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changeSemester(Semester semester) async {
    setState(() => _isLoading = true);
    await _loadSemesterData(semester);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Semester Selector Card
            if (_semesters.isNotEmpty) _buildSemesterSelector(),
            const SizedBox(height: 16),
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildNeedGradingSection(),
            const SizedBox(height: 24),
            _buildCoursesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Semester:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Semester>(
                  value: _selectedSemester,
                  icon: const Icon(Icons.arrow_drop_down),
                  isExpanded: true,
                  items: _semesters.map((Semester semester) {
                    return DropdownMenuItem<Semester>(
                      value: semester,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(semester.displayName),
                          if (semester.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (Semester? newSemester) {
                    if (newSemester != null) {
                      _changeSemester(newSemester);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${_currentUser?.fullName ?? 'Instructor'}!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your courses and track student progress',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedSemester != null
                  ? '${_selectedSemester!.displayName} Overview'
                  : 'Semester Overview',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_selectedSemester != null && !_selectedSemester!.isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Past Semester',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 900
              ? 5
              : MediaQuery.of(context).size.width > 600
              ? 3
              : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              'Courses',
              '$_totalCourses',
              Icons.school,
              Colors.blue,
            ),
            _buildStatCard(
              'Students',
              '$_totalStudents',
              Icons.people,
              Colors.orange,
            ),
            _buildStatCard(
              'Assignments',
              '$_totalAssignments',
              Icons.assignment,
              Colors.purple,
            ),
            _buildStatCard('Quizzes', '$_totalQuizzes', Icons.quiz, Colors.red),
            _buildStatCard(
              'Notifications',
              '$_notifications',
              Icons.notifications,
              Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(
    String label,
    double value,
    String percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showCreateCourseDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Course'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _courses.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text('No courses yet'),
                      const SizedBox(height: 8),
                      const Text('Create your first course to get started'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateCourseDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Course'),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600
                      ? 2
                      : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 3,
                ),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return _buildCourseCard(course);
                },
              ),
      ],
    );
  }

  Widget _buildNeedGradingSection() {
    if (_dashboardData == null) return const SizedBox.shrink();

    final needGrading = _dashboardData!['needGrading'];
    if (needGrading == null || needGrading is! List || needGrading.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submissions Needing Grading',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: needGrading.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = needGrading[index];
                final studentName = item['studentName'] ?? 'Student';
                final assignmentTitle = item['assignmentTitle'] ?? 'Assignment';
                final courseTitle = item['courseTitle'] ?? '';
                final submittedAt = item['submittedAt'] != null
                    ? DateTime.tryParse(item['submittedAt'].toString())
                    : null;

                return ListTile(
                  title: Text('$assignmentTitle'),
                  subtitle: Text('$studentName • ${courseTitle ?? ''}'),
                  trailing: Text(
                    submittedAt != null ? _formatRelative(submittedAt) : '',
                  ),
                  onTap: () {
                    // Optionally navigate to grading UI - not yet implemented
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Open grading for $assignmentTitle'),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildCourseCard(Course course) {
    // Parse course color if available
    Color color = Colors.blue;
    if (course.color != null && course.color!.isNotEmpty) {
      try {
        final hexColor = course.color!.replaceAll('#', '');
        color = Color(int.parse('FF$hexColor', radix: 16));
      } catch (e) {
        color = Colors.blue;
      }
    }

    return Card(
      child: InkWell(
        onTap: () {
          // Navigate to course detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.description ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text('${course.studentCount} students'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditCourseDialog(context, course);
                      break;
                    case 'students':
                      _showStudentsList(context, course);
                      break;
                    case 'assignments':
                      _showAssignments(context, course);
                      break;
                    case 'materials':
                      _showMaterials(context, course);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Course'),
                  ),
                  const PopupMenuItem(
                    value: 'students',
                    child: Text('View Students'),
                  ),
                  const PopupMenuItem(
                    value: 'assignments',
                    child: Text('Assignments'),
                  ),
                  const PopupMenuItem(
                    value: 'materials',
                    child: Text('Materials'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateCourseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Course'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Course Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement create course
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create course feature coming soon!'),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditCourseDialog(BuildContext context, Course course) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Edit ${course.name} coming soon!')));
  }

  void _showStudentsList(BuildContext context, Course course) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Students list for ${course.name} coming soon!')),
    );
  }

  void _showAssignments(BuildContext context, Course course) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assignments for ${course.name} coming soon!')),
    );
  }

  void _showMaterials(BuildContext context, Course course) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Materials for ${course.name} coming soon!')),
    );
  }
}
