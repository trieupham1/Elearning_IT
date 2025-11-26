import 'package:flutter/material.dart';
import 'dart:math';
import '../services/course_service.dart';
import '../services/semester_service.dart';
import '../services/auth_service.dart';
import '../models/course.dart';
import '../models/semester.dart';
import '../models/user.dart';

class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({super.key});

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  final _courseService = CourseService();
  final _semesterService = SemesterService();
  final _authService = AuthService();

  List<Course> _courses = [];
  List<Semester> _semesters = [];
  User? _currentUser;
  bool _isLoading = true;

  // Predefined colors for courses
  final List<String> _courseColors = [
    '#1976D2', // Blue
    '#388E3C', // Green
    '#7B1FA2', // Purple
    '#F57C00', // Orange
    '#C62828', // Red
    '#00796B', // Teal
    '#303F9F', // Indigo
    '#C2185B', // Pink
    '#5D4037', // Brown
    '#455A64', // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final courses = await _courseService.getCourses();
      final semesters = await _semesterService.getSemesters();
      final user = await _authService.getCurrentUser();

      setState(() {
        _courses = courses;
        _semesters = semesters;
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  String _getRandomColor() {
    final random = Random();
    return _courseColors[random.nextInt(_courseColors.length)];
  }

  Future<void> _createCourse({
    required String code,
    required String name,
    required String description,
    required String semesterId,
    required int sessions,
    required String color,
  }) async {
    try {
      await _courseService.createCourse(
        code: code,
        name: name,
        description: description,
        semesterId: semesterId,
        sessions: sessions,
        color: color,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created successfully')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating course: $e')));
      }
    }
  }

  Future<void> _updateCourse({
    required String courseId,
    required String code,
    required String name,
    required String description,
    required String semesterId,
    required int sessions,
    required String color,
  }) async {
    try {
      await _courseService.updateCourse(
        id: courseId,
        code: code,
        name: name,
        description: description,
        semesterId: semesterId,
        sessions: sessions,
        color: color,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course updated successfully')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating course: $e')));
      }
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await _courseService.deleteCourse(courseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course deleted successfully')),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting course: $e')));
      }
    }
  }

  bool _isCourseEditable(Course course) {
    // Course is editable if its semester is active
    final semester = _semesters.firstWhere(
      (s) => s.id == course.semesterId,
      orElse: () => Semester(
        id: '',
        code: '',
        name: '',
        year: 0,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        isActive: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return semester.isActive;
  }

  void _showCreateCourseDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Semester? selectedSemester;
    int selectedSessions = 15;
    String selectedColor = _getRandomColor();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Course'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Course Code*',
                      hintText: 'e.g., AI502083',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Course Name*',
                      hintText: 'e.g., Artificial Intelligence',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Course description...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Instructor (read-only, shows current user)
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Instructor',
                      hintText: _currentUser?.fullName ?? 'Unknown',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    controller: TextEditingController(
                      text: _currentUser?.fullName ?? 'Unknown',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Semester Dropdown
                  DropdownButtonFormField<Semester>(
                    value: selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Semester*',
                      border: OutlineInputBorder(),
                    ),
                    items: _semesters.map((semester) {
                      return DropdownMenuItem(
                        value: semester,
                        child: Row(
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
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSemester = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sessions Selection
                  const Text(
                    'Number of Sessions*',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<int>(
                          title: const Text('10 Sessions'),
                          value: 10,
                          groupValue: selectedSessions,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSessions = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<int>(
                          title: const Text('15 Sessions'),
                          value: 15,
                          groupValue: selectedSessions,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSessions = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  const Text(
                    'Course Color',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _courseColors.map((color) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(color.substring(1), radix: 16) +
                                  0xFF000000,
                            ),
                            shape: BoxShape.circle,
                            border: selectedColor == color
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: selectedColor == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            selectedColor = _getRandomColor();
                          });
                        },
                        icon: const Icon(Icons.shuffle, size: 16),
                        label: const Text('Random Color'),
                      ),
                    ],
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
              onPressed: () async {
                if (codeController.text.isEmpty ||
                    nameController.text.isEmpty ||
                    selectedSemester == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _createCourse(
                  code: codeController.text,
                  name: nameController.text,
                  description: descriptionController.text,
                  semesterId: selectedSemester!.id,
                  sessions: selectedSessions,
                  color: selectedColor,
                );
              },
              child: const Text('Create Course'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCourseDialog(Course course) {
    // Check if course is editable
    if (!_isCourseEditable(course)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit courses from inactive semesters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final codeController = TextEditingController(text: course.code);
    final nameController = TextEditingController(text: course.name);
    final descriptionController = TextEditingController(
      text: course.description ?? '',
    );

    Semester? selectedSemester = _semesters.firstWhere(
      (s) => s.id == course.semesterId,
      orElse: () => _semesters.first,
    );
    int selectedSessions = course.sessions ?? 15;
    String selectedColor = course.color ?? _getRandomColor();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Course'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Course Code*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Course Name*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Instructor (read-only)
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Instructor',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    controller: TextEditingController(
                      text:
                          course.instructorName ??
                          _currentUser?.fullName ??
                          'Unknown',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Semester Dropdown
                  DropdownButtonFormField<Semester>(
                    value: selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Semester*',
                      border: OutlineInputBorder(),
                    ),
                    items: _semesters.map((semester) {
                      return DropdownMenuItem(
                        value: semester,
                        child: Row(
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
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSemester = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sessions Selection
                  const Text(
                    'Number of Sessions*',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<int>(
                          title: const Text('10 Sessions'),
                          value: 10,
                          groupValue: selectedSessions,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSessions = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<int>(
                          title: const Text('15 Sessions'),
                          value: 15,
                          groupValue: selectedSessions,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSessions = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  const Text(
                    'Course Color',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _courseColors.map((color) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(color.substring(1), radix: 16) +
                                  0xFF000000,
                            ),
                            shape: BoxShape.circle,
                            border: selectedColor == color
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: selectedColor == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
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
              onPressed: () async {
                if (codeController.text.isEmpty ||
                    nameController.text.isEmpty ||
                    selectedSemester == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _updateCourse(
                  courseId: course.id,
                  code: codeController.text,
                  name: nameController.text,
                  description: descriptionController.text,
                  semesterId: selectedSemester!.id,
                  sessions: selectedSessions,
                  color: selectedColor,
                );
              },
              child: const Text('Update Course'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCourseDialog(Course course) {
    // Check if course is editable
    if (!_isCourseEditable(course)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete courses from inactive semesters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
          'Are you sure you want to delete "${course.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCourse(course.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No courses yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click the + button to create your first course',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                final isEditable = _isCourseEditable(course);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(
                                (course.color ?? '#1976D2').substring(1),
                                radix: 16,
                              ) +
                              0xFF000000,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school, color: Colors.white),
                    ),
                    title: Text(
                      course.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code: ${course.code}'),
                        Text('Semester: ${course.semesterName ?? "N/A"}'),
                        Text('Sessions: ${course.sessions ?? 15}'),
                        Text(
                          'Instructor: ${course.instructorName ?? "Unknown"}',
                        ),
                        if (!isEditable)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'READ ONLY (Inactive Semester)',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: isEditable ? Colors.blue : Colors.grey,
                          ),
                          onPressed: isEditable
                              ? () => _showEditCourseDialog(course)
                              : null,
                          tooltip: isEditable
                              ? 'Edit'
                              : 'Cannot edit (inactive semester)',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: isEditable ? Colors.red : Colors.grey,
                          ),
                          onPressed: isEditable
                              ? () => _showDeleteCourseDialog(course)
                              : null,
                          tooltip: isEditable
                              ? 'Delete'
                              : 'Cannot delete (inactive semester)',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCourseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Course'),
      ),
    );
  }
}
