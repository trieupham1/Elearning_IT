import 'package:flutter/material.dart';

class GroupCard extends StatelessWidget {
  final String groupName;
  final int studentCount;

  const GroupCard({
    Key? key,
    required this.groupName,
    required this.studentCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(groupName),
        subtitle: Text('$studentCount students'),
        children: [
          for (int i = 1; i <= 3; i++)
            ListTile(
              leading: CircleAvatar(
                child: Text('S$i'),
              ),
              title: Text('Student $i'),
              subtitle: Text('student$i@fit.edu.vn'),
              dense: true,
            ),
          if (studentCount > 3)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('... and ${studentCount - 3} more students'),
            ),
        ],
      ),
    );
  }
}