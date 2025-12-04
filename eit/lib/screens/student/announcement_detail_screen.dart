import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../models/announcement.dart';
import '../../models/user.dart';
import '../../services/announcement_service.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;
  final User? currentUser;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
    this.currentUser,
  });

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final _announcementService = AnnouncementService();
  final _commentController = TextEditingController();
  Announcement? _announcement;
  bool _isLoading = false;
  bool _isPostingComment = false;
  bool _hasTrackedView = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncement() async {
    setState(() => _isLoading = true);
    try {
      final announcement = await _announcementService.getAnnouncement(
        widget.announcementId,
      );
      setState(() {
        _announcement = announcement;
        _isLoading = false;
      });

      // Track view after successfully loading (only once)
      if (!_hasTrackedView) {
        _trackView();
        _hasTrackedView = true;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load announcement: $e');
    }
  }

  Future<void> _trackView() async {
    try {
      await _announcementService.trackView(widget.announcementId);
      print('View tracked successfully');
    } catch (e) {
      print('Failed to track view: $e');
      // Don't show error to user - this is a background operation
    }
  }

  Future<void> _downloadFile(AnnouncementAttachment attachment) async {
    try {
      _showMessage('Downloading ${attachment.name}...');

      // Build full URL if the attachment URL is relative
      String fileUrl = attachment.url;
      if (fileUrl.startsWith('/')) {
        // Relative URL, prepend base URL without /api
        final baseUrl = ApiConfig.getBaseUrl().replaceAll('/api', '');
        fileUrl = '$baseUrl$fileUrl';
      }

      // Launch URL to download file
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        // Use platformDefault mode which works better on web
        await launchUrl(uri, mode: LaunchMode.platformDefault);

        // Track download
        await _announcementService.trackDownload(
          announcementId: widget.announcementId,
          fileName: attachment.name,
        );

        _showSuccess('Download started');
      } else {
        _showError('Cannot open file: $fileUrl');
      }
    } catch (e) {
      _showError('Failed to download file: $e');
      print('Download error: $e');
      print('File URL: ${attachment.url}');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showError('Please enter a comment');
      return;
    }

    setState(() => _isPostingComment = true);
    try {
      final updatedAnnouncement = await _announcementService.addComment(
        announcementId: widget.announcementId,
        text: _commentController.text.trim(),
      );

      setState(() {
        _announcement = updatedAnnouncement;
        _isPostingComment = false;
      });

      _commentController.clear();
      _showSuccess('Comment added');

      // Hide keyboard
      FocusScope.of(context).unfocus();
    } catch (e) {
      setState(() => _isPostingComment = false);
      _showError('Failed to add comment: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcement == null
          ? const Center(child: Text('Announcement not found'))
          : RefreshIndicator(
              onRefresh: _loadAnnouncement,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildHeader(),

                    const Divider(height: 1),

                    // Content Section
                    _buildContent(),

                    // Attachments Section
                    if (_announcement!.hasAttachments) _buildAttachments(),

                    const Divider(height: 1, thickness: 8),

                    // Comments Section
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildCommentInput(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                backgroundImage: _announcement!.authorAvatar != null
                    ? NetworkImage(_announcement!.authorAvatar!)
                    : null,
                child: _announcement!.authorAvatar == null
                    ? Text(
                        _announcement!.authorName.isNotEmpty
                            ? _announcement!.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: Colors.blue.shade900),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _announcement!.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'MMM d, yyyy h:mm a',
                      ).format(_announcement!.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            _announcement!.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          // Group info
          if (!_announcement!.isForAllGroups)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                avatar: const Icon(Icons.group, size: 16),
                label: Text(_announcement!.groupDisplay),
                backgroundColor: Colors.blue.shade50,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _announcement!.content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 20),
              const SizedBox(width: 8),
              Text(
                'Attachments (${_announcement!.attachments.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._announcement!.attachments.map((attachment) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _getFileIcon(attachment),
                  color: Colors.blue,
                  size: 32,
                ),
                title: Text(attachment.name),
                subtitle: Text(attachment.formattedSize),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadFile(attachment),
                  tooltip: 'Download',
                ),
                onTap: () => _downloadFile(attachment),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.comment, size: 20),
              const SizedBox(width: 8),
              Text(
                'Comments (${_announcement!.commentCount})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_announcement!.comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Be the first to comment!',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._announcement!.comments.map((comment) {
              return _buildCommentTile(comment);
            }),
        ],
      ),
    );
  }

  Widget _buildCommentTile(AnnouncementComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: comment.userAvatar != null
                ? NetworkImage(comment.userAvatar!)
                : null,
            child: comment.userAvatar == null
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comment.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, h:mm a').format(comment.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isPostingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _isPostingComment ? null : _addComment,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(AnnouncementAttachment attachment) {
    if (attachment.isImage) {
      return Icons.image;
    } else if (attachment.isDocument) {
      final ext = attachment.extension;
      if (ext == 'pdf') return Icons.picture_as_pdf;
      if (ext == 'doc' || ext == 'docx') return Icons.description;
      if (ext == 'xls' || ext == 'xlsx') return Icons.table_chart;
      if (ext == 'ppt' || ext == 'pptx') return Icons.slideshow;
    }
    return Icons.insert_drive_file;
  }
}
