import 'package:flutter/material.dart';

class ClassworkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String info;
  final Color color;

  const ClassworkItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.info,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Text(info, style: const TextStyle(fontSize: 12))],
        ),
        onTap: () {},
      ),
    );
  }
}
