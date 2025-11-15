import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/group.dart';
import '../models/import_models.dart';
import '../services/student_service.dart';
import '../services/course_service.dart';
import '../services/notification_service.dart';
import '../services/group_service.dart';
import '../widgets/csv_import_dialog.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final _studentService = StudentService();
  List<User> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _studentService.getStudents();
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading students: $e')));
      }
    }
  }

  void _showCreateStudentDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final studentIdController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Student Account'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: studentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password (optional)',
                    hintText: 'Default: student123',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
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
              // Validation
              if (usernameController.text.trim().isEmpty ||
                  emailController.text.trim().isEmpty ||
                  firstNameController.text.trim().isEmpty ||
                  lastNameController.text.trim().isEmpty ||
                  studentIdController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                  ),
                );
                return;
              }

              // Save the scaffold messenger before popping
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              try {
                await _studentService.createStudent(
                  username: usernameController.text.trim(),
                  email: emailController.text.trim(),
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  studentId: studentIdController.text.trim(),
                  password: passwordController.text.trim().isEmpty
                      ? null
                      : passwordController.text.trim(),
                  phoneNumber: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                );

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Student created successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadStudents(); // Reload list
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(User student) {
    final emailController = TextEditingController(text: student.email);
    final phoneController = TextEditingController(
      text: student.phoneNumber ?? '',
    );
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'New Password (optional)',
                  hintText: 'Leave empty to keep current',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
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
              // Save the scaffold messenger before popping
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              try {
                await _studentService.updateStudent(
                  id: student.id,
                  email: emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                  phoneNumber: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  password: passwordController.text.trim().isEmpty
                      ? null
                      : passwordController.text.trim(),
                );

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Student updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadStudents(); // Reload list
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteStudent(User student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student.fullName}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Save the scaffold messenger before popping
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              try {
                await _studentService.deleteStudent(student.id);

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Student deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadStudents(); // Reload list
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _sendCourseInvitation(User student) async {
    // Load instructor's courses
    final courseService = CourseService();
    final notificationService = NotificationService();

    try {
      final courses = await courseService.getCourses();

      if (courses.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have no courses to invite students to'),
          ),
        );
        return;
      }

      // Show dialog with course and group selection
      final selectedCourseIds = <String>{};
      final courseGroupMap = <String, String?>{}; // courseId -> groupId

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _CourseInvitationDialog(
          student: student,
          courses: courses,
          selectedCourseIds: selectedCourseIds,
          courseGroupMap: courseGroupMap,
        ),
      );

      if (confirmed != true || selectedCourseIds.isEmpty) return;

      // Send invitations for each selected course
      for (final courseId in selectedCourseIds) {
        await notificationService.sendCourseInvitation(
          courseId: courseId,
          studentIds: [student.id],
          groupId: courseGroupMap[courseId],
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent ${selectedCourseIds.length} course invitation(s) to ${student.fullName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invitations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImportCsvDialog() {
    showDialog(
      context: context,
      builder: (context) => CsvImportDialog<StudentCsvData>(
        title: 'Import Students from CSV',
        entityName: 'Student',
        csvHeaders: const [
          'Username',
          'Email',
          'FirstName',
          'LastName',
          'StudentId',
          'Password',
          'Department',
          'PhoneNumber',
          'Year',
        ],
        csvTemplate:
            '''Username,Email,FirstName,LastName,StudentId,Password,Department,PhoneNumber,Year
john_doe,john.doe@fit.edu.vn,John,Doe,STU001,student123,Information Technology,0123456789,1
jane_smith,jane.smith@fit.edu.vn,Jane,Smith,STU002,student123,Information Technology,0987654321,2
bob_wilson,bob.wilson@fit.edu.vn,Bob,Wilson,STU003,student123,Information Technology,0111222333,1''',
        parseRow: (row) => StudentCsvData.fromCsvRow(row),
        validateData: (students) async {
          return await _studentService.previewImport(students);
        },
        importData: (items) async {
          return await _studentService.confirmImport(items);
        },
      ),
    ).then((result) {
      if (result == true) {
        _loadStudents(); // Reload list after successful import
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Management')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStudents,
              child: _students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No students yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Create your first student account'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              backgroundImage: student.profilePicture != null
                                  ? NetworkImage(student.profilePicture!)
                                  : null,
                              child: student.profilePicture == null
                                  ? Text(
                                      student.username
                                          .substring(0, 2)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              student.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${student.email}\nStudent ID: ${student.studentId ?? 'N/A'}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _showEditStudentDialog(student);
                                    break;
                                  case 'invite':
                                    _sendCourseInvitation(student);
                                    break;
                                  case 'delete':
                                    _deleteStudent(student);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'invite',
                                  child: Row(
                                    children: [
                                      Icon(Icons.send, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Send Course Invitation'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'import_csv',
            onPressed: _showImportCsvDialog,
            child: const Icon(Icons.upload_file),
            tooltip: 'Import from CSV',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_student',
            onPressed: _showCreateStudentDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Student'),
          ),
        ],
      ),
    );
  }
}

// Course Invitation Dialog with Group Selection
class _CourseInvitationDialog extends StatefulWidget {
  final User student;
  final List<Course> courses;
  final Set<String> selectedCourseIds;
  final Map<String, String?> courseGroupMap;

  const _CourseInvitationDialog({
    required this.student,
    required this.courses,
    required this.selectedCourseIds,
    required this.courseGroupMap,
  });

  @override
  State<_CourseInvitationDialog> createState() =>
      _CourseInvitationDialogState();
}

class _CourseInvitationDialogState extends State<_CourseInvitationDialog> {
  final Map<String, List<Group>> _courseGroups = {};
  final Map<String, bool> _loadingGroups = {};

  @override
  void initState() {
    super.initState();
    for (final course in widget.courses) {
      _loadGroupsForCourse(course.id);
    }
  }

  Future<void> _loadGroupsForCourse(String courseId) async {
    setState(() {
      _loadingGroups[courseId] = true;
    });

    try {
      final groups = await GroupService.getGroupsByCourse(courseId);
      setState(() {
        _courseGroups[courseId] = groups;
        _loadingGroups[courseId] = false;
      });
    } catch (e) {
      print('Error loading groups for course $courseId: $e');
      setState(() {
        _courseGroups[courseId] = [];
        _loadingGroups[courseId] = false;
      });
    }
  }

  Color _parseCourseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.blue;
    }
    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Course Invitation'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send course invitation to ${widget.student.fullName}'),
            const SizedBox(height: 16),
            const Text(
              'Select courses and groups to invite the student to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Course selection list with group dropdowns
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  children: widget.courses.map((course) {
                    final isSelected = widget.selectedCourseIds.contains(
                      course.id,
                    );
                    final groups = _courseGroups[course.id] ?? [];
                    final isLoadingGroups = _loadingGroups[course.id] ?? false;
                    final selectedGroupId = widget.courseGroupMap[course.id];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  widget.selectedCourseIds.add(course.id);
                                } else {
                                  widget.selectedCourseIds.remove(course.id);
                                  widget.courseGroupMap.remove(course.id);
                                }
                              });
                            },
                            title: Text(course.name),
                            subtitle: Text(course.code),
                            secondary: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _parseCourseColor(course.color),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.school,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: isLoadingGroups
                                  ? const CircularProgressIndicator()
                                  : groups.isEmpty
                                  ? const Text(
                                      'No groups in this course',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    )
                                  : DropdownButtonFormField<String?>(
                                      value: selectedGroupId,
                                      decoration: const InputDecoration(
                                        labelText: 'Select Group (Optional)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('No specific group'),
                                        ),
                                        ...groups.map(
                                          (group) => DropdownMenuItem(
                                            value: group.id,
                                            child: Text(
                                              '${group.name} (${group.members.length} members)',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (groupId) {
                                        setState(() {
                                          widget.courseGroupMap[course.id] =
                                              groupId;
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (widget.selectedCourseIds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Please select at least one course',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.selectedCourseIds.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: const Text('Send Invitation'),
        ),
      ],
    );
  }
}
