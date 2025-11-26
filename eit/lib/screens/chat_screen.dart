// screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../services/file_service.dart';
import '../config/api_config.dart';

class ChatScreen extends StatefulWidget {
  final User recipient;
  final User currentUser;

  const ChatScreen({
    super.key,
    required this.recipient,
    required this.currentUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = MessageService();
  final FileService _fileService = FileService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  List<ChatMessage> _filteredMessages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _messageService.getConversation(
        widget.recipient.id,
      );
      setState(() {
        _messages = messages;
        _filteredMessages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final message = await _messageService.sendMessage(
        receiverId: widget.recipient.id,
        content: content,
      );

      if (message != null) {
        // Clear input
        _messageController.clear();

        // Reload messages to get the latest conversation
        await _loadMessages();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message sent')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _filterMessages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMessages = _messages;
      } else {
        _filteredMessages = _messages
            .where(
              (msg) => msg.content.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        setState(() => _isSending = true);

        final file = result.files.first;

        // Upload file
        final uploadedFile = await _fileService.uploadFile(file);

        // Extract file ID from fileUrl
        final fileUrl = uploadedFile['fileUrl'] as String;
        final fileId = fileUrl.split('/').last;

        // Send message with file attachment
        final message = await _messageService.sendMessage(
          receiverId: widget.recipient.id,
          content: '📎 ${file.name}',
          fileId: fileId,
        );

        if (message != null) {
          await _loadMessages();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File sent successfully')),
            );
          }
        }
      }
    } catch (e) {
      print('Error sending file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showInfoPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              backgroundImage: widget.recipient.profilePicture != null
                  ? NetworkImage(widget.recipient.profilePicture!)
                  : null,
              child: widget.recipient.profilePicture == null
                  ? Text(
                      widget.recipient.username.isNotEmpty
                          ? widget.recipient.username
                                .substring(0, 1)
                                .toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              widget.recipient.fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.recipient.role == 'instructor' ? 'Instructor' : 'Student',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoButton(Icons.search, 'Search', () {
                  Navigator.pop(context);
                  setState(() => _showSearch = true);
                }),
                _buildInfoButton(Icons.folder_outlined, 'Files', () {
                  Navigator.pop(context);
                  _showFilesDialog();
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilesDialog() {
    // Get all messages with files, sort by date (newest first), and take 10
    final filesWithAttachments =
        _messages
            .where((msg) => msg.fileId != null && msg.fileId!.isNotEmpty)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final recentFiles = filesWithAttachments.take(10).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shared Files (Last 10)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: recentFiles.isEmpty
              ? const Center(child: Text('No shared files'))
              : ListView.builder(
                  itemCount: recentFiles.length,
                  itemBuilder: (context, index) {
                    final message = recentFiles[index];
                    final fileName = message.content.replaceAll('📎 ', '');

                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(fileName),
                      subtitle: Text(timeago.format(message.createdAt)),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          try {
                            final url =
                                '${ApiConfig.getBaseUrl()}/files/${message.fileId}';
                            print('Attempting to download from: $url');
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              print('Cannot launch URL: $url');
                            }
                          } catch (e) {
                            print('Error downloading file: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to download: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  backgroundImage: widget.recipient.profilePicture != null
                      ? NetworkImage(widget.recipient.profilePicture!)
                      : null,
                  child: widget.recipient.profilePicture == null
                      ? Text(
                          widget.recipient.username.isNotEmpty
                              ? widget.recipient.username
                                    .substring(0, 1)
                                    .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.recipient.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Active now',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (if visible)
          if (_showSearch)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search in conversation...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade700),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade700),
                    onPressed: () {
                      setState(() {
                        _showSearch = false;
                        _searchController.clear();
                        _filteredMessages = _messages;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onChanged: _filterMessages,
              ),
            ),

          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  )
                : _filteredMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showSearch ? 'No messages found' : 'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!_showSearch) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation!',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMessages.length,
                    itemBuilder: (context, index) {
                      final message = _filteredMessages[index];
                      final isMe = message.senderId == widget.currentUser.id;

                      // Debug logging
                      print('Message: ${message.content}');
                      print('SenderId: ${message.senderId}');
                      print('CurrentUserId: ${widget.currentUser.id}');
                      print('IsMe: $isMe');

                      final showAvatar =
                          index == _filteredMessages.length - 1 ||
                          _filteredMessages[index + 1].senderId !=
                              message.senderId;

                      return _MessageBubble(
                        message: message,
                        isMe: isMe,
                        showAvatar: showAvatar,
                        currentUser: widget.currentUser,
                        recipient: widget.recipient,
                      );
                    },
                  ),
          ),

          // Message Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment Button
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.blue,
                    iconSize: 28,
                    onPressed: _isSending ? null : _pickAndSendFile,
                  ),

                  // Text Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: (text) {
                          setState(() {}); // Update UI for send button
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send Button (only shown when there's text)
                  if (_messageController.text.trim().isNotEmpty || _isSending)
                    _isSending
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send),
                            color: Colors.blue,
                            iconSize: 28,
                            onPressed: _sendMessage,
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final User currentUser;
  final User recipient;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.currentUser,
    required this.recipient,
  });

  Future<void> _downloadFile(BuildContext context) async {
    if (message.fileId == null) {
      print('FileId is null, cannot download');
      return;
    }

    try {
      final url = '${ApiConfig.getBaseUrl()}/files/${message.fileId}';
      print('Attempting to download file from: $url');
      print('FileId: ${message.fileId}');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        print('Launching URL...');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('URL launched successfully');
      } else {
        print('Cannot launch URL: $url');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cannot open file URL')));
        }
      }
    } catch (e) {
      print('Error downloading file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFile = message.fileId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left side avatar (for received messages)
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue,
              backgroundImage: recipient.profilePicture != null
                  ? NetworkImage(recipient.profilePicture!)
                  : null,
              child: recipient.profilePicture == null
                  ? Text(
                      recipient.fullName.isNotEmpty
                          ? recipient.fullName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            )
          else if (!isMe)
            const SizedBox(width: 28),

          const SizedBox(width: 8),

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: hasFile ? () => _downloadFile(context) : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: hasFile ? 12 : 14,
                      vertical: hasFile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: hasFile
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: isMe ? Colors.white : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message.content.replaceAll('📎 ', ''),
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.download,
                                color: isMe ? Colors.white : Colors.blue,
                                size: 16,
                              ),
                            ],
                          )
                        : Text(
                            message.content,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 12, right: 12),
                    child: Text(
                      timeago.format(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right side avatar (for sent messages)
          if (isMe && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue,
              backgroundImage: currentUser.profilePicture != null
                  ? NetworkImage(currentUser.profilePicture!)
                  : null,
              child: currentUser.profilePicture == null
                  ? Text(
                      currentUser.fullName.isNotEmpty
                          ? currentUser.fullName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            )
          else if (isMe)
            const SizedBox(width: 28),
        ],
      ),
    );
  }
}
