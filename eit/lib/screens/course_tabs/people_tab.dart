// screens/course_tabs/people_tab.dart
import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../models/user.dart';
import '../../models/group.dart';
import '../../services/people_service.dart';
import '../../services/group_service.dart';
import '../chat_screen.dart';

class PeopleTab extends StatefulWidget {
  final Course course;
  final User? currentUser;

  const PeopleTab({super.key, required this.course, this.currentUser});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  final PeopleService _peopleService = PeopleService();
  List<User> _instructors = [];
  List<User> _students = [];
  List<Group> _groups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPeople();
    _loadGroups();
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    try {
      final people = await _peopleService.getCoursePeople(widget.course.id);
      setState(() {
        _instructors = people['instructors'] ?? [];
        _students = people['students'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading people: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await GroupService.getGroupsByCourse(widget.course.id);
      setState(() {
        _groups = groups;
      });
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  void _openChat(User user) {
    // Check permissions
    final isStudent = widget.currentUser?.role == 'student';

    if (isStudent && user.role == 'student') {
      // Students cannot message other students
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Students can only message instructors')),
      );
      return;
    }

    // Open chat screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(recipient: user, currentUser: widget.currentUser!),
      ),
    );
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Group 1',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter group description',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await GroupService.createGroup(
          name: nameController.text,
          courseId: widget.course.id,
          createdBy: widget.currentUser!.id,
          description: descController.text.isNotEmpty
              ? descController.text
              : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully')),
        );
        _loadGroups();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
      }
    }
  }

  List<User> _getUngroupedStudents() {
    final groupedStudentIds = <String>{};
    for (final group in _groups) {
      for (final member in group.members) {
        groupedStudentIds.add(member.id);
      }
    }
    return _students.where((s) => !groupedStudentIds.contains(s.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadPeople();
        await _loadGroups();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Teachers Section
          _SectionHeader(
            title: 'Teachers',
            icon: Icons.person,
            count: _instructors.length,
          ),
          const SizedBox(height: 8),
          if (_instructors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No instructors',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._instructors.map(
              (instructor) => _PersonCard(
                user: instructor,
                onTap: () => _openChat(instructor),
              ),
            ),

          const SizedBox(height: 24),

          // Groups Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(
                title: 'Groups',
                icon: Icons.group,
                count: _groups.length,
              ),
              if (widget.currentUser?.role == 'instructor')
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).primaryColor,
                  onPressed: _createGroup,
                  tooltip: 'Create Group',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No groups created yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._groups.map(
              (group) => _GroupCard(
                group: group,
                allStudents: _students,
                currentUser: widget.currentUser,
                onRefresh: () {
                  _loadGroups();
                  _loadPeople();
                },
                onChatStudent: _openChat,
              ),
            ),

          const SizedBox(height: 24),

          // Classmates Section (ungrouped students)
          _SectionHeader(
            title: 'Ungrouped Students',
            icon: Icons.people,
            count: _getUngroupedStudents().length,
          ),
          const SizedBox(height: 8),
          if (_getUngroupedStudents().isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'All students are in groups',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._getUngroupedStudents().map(
              (student) => _PersonCard(
                user: student,
                onTap: () => _openChat(student),
                showMessageIcon: widget.currentUser?.role == 'instructor',
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final User user;
  final VoidCallback onTap;
  final bool showMessageIcon;

  const _PersonCard({
    required this.user,
    required this.onTap,
    this.showMessageIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: showMessageIcon ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(user.username),
          backgroundImage: user.profilePicture != null
              ? NetworkImage(user.profilePicture!)
              : null,
          child: user.profilePicture == null
              ? Text(
                  user.username.isNotEmpty
                      ? user.username.substring(0, 1).toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(user.email),
        trailing: showMessageIcon
            ? IconButton(
                icon: const Icon(Icons.message),
                color: Theme.of(context).primaryColor,
                onPressed: onTap,
                tooltip: 'Send message',
              )
            : null,
      ),
    );
  }

  Color _getAvatarColor(String text) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.orange,
      Colors.deepOrange,
    ];

    final index = text.codeUnitAt(0) % colors.length;
    return colors[index];
  }
}

class _GroupCard extends StatefulWidget {
  final Group group;
  final List<User> allStudents;
  final User? currentUser;
  final VoidCallback onRefresh;
  final Function(User) onChatStudent;

  const _GroupCard({
    required this.group,
    required this.allStudents,
    required this.currentUser,
    required this.onRefresh,
    required this.onChatStudent,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _isExpanded = false;

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete ${widget.group.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await GroupService.deleteGroup(widget.group.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group deleted')));
        widget.onRefresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInstructor = widget.currentUser?.role == 'instructor';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                widget.group.name.isNotEmpty
                    ? widget.group.name.substring(0, 1).toUpperCase()
                    : 'G',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              widget.group.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: widget.group.description != null
                ? Text(widget.group.description!)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.group.members.length} members',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (isInstructor) ...[
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteGroup,
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.group.members.length,
              itemBuilder: (context, index) {
                final member = widget.group.members[index];
                // Find full user details
                final user = widget.allStudents.firstWhere(
                  (u) => u.id == member.id,
                  orElse: () => User(
                    id: member.id,
                    username: member.studentId,
                    email: member.email,
                    role: 'student',
                    firstName: member.fullName.split(' ').first,
                    lastName: member.fullName.split(' ').skip(1).join(' '),
                  ),
                );

                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person, size: 20),
                  title: Text(member.fullName),
                  subtitle: Text(member.email),
                  trailing: isInstructor
                      ? IconButton(
                          icon: const Icon(Icons.message, size: 20),
                          onPressed: () => widget.onChatStudent(user),
                        )
                      : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
