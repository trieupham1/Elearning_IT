import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/group_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_manager.dart';

class AvailableCoursesScreen extends StatefulWidget {
  const AvailableCoursesScreen({super.key});

  @override
  State<AvailableCoursesScreen> createState() => _AvailableCoursesScreenState();
}

class _AvailableCoursesScreenState extends State<AvailableCoursesScreen> {
  List<Course> _availableCourses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableCourses();
  }

  Future<void> _loadAvailableCourses() async {
    setState(() => _isLoading = true);

    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.courses}/available'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final courses = data.map((json) => Course.fromJson(json)).toList();

        setState(() {
          _availableCourses = courses;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        throw Exception('Failed to load available courses: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _joinCourse(Course course) async {
    try {
      // Load groups for this course
      final groups = await GroupService.getGroupsByCourse(course.id);

      String? selectedGroupId;

      // If there are groups, show selection dialog
      if (groups.isNotEmpty) {
        if (!mounted) return;
        selectedGroupId = await showDialog<String?>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Group'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select a group to join in this course:'),
                const SizedBox(height: 16),
                ...groups.map(
                  (group) => RadioListTile<String>(
                    title: Text(group.name),
                    subtitle: Text(
                      '${group.members.length} members${group.description != null ? '\n${group.description}' : ''}',
                    ),
                    value: group.id,
                    groupValue: selectedGroupId,
                    onChanged: (value) {
                      Navigator.pop(context, value);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('No specific group'),
                  leading: Radio<String?>(
                    value: null,
                    groupValue: selectedGroupId,
                    onChanged: (value) {
                      Navigator.pop(context, null);
                    },
                  ),
                  onTap: () => Navigator.pop(context, null),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        // If user cancelled
        if (selectedGroupId == 'cancel' || !mounted) return;
      }

      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');

      final headers = await ApiConfig.headers();

      final body = <String, dynamic>{};
      if (selectedGroupId != null) {
        body['groupId'] = selectedGroupId;
      }

      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.courses}/${course.id}/join',
            ),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Join request sent! Waiting for instructor approval.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh the list
        _loadAvailableCourses();

        // Don't pop - let user browse more courses
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to send join request');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Courses'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
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
                    'Error loading courses',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAvailableCourses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _availableCourses.isEmpty
          ? Center(
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
                    'No available courses',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are enrolled in all active courses',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAvailableCourses,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _availableCourses.length,
                itemBuilder: (context, index) {
                  return _buildCourseCard(_availableCourses[index]);
                },
              ),
            ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        course.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
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
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        course.instructorName ?? 'Unknown Instructor',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
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
                if (course.description != null &&
                    course.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      course.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _joinCourse(course),
                    icon: const Icon(Icons.send),
                    label: const Text('Request to Join'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
