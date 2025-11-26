import 'package:flutter/material.dart';

class NotificationItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final bool isRead;

  const NotificationItem({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    this.isRead = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isRead ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey.shade300 : Theme.of(context).primaryColor,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Text(time, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}