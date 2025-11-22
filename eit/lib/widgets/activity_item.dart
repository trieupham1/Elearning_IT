import 'package:flutter/material.dart';

class ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;

  const ActivityItem({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.time,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }
}