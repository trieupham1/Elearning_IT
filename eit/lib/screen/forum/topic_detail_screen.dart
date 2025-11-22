import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/forum.dart';
import '../../services/forum_service.dart';
import '../../services/auth_service.dart';

class TopicDetailScreen extends StatefulWidget {
  final String topicId;

  const TopicDetailScreen({Key? key, required this.topicId}) : super(key: key);

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final TextEditingController _replyController = TextEditingController();

  ForumTopic? _topic;
  List<ForumReply> _replies = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _userRole;
  ForumReply? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTopicAndReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final currentUser = await _authService.getCurrentUser();
    setState(() {
      _currentUserId = currentUser?.id;
      _userRole = currentUser?.role;
    });
    print(
      '📍 Topic Detail: Current user ID loaded: $_currentUserId, role: $_userRole',
    );
  }

  Future<void> _loadTopicAndReplies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final topic = await _forumService.getTopic(widget.topicId);
      final replies = await _forumService.getReplies(widget.topicId);

      setState(() {
        _topic = topic;
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load topic: $e')));
      }
    }
  }

  Future<void> _toggleTopicLike() async {
    if (_topic == null) return;
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like topics')),
      );
      return;
    }

    try {
      final result = await _forumService.toggleTopicLike(_topic!.id);
      setState(() {
        final isLiked = result['isLiked'] as bool? ?? false;
        if (isLiked) {
          // Add like if not already in the list
          if (!_topic!.likes.contains(_currentUserId)) {
            _topic!.likes.add(_currentUserId!);
          }
        } else {
          // Remove like
          _topic!.likes.remove(_currentUserId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to like topic: $e')));
      }
    }
  }

  Future<void> _toggleReplyLike(ForumReply reply) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like replies')),
      );
      return;
    }

    try {
      final result = await _forumService.toggleReplyLike(reply.id);
      setState(() {
        final isLiked = result['isLiked'] as bool? ?? false;
        if (isLiked) {
          // Add like if not already in the list
          if (!reply.likes.contains(_currentUserId)) {
            reply.likes.add(_currentUserId!);
          }
        } else {
          // Remove like
          reply.likes.remove(_currentUserId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to like reply: $e')));
      }
    }
  }

  Future<void> _togglePin() async {
    if (_topic == null) return;
    try {
      await _forumService.toggleTopicPin(_topic!.id);
      setState(() {
        _topic!.isPinned = !_topic!.isPinned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_topic!.isPinned ? 'Topic pinned' : 'Topic unpinned'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pin topic: $e')));
    }
  }

  Future<void> _toggleLock() async {
    if (_topic == null) return;
    try {
      await _forumService.toggleTopicLock(_topic!.id);
      setState(() {
        _topic!.isLocked = !_topic!.isLocked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_topic!.isLocked ? 'Topic locked' : 'Topic unlocked'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to lock topic: $e')));
    }
  }

  Future<void> _submitReply() async {
    if (_topic == null) return;
    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a reply')));
      return;
    }

    try {
      await _forumService.createReply(
        topicId: _topic!.id,
        content: _replyController.text.trim(),
        parentReplyId: _replyingTo?.id,
        attachments: [],
      );

      _replyController.clear();
      setState(() {
        _replyingTo = null;
      });

      await _loadTopicAndReplies();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply posted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post reply: $e')));
    }
  }

  void _setReplyingTo(ForumReply? reply) {
    setState(() {
      _replyingTo = reply;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topic'),
        backgroundColor: Colors.blue,
        actions: [
          if (_topic != null && _userRole == 'instructor') ...[
            IconButton(
              icon: Icon(
                _topic!.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              onPressed: _togglePin,
            ),
            IconButton(
              icon: Icon(_topic!.isLocked ? Icons.lock : Icons.lock_open),
              onPressed: _toggleLock,
            ),
          ],
        ],
      ),
      body: _isLoading && _topic == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_topic != null) ...[
                        _buildTopicCard(),
                        const Divider(height: 32),
                        Text(
                          'Replies (${_replies.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ..._buildRepliesTree(),
                    ],
                  ),
                ),
                if (_topic != null && !_topic!.isLocked) _buildReplyInput(),
              ],
            ),
    );
  }

  Widget _buildTopicCard() {
    if (_topic == null) return const SizedBox();

    final isLiked =
        _currentUserId != null && _topic!.likes.contains(_currentUserId);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _topic!.authorRole == 'instructor'
                      ? Colors.orange[400]
                      : Colors.blue[400],
                  child: Text(
                    _topic!.authorName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _topic!.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_topic!.authorRole == 'instructor') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange[300]!,
                                    Colors.orange[400]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Instructor',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeago.format(_topic!.createdAt),
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _topic!.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            if (_topic!.content.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _topic!.content,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.grey[800],
                ),
              ),
            ],
            if (_topic!.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _topic!.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue[200]!, width: 1),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 20,
                  color: Colors.blue[600],
                ),
                const SizedBox(width: 6),
                Text(
                  '${_topic!.views}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  decoration: BoxDecoration(
                    color: isLiked ? Colors.red[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    onTap: _toggleTopicLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_topic!.likes.length}',
                            style: TextStyle(
                              color: isLiked ? Colors.red : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRepliesTree() {
    final topLevelReplies = _replies
        .where((r) => r.parentReplyId == null)
        .toList();
    return topLevelReplies.map((reply) => _buildReplyCard(reply, 0)).toList();
  }

  Widget _buildReplyCard(ForumReply reply, int depth) {
    final isLiked =
        _currentUserId != null && reply.likes.contains(_currentUserId);
    final childReplies = _replies
        .where((r) => r.parentReplyId == reply.id)
        .toList();

    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12, top: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: depth > 0 ? Colors.blue[100]! : Colors.grey[200]!,
                width: depth > 0 ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: reply.authorRole == 'instructor'
                            ? Colors.orange[400]
                            : Colors.blue[400],
                        child: Text(
                          reply.authorName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    reply.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (reply.authorRole == 'instructor') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange[300]!,
                                          Colors.orange[400]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Instructor',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeago.format(reply.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reply.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isLiked ? Colors.red[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => _toggleReplyLike(reply),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: isLiked
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${reply.likes.length}',
                                  style: TextStyle(
                                    color: isLiked
                                        ? Colors.red
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        icon: Icon(
                          Icons.reply,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        label: Text(
                          'Reply',
                          style: TextStyle(color: Colors.blue[600]),
                        ),
                        onPressed: () => _setReplyingTo(reply),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ...childReplies.map((child) => _buildReplyCard(child, depth + 1)),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 18, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.authorName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: Colors.blue[600]),
                    onPressed: () => _setReplyingTo(null),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[400]!,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _submitReply,
                  tooltip: 'Send reply',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
