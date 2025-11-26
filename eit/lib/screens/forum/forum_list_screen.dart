import 'package:flutter/material.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';
import '../../services/auth_service.dart';
import 'topic_detail_screen.dart';
import 'create_topic_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class ForumListScreen extends StatefulWidget {
  final String courseId;

  const ForumListScreen({Key? key, required this.courseId}) : super(key: key);

  @override
  State<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends State<ForumListScreen> {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ForumTopic> _topics = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _sortBy = 'recent';
  String _searchQuery = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTopics();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final currentUser = await _authService.getCurrentUser();
    setState(() {
      _currentUserId = currentUser?.id;
    });
    print('📍 Forum: Current user ID loaded: $_currentUserId');
  }

  Future<void> _loadTopics({bool refresh = false}) async {
    if (_isLoading) return;
    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _topics = [];
        _hasMore = true;
      }
    });

    try {
      final result = await _forumService.getTopics(
        courseId: widget.courseId,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (refresh) {
          _topics = result['topics'];
        } else {
          _topics.addAll(result['topics']);
        }
        _hasMore = result['pagination'].page < result['pagination'].totalPages;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load topics: $e')));
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadTopics();
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadTopics(refresh: true);
  }

  void _onSortChange(String? value) {
    if (value != null) {
      setState(() {
        _sortBy = value;
      });
      _loadTopics(refresh: true);
    }
  }

  Future<void> _navigateToCreateTopic() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTopicScreen(courseId: widget.courseId),
      ),
    );

    if (result == true) {
      _loadTopics(refresh: true);
    }
  }

  Future<void> _navigateToTopicDetail(ForumTopic topic) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TopicDetailScreen(topicId: topic.id),
      ),
    );

    if (result == true) {
      _loadTopics(refresh: true);
    }
  }

  Future<void> _toggleLike(ForumTopic topic) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like topics')),
      );
      return;
    }

    try {
      final result = await _forumService.toggleTopicLike(topic.id);
      // Update UI based on server response
      setState(() {
        final index = _topics.indexWhere((t) => t.id == topic.id);
        if (index != -1) {
          final isLiked = result['isLiked'] as bool? ?? false;
          if (isLiked) {
            // Add like if not already in the list
            if (!topic.likes.contains(_currentUserId)) {
              topic.likes.add(_currentUserId!);
            }
          } else {
            // Remove like
            topic.likes.remove(_currentUserId);
          }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadTopics(refresh: true),
        child: Column(
          children: [
            // Search bar with filter button
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search topics...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearch('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      onSubmitted: _onSearch,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!, width: 1),
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.filter_list,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                      tooltip: 'Sort by',
                      onSelected: _onSortChange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'recent',
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 20,
                                color: _sortBy == 'recent'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              const Text('Recent Activity'),
                              if (_sortBy == 'recent') ...[
                                const Spacer(),
                                Icon(Icons.check, color: Colors.blue, size: 20),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'popular',
                          child: Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 20,
                                color: _sortBy == 'popular'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              const Text('Most Popular'),
                              if (_sortBy == 'popular') ...[
                                const Spacer(),
                                Icon(Icons.check, color: Colors.blue, size: 20),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'mostReplies',
                          child: Row(
                            children: [
                              Icon(
                                Icons.comment,
                                size: 20,
                                color: _sortBy == 'mostReplies'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              const Text('Most Replies'),
                              if (_sortBy == 'mostReplies') ...[
                                const Spacer(),
                                Icon(Icons.check, color: Colors.blue, size: 20),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'mostLikes',
                          child: Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 20,
                                color: _sortBy == 'mostLikes'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              const Text('Most Liked'),
                              if (_sortBy == 'mostLikes') ...[
                                const Spacer(),
                                Icon(Icons.check, color: Colors.blue, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Topics list
            Expanded(
              child: _topics.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 24),
                          Text(
                            'No topics yet',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Be the first to start a discussion!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreateTopic,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Create First Topic'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          itemCount: _topics.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 0),
                          itemBuilder: (context, index) {
                            if (index >= _topics.length) {
                              return const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final topic = _topics[index];
                            return _buildTopicCard(topic);
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTopic,
        icon: const Icon(Icons.add_circle_outline, size: 24),
        label: const Text(
          'New Topic',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 4,
      ),
    );
  }

  Widget _buildTopicCard(ForumTopic topic) {
    final isLiked =
        _currentUserId != null && topic.likes.contains(_currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: () => _navigateToTopicDetail(topic),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with author and time
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: topic.authorRole == 'instructor'
                        ? Colors.orange[400]
                        : Colors.blue[400],
                    child: Text(
                      topic.authorName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
                                topic.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (topic.authorRole == 'instructor') ...[
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
                          timeago.format(topic.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (topic.isPinned)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.push_pin,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                    ),
                  if (topic.isLocked)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.lock,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                topic.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              if (topic.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  topic.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              if (topic.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topic.tags.map((tag) {
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
              const SizedBox(height: 16),
              // Stats and actions
              Row(
                children: [
                  _buildStatItem(
                    Icons.visibility_outlined,
                    '${topic.views}',
                    Colors.blue,
                  ),
                  const SizedBox(width: 20),
                  _buildStatItem(
                    Icons.chat_bubble_outline,
                    '${topic.replyCount}',
                    Colors.green,
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: isLiked ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: InkWell(
                      onTap: () => _toggleLike(topic),
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
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${topic.likes.length}',
                              style: TextStyle(
                                color: isLiked ? Colors.red : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, MaterialColor color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color[600]),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
