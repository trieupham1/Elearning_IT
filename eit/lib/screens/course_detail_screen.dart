import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'course_tabs/stream_tab.dart';
import 'course_tabs/classwork_tab.dart';
import 'course_tabs/people_tab.dart';
import 'forum/forum_list_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final bool isReadOnly;

  const CourseDetailScreen({
    super.key,
    required this.course,
    this.isReadOnly = false,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courseColor = _parseColor(widget.course.color);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: courseColor,
        title: Text(widget.course.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.stream), text: 'Stream'),
            Tab(icon: Icon(Icons.assignment), text: 'Classwork'),
            Tab(icon: Icon(Icons.forum), text: 'Forum'),
            Tab(icon: Icon(Icons.people), text: 'People'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StreamTab(course: widget.course, currentUser: _currentUser),
          ClassworkTab(course: widget.course, currentUser: _currentUser),
          ForumListScreen(courseId: widget.course.id),
          PeopleTab(course: widget.course, currentUser: _currentUser),
        ],
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.blue;
    }

    try {
      // Remove # if present
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }
}
