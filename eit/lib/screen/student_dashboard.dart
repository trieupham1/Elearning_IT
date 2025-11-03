import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../services/semester_service.dart';
import '../services/dashboard_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/semester.dart';
import '../models/dashboard_summary.dart';
import '../screens/course_detail_screen.dart';
import '../screens/available_courses_screen.dart';
import '../widgets/dashboard/deadline_timeline.dart';
import '../widgets/dashboard/progress_chart.dart';
import '../widgets/dashboard/recent_activity_list.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _authService = AuthService();
  final _courseService = CourseService();
  final _semesterService = SemesterService();
  final _dashboardService = DashboardService();
  final _notificationService = NotificationService();

  User? _currentUser;
  List<Course> _courses = [];
  List<Semester> _semesters = [];
  Semester? _selectedSemester;
  bool _isLoading = true;
  String? _errorMessage;

  // Stats
  int _totalCourses = 0;
  int _completedAssignments = 12;
  int _pendingTasks = 4;
  int _notifications = 2;

  // Dashboard data
  DashboardSummary? _dashboardData;

  // Auto-refresh timer
  Timer? _refreshTimer;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Start auto-refresh timer (refresh every 2 minutes)
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      print('🔄 Auto-refreshing dashboard...');
      _refreshDashboardData();
    });
  }

  /// Refresh only dashboard data without reloading courses
  Future<void> _refreshDashboardData() async {
    try {
      final dashboardData = await _dashboardService.getDashboardSummary();

      // Also refresh notification count
      int notificationCount = 0;
      try {
        notificationCount = await _notificationService.getUnreadCount();
      } catch (e) {
        print('⚠️ Failed to refresh notification count: $e');
      }

      if (mounted) {
        setState(() {
          _dashboardData = dashboardData;
          _lastRefresh = DateTime.now();

          // Update stats from dashboard data
          if (dashboardData != null) {
            _completedAssignments =
                dashboardData.assignmentStats.submitted +
                dashboardData.quizStats.completed;
            _pendingTasks =
                dashboardData.assignmentStats.pending +
                dashboardData.quizStats.pending;
          }

          // Update notification count from notification service
          _notifications = notificationCount;
        });

        print('✅ Dashboard auto-refreshed at ${_lastRefresh}');
      }
    } catch (e) {
      print('⚠️ Auto-refresh failed: $e');
      // Don't show error to user for background refresh
    }
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

      // Load courses for active semester
      List<Course> courses = [];
      if (activeSemester != null) {
        courses = await _courseService.getCourses(semester: activeSemester.id);
      }

      // Load dashboard data from backend
      DashboardSummary? dashboardData;
      try {
        dashboardData = await _dashboardService.getDashboardSummary();
        print('✅ Dashboard data loaded from backend');
      } catch (dashboardError) {
        print(
          '⚠️ Failed to load dashboard data, using mock data: $dashboardError',
        );
        // Fallback to mock data if backend fails
        dashboardData = DashboardSummary.mock();
      }

      // Load notification count separately
      int notificationCount = 0;
      try {
        notificationCount = await _notificationService.getUnreadCount();
        print('✅ Notification count loaded: $notificationCount');
      } catch (notificationError) {
        print('⚠️ Failed to load notification count: $notificationError');
      }

      setState(() {
        _semesters = semesters;
        _selectedSemester = activeSemester;
        _courses = courses;
        _totalCourses = courses.length;
        _dashboardData = dashboardData;
        _lastRefresh = DateTime.now();

        // Update stats from dashboard data
        if (dashboardData != null) {
          _completedAssignments =
              dashboardData.assignmentStats.submitted +
              dashboardData.quizStats.completed;
          _pendingTasks =
              dashboardData.assignmentStats.pending +
              dashboardData.quizStats.pending;
        }

        // Use notification service count instead of dashboard API
        _notifications = notificationCount;

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

  Future<void> _loadCoursesForSemester(Semester semester) async {
    setState(() => _isLoading = true);

    try {
      final courses = await _courseService.getCourses(semester: semester.id);

      setState(() {
        _selectedSemester = semester;
        _courses = courses;
        _totalCourses = courses.length;
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
              'Error loading data',
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          print('🔄 Pull-to-refresh triggered');
          await _loadData();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: 8),

              // Last refresh indicator
              if (_lastRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Last updated: ${_formatLastRefresh()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              const SizedBox(height: 16),

              // Stats Cards
              _buildStatsCards(),
              const SizedBox(height: 32),

              // Courses Section with Semester Filter
              _buildCoursesHeader(),
              const SizedBox(height: 16),

              // Courses Grid
              _buildCoursesGrid(),
              const SizedBox(height: 32),

              // Upcoming Deadlines Section
              if (_dashboardData != null) ...[
                _buildSectionHeader('Upcoming Deadlines', Icons.access_time),
                const SizedBox(height: 16),
                _buildDeadlinesSection(),
                const SizedBox(height: 32),
              ],

              // Quiz Performance Section
              if (_dashboardData != null &&
                  _dashboardData!.quizStats.recentScores.isNotEmpty) ...[
                _buildSectionHeader('Quiz Performance', Icons.bar_chart),
                const SizedBox(height: 16),
                _buildQuizPerformanceSection(),
                const SizedBox(height: 32),
              ],

              // Recent Activity Section
              if (_dashboardData != null) ...[
                _buildSectionHeader('Recent Activity', Icons.history),
                const SizedBox(height: 16),
                _buildRecentActivitySection(),
                const SizedBox(height: 80), // Extra space for FAB
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AvailableCoursesScreen()),
          );
          // Reload courses if a course was joined
          if (result == true) {
            _loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Join Course'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(context).primaryColor,
          backgroundImage: _currentUser?.profilePicture != null
              ? NetworkImage(_currentUser!.profilePicture!)
              : null,
          child: _currentUser?.profilePicture == null
              ? Text(
                  _currentUser?.username.substring(0, 2).toUpperCase() ?? 'U',
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                _currentUser?.fullName ?? 'Student',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1200) crossAxisCount = 2;
        if (constraints.maxWidth < 600) crossAxisCount = 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              icon: Icons.school,
              label: 'Courses',
              value: _totalCourses.toString(),
              color: Colors.blue,
              iconColor: Colors.blue,
            ),
            _buildStatCard(
              icon: Icons.check_circle,
              label: 'Completed',
              value: _completedAssignments.toString(),
              color: Colors.green,
              iconColor: Colors.green,
            ),
            _buildStatCard(
              icon: Icons.pending_actions,
              label: 'Pending',
              value: _pendingTasks.toString(),
              color: Colors.orange,
              iconColor: Colors.orange,
            ),
            _buildStatCard(
              icon: Icons.notifications,
              label: 'Notifications',
              value: _notifications.toString(),
              color: Colors.purple,
              iconColor: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color iconColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'My Courses',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (_semesters.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Semester>(
                value: _selectedSemester,
                icon: const Icon(Icons.arrow_drop_down),
                items: _semesters.map((Semester semester) {
                  return DropdownMenuItem<Semester>(
                    value: semester,
                    child: Text(
                      semester.displayName,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (Semester? newSemester) {
                  if (newSemester != null) {
                    _loadCoursesForSemester(newSemester);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoursesGrid() {
    if (_courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No courses enrolled',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact your instructor to join courses',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1400) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 1000) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: _courses.length,
          itemBuilder: (context, index) {
            return _buildCourseCard(_courses[index]);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(Course course) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    final color = colors[course.id.hashCode % colors.length];

    // Check if semester is read-only (past semester)
    final isReadOnly =
        _selectedSemester != null && !_selectedSemester!.isActive;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CourseDetailScreen(course: course, isReadOnly: isReadOnly),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient color
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Course Code
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          course.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Read-only badge for past semesters
                      if (isReadOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'READ ONLY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Course Title
                  Text(
                    course.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instructor Name
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                course.instructorName ?? 'Unknown Instructor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Student Count
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${course.studentCount} students enrolled',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastRefresh() {
    if (_lastRefresh == null) return 'Just now';

    final diff = DateTime.now().difference(_lastRefresh!);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDeadlinesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DeadlineTimeline(
          deadlines: _dashboardData!.upcomingDeadlines.take(5).toList(),
        ),
      ),
    );
  }

  Widget _buildQuizPerformanceSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ProgressChart(quizScores: _dashboardData!.quizStats.recentScores),
    );
  }

  Widget _buildRecentActivitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RecentActivityList(activities: _dashboardData!.recentActivities),
    );
  }
}
