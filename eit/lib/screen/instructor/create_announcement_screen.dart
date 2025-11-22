import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/course.dart';
import '../../models/group.dart';
import '../../models/announcement.dart';
import '../../services/announcement_service.dart';
import '../../services/group_service.dart';
import '../../services/file_service.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final Course course;
  final Announcement? announcement; // For edit mode

  const CreateAnnouncementScreen({
    super.key,
    required this.course,
    this.announcement,
  });

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _announcementService = AnnouncementService();
  final _fileService = FileService();

  List<Group> _allGroups = [];
  List<String> _selectedGroupIds = [];
  List<AnnouncementAttachment> _attachments = [];
  List<PlatformFile> _pendingFiles = [];
  bool _isLoading = false;
  bool _uploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();

    // If editing, populate fields
    if (widget.announcement != null) {
      _titleController.text = widget.announcement!.title;
      _contentController.text = widget.announcement!.content;
      _selectedGroupIds = List.from(widget.announcement!.groupIds);
      _attachments = List.from(widget.announcement!.attachments);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await GroupService.getGroupsByCourse(widget.course.id);
      setState(() {
        _allGroups = groups;
      });
    } catch (e) {
      _showError('Failed to load groups: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _pendingFiles.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Failed to pick files: $e');
    }
  }

  Future<void> _uploadPendingFiles() async {
    if (_pendingFiles.isEmpty) return;

    setState(() => _uploadingFiles = true);

    try {
      for (final file in _pendingFiles) {
        // Upload file using the new API that takes PlatformFile
        final uploadResult = await _fileService.uploadFile(file);

        _attachments.add(
          AnnouncementAttachment(
            name: uploadResult['fileName'],
            url: uploadResult['fileUrl'],
            size: uploadResult['fileSize'],
          ),
        );
      }

      setState(() {
        _pendingFiles.clear();
        _uploadingFiles = false;
      });

      _showSuccess('Files uploaded successfully');
    } catch (e) {
      setState(() => _uploadingFiles = false);
      _showError('Failed to upload files: $e');
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _removePendingFile(int index) {
    setState(() {
      _pendingFiles.removeAt(index);
    });
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Upload pending files first
    if (_pendingFiles.isNotEmpty) {
      await _uploadPendingFiles();
      if (_uploadingFiles) return; // Still uploading
    }

    setState(() => _isLoading = true);

    try {
      final attachmentsJson = _attachments.map((a) => a.toJson()).toList();

      if (widget.announcement != null) {
        // Update existing announcement
        await _announcementService.updateAnnouncement(
          announcementId: widget.announcement!.id,
          title: _titleController.text,
          content: _contentController.text,
          groupIds: _selectedGroupIds,
          attachments: attachmentsJson,
        );
        _showSuccess('Announcement updated successfully');
      } else {
        // Create new announcement
        await _announcementService.createAnnouncement(
          courseId: widget.course.id,
          title: _titleController.text,
          content: _contentController.text,
          groupIds: _selectedGroupIds,
          attachments: attachmentsJson,
        );
        _showSuccess('Announcement created successfully');
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      _showError('Failed to save announcement: $e');
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.announcement != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Announcement' : 'Create Announcement'),
        actions: [
          if (_isLoading || _uploadingFiles)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveAnnouncement,
              tooltip: 'Save',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter announcement title',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Content Field
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content *',
                hintText: 'Enter announcement content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              maxLength: 5000,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Content is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Group Selection
            _buildGroupSelection(),
            const SizedBox(height: 24),

            // Attachments Section
            _buildAttachmentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Target Groups',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedGroupIds.isEmpty
                  ? 'All students in the course'
                  : '${_selectedGroupIds.length} group(s) selected',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // All Students Option
            CheckboxListTile(
              title: const Text('All Students'),
              subtitle: const Text('Send to all students in the course'),
              value: _selectedGroupIds.isEmpty,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedGroupIds.clear();
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_allGroups.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Or select specific groups:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Group Checkboxes
              ..._allGroups.map((group) {
                final isSelected = _selectedGroupIds.contains(group.id);
                return CheckboxListTile(
                  title: Text(group.name),
                  subtitle: Text('${group.members.length} member(s)'),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedGroupIds.add(group.id);
                      } else {
                        _selectedGroupIds.remove(group.id);
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _uploadingFiles ? null : _pickFiles,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Files'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Uploaded Attachments
            if (_attachments.isNotEmpty) ...[
              const Text(
                'Uploaded Files:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                return _buildAttachmentTile(
                  name: attachment.name,
                  size: attachment.formattedSize,
                  isUploaded: true,
                  onRemove: () => _removeAttachment(index),
                );
              }),
              const SizedBox(height: 12),
            ],

            // Pending Files
            if (_pendingFiles.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pending Upload:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (!_uploadingFiles)
                    TextButton.icon(
                      onPressed: _uploadPendingFiles,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload All'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ..._pendingFiles.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return _buildAttachmentTile(
                  name: file.name,
                  size: _formatBytes(file.size),
                  isUploaded: false,
                  onRemove: _uploadingFiles
                      ? null
                      : () => _removePendingFile(index),
                );
              }),
            ],

            if (_attachments.isEmpty && _pendingFiles.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No files attached',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentTile({
    required String name,
    required String size,
    required bool isUploaded,
    VoidCallback? onRemove,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getFileIcon(name),
          color: isUploaded ? Colors.green : Colors.orange,
        ),
        title: Text(name),
        subtitle: Text(size),
        trailing: onRemove != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
                tooltip: 'Remove',
              )
            : null,
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return Icons.image;
    } else if (['pdf'].contains(extension)) {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.description;
    } else if (['xls', 'xlsx'].contains(extension)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow;
    } else if (['zip', 'rar', '7z'].contains(extension)) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
