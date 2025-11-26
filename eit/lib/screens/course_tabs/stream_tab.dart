// screens/course_tabs/stream_tab.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/announcement.dart';
import '../../models/course.dart';
import '../../models/user.dart';
import '../../services/announcement_service.dart';
import '../instructor/create_announcement_screen.dart';
import '../student/announcement_detail_screen.dart';

class StreamTab extends StatefulWidget {
  final Course course;
  final User? currentUser;

  const StreamTab({super.key, required this.course, this.currentUser});

  @override
  State<StreamTab> createState() => _StreamTabState();
}

class _StreamTabState extends State<StreamTab> {
  final AnnouncementService _announcementService = AnnouncementService();
  List<Announcement> _announcements = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final announcements = await _announcementService.getAnnouncements(
        widget.course.id,
      );
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading announcements: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showNewAnnouncementDialog() async {
    // Navigate to full-featured announcement creation screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAnnouncementScreen(course: widget.course),
      ),
    );

    // Reload announcements if created successfully
    if (result == true || mounted) {
      _loadAnnouncements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInstructor = widget.currentUser?.role == 'instructor';

    return Column(
      children: [
        // New Announcement Button (Instructor only)
        if (isInstructor)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showNewAnnouncementDialog,
              icon: const Icon(Icons.edit),
              label: const Text('New announcement'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

        // Announcements List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.announcement_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No announcements yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnnouncements,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      final announcement = _announcements[index];
                      return _AnnouncementCard(
                        announcement: announcement,
                        currentUser: widget.currentUser,
                        onTap: () {
                          // Navigate to full announcement detail screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnnouncementDetailScreen(
                                announcementId: announcement.id,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ).then((_) => _loadAnnouncements());
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final User? currentUser;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Announcement Header
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage: announcement.authorAvatar != null
                    ? NetworkImage(announcement.authorAvatar!)
                    : null,
                child: announcement.authorAvatar == null
                    ? Text(
                        announcement.authorName.isNotEmpty
                            ? announcement.authorName
                                  .substring(0, 1)
                                  .toUpperCase()
                            : 'A',
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              title: Text(
                announcement.authorName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                timeago.format(announcement.createdAt),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),

            // Announcement Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (announcement.title.isNotEmpty)
                    Text(
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (announcement.title.isNotEmpty) const SizedBox(height: 8),
                  Text(
                    announcement.content,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Metadata footer
            if (announcement.attachments.isNotEmpty ||
                announcement.comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    if (announcement.attachments.isNotEmpty) ...[
                      Icon(
                        Icons.attach_file,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${announcement.attachments.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (announcement.comments.isNotEmpty) ...[
                      Icon(
                        Icons.comment,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${announcement.comments.length} ${announcement.comments.length == 1 ? 'comment' : 'comments'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
