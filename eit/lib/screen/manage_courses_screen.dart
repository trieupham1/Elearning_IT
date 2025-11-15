import 'package:flutter/material.dart';
import 'dart:math';
import '../services/course_service.dart';
import '../services/semester_service.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../services/student_service.dart';
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
  final _adminService = AdminService();
  final _studentService = StudentService();

  List<Course> _courses = [];
  List<Semester> _semesters = [];
  List<User> _instructors = [];
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

      // Fetch instructors if user is admin
      List<User> instructors = [];
      if (user?.role == 'admin') {
        try {
          instructors = await _adminService.getAllInstructors();
        } catch (e) {
          print('Error loading instructors: $e');
        }
      }

      setState(() {
        _courses = courses;
        _semesters = semesters;
        _instructors = instructors;
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
    User? selectedInstructor;
    int selectedSessions = 15;
    String selectedColor = _getRandomColor();

    // If admin, allow instructor selection; otherwise, use current user
    final bool isAdmin = _currentUser?.role == 'admin';
    if (!isAdmin) {
      selectedInstructor = _currentUser;
    }

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

                  // Instructor Selection (dropdown for admin, read-only for others)
                  if (isAdmin)
                    DropdownButtonFormField<User>(
                      value: selectedInstructor,
                      decoration: const InputDecoration(
                        labelText: 'Assign Instructor (Optional)',
                        border: OutlineInputBorder(),
                        helperText:
                            'Leave blank to assign later via invitation',
                      ),
                      items: [
                        const DropdownMenuItem<User>(
                          value: null,
                          child: Text('-- Assign Later --'),
                        ),
                        ..._instructors.map((instructor) {
                          return DropdownMenuItem<User>(
                            value: instructor,
                            child: Text(instructor.fullName),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedInstructor = value;
                        });
                      },
                    )
                  else
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

  void _showAssignTeacherDialog(Course course) {
    User? selectedInstructor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Teacher to ${course.name}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current instructor: ${course.instructorName ?? "None"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select a new instructor to send them an invitation to teach this course:',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<User>(
                  value: selectedInstructor,
                  decoration: const InputDecoration(
                    labelText: 'Select Instructor*',
                    border: OutlineInputBorder(),
                  ),
                  items: _instructors.map((instructor) {
                    return DropdownMenuItem<User>(
                      value: instructor,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: instructor.profilePicture != null
                                ? NetworkImage(instructor.profilePicture!)
                                : null,
                            child: instructor.profilePicture == null
                                ? Text(instructor.fullName[0])
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(instructor.fullName),
                                Text(
                                  instructor.email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedInstructor = value;
                    });
                  },
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
              onPressed: () async {
                if (selectedInstructor == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select an instructor'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  await _courseService.assignTeacher(
                    courseId: course.id,
                    instructorId: selectedInstructor!.id,
                  );

                  if (!mounted) return;
                  Navigator.pop(context); // Close loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invitation sent to ${selectedInstructor!.fullName}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  await _loadData();
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context); // Close loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error assigning teacher: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignStudentsDialog(Course course) async {
    try {
      // Load students
      final students = await _studentService.getStudents();
      final selectedStudentIds = <String>{};

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Assign Students to ${course.name}'),
            content: SizedBox(
              width: 500,
              height: 600,
              child: Column(
                children: [
                  const Text(
                    'Select students to send course invitations:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: students.isEmpty
                        ? const Center(child: Text('No students available'))
                        : ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final isSelected = selectedStudentIds.contains(
                                student.id,
                              );

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedStudentIds.add(student.id);
                                    } else {
                                      selectedStudentIds.remove(student.id);
                                    }
                                  });
                                },
                                title: Text(student.fullName),
                                subtitle: Text(student.email),
                                secondary: CircleAvatar(
                                  backgroundImage:
                                      student.profilePicture != null
                                      ? NetworkImage(student.profilePicture!)
                                      : null,
                                  child: student.profilePicture == null
                                      ? Text(student.fullName[0])
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${selectedStudentIds.length} student(s) selected',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
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
                onPressed: selectedStudentIds.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(context);

                        // Show loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          await _courseService.assignStudents(
                            courseId: course.id,
                            studentIds: selectedStudentIds.toList(),
                          );

                          if (!mounted) return;
                          Navigator.pop(context); // Close loading

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sent ${selectedStudentIds.length} invitation(s)',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context); // Close loading

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error assigning students: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Send Invitations'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading students: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  child: ExpansionTile(
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
                          'Instructor: ${course.instructorName ?? "Not Assigned"}',
                        ),
                        Text('Students: ${course.studentCount}'),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Course Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Edit Button
                                ElevatedButton.icon(
                                  onPressed: isEditable
                                      ? () => _showEditCourseDialog(course)
                                      : null,
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Edit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),

                                // Assign Teacher Button (Admin only)
                                if (_currentUser?.role == 'admin')
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showAssignTeacherDialog(course),
                                    icon: const Icon(
                                      Icons.person_add,
                                      size: 18,
                                    ),
                                    label: const Text('Assign Teacher'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),

                                // Assign Students Button
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showAssignStudentsDialog(course),
                                  icon: const Icon(Icons.group_add, size: 18),
                                  label: const Text('Assign Students'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),

                                // Delete Button
                                ElevatedButton.icon(
                                  onPressed: isEditable
                                      ? () => _showDeleteCourseDialog(course)
                                      : null,
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Delete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
