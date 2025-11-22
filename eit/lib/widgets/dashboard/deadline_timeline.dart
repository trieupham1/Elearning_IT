import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_summary.dart';

class DeadlineTimeline extends StatelessWidget {
  final List<UpcomingDeadline> deadlines;

  const DeadlineTimeline({super.key, required this.deadlines});

  @override
  Widget build(BuildContext context) {
    if (deadlines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
              const SizedBox(height: 16),
              Text(
                'All caught up!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No upcoming deadlines',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: deadlines.length,
      itemBuilder: (context, index) {
        final deadline = deadlines[index];
        final isLast = index == deadlines.length - 1;

        return _DeadlineTimelineItem(
          deadline: deadline,
          isLast: isLast,
        );
      },
    );
  }
}

class _DeadlineTimelineItem extends StatelessWidget {
  final UpcomingDeadline deadline;
  final bool isLast;

  const _DeadlineTimelineItem({
    required this.deadline,
    required this.isLast,
  });

  Color _getUrgencyColor() {
    if (deadline.isOverdue) return Colors.red;
    if (deadline.isUrgent) return Colors.orange;
    if (deadline.daysUntilDue <= 3) return Colors.amber;
    return Colors.green;
  }

  IconData _getTypeIcon() {
    return deadline.type == 'quiz' ? Icons.quiz : Icons.assignment;
  }

  String _getTimeUntilText() {
    if (deadline.isOverdue) {
      return 'Overdue';
    } else if (deadline.hoursUntilDue < 24) {
      return '${deadline.hoursUntilDue}h left';
    } else {
      return '${deadline.daysUntilDue}d left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: urgencyColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getTypeIcon(), color: urgencyColor, size: 24),
                  ),
                  title: Text(
                    deadline.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        deadline.courseTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(deadline.deadline),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTimeUntilText(),
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

