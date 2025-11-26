import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/material.dart' as MaterialModel;
import '../../models/course.dart';
import '../../models/user.dart';
import '../../services/material_service.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';

class MaterialDetailScreen extends StatefulWidget {
  final MaterialModel.Material material;
  final Course course;

  const MaterialDetailScreen({
    super.key,
    required this.material,
    required this.course,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  final MaterialService _materialService = MaterialService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _trackView();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    setState(() => _currentUser = user);
  }

  Future<void> _trackView() async {
    try {
      await _materialService.trackMaterialView(widget.material.id);
    } catch (e) {
      // Track view silently, don't show error to user
      print('Failed to track material view: $e');
    }
  }

  Future<void> _downloadFile(MaterialModel.MaterialFile file) async {
    try {
      setState(() => _isLoading = true);
      
      // Track download
      await _materialService.trackMaterialDownload(widget.material.id, file.fileName);
      
      // Construct full URL for file download
      String fileUrl = file.fileUrl;
      if (!fileUrl.startsWith('http')) {
        // If it's a relative URL, construct full URL with API base
        fileUrl = '${ApiConfig.baseUrl}$fileUrl';
      }
      
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${file.fileName}...'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openLink(String link) async {
    try {
      // Ensure the link has a protocol
      String url = link;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.grid_on;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    if (mimeType.contains('zip') || mimeType.contains('rar')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.purple;
    if (mimeType.startsWith('video/')) return Colors.red;
    if (mimeType.startsWith('audio/')) return Colors.orange;
    if (mimeType.contains('pdf')) return Colors.red[800]!;
    if (mimeType.contains('word') || mimeType.contains('document')) return Colors.blue;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Colors.green;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Colors.orange[800]!;
    if (mimeType.contains('zip') || mimeType.contains('rar')) return Colors.brown;
    return Colors.grey;
  }

  bool get _isInstructor => _currentUser?.role == 'instructor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title),
        actions: [
          if (_isInstructor) ...[
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: _showTrackingDialog,
              tooltip: 'View Tracking',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    // Navigate to edit screen
                    break;
                  case 'export':
                    _exportTracking();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Material'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.file_download),
                    title: Text('Export Tracking'),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Course info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course.code,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(widget.course.name),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Material info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.material.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        if (widget.material.description != null && widget.material.description!.isNotEmpty) ...[
                          Text(
                            widget.material.description!,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Material metadata
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'By ${widget.material.displayAuthor}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(widget.material.createdAt),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        
                        if (_isInstructor) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.material.totalViews} views',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.download, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.material.totalDownloads} downloads',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Files section
                if (widget.material.hasFiles) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.attach_file),
                              const SizedBox(width: 8),
                              const Text(
                                'Files',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                '${widget.material.files.length} file(s) • ${widget.material.formattedFileSize}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          ...widget.material.files.map((file) => Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                _getFileIcon(file.mimeType),
                                color: _getFileColor(file.mimeType),
                                size: 32,
                              ),
                              title: Text(file.fileName),
                              subtitle: Text(
                                '${_formatFileSize(file.fileSize)} • ${file.mimeType.split('/').last.toUpperCase()}',
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _downloadFile(file),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Download'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(100, 36),
                                ),
                              ),
                              onTap: () => _downloadFile(file),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Links section
                if (widget.material.hasLinks) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.link),
                              const SizedBox(width: 8),
                              const Text(
                                'Links',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                '${widget.material.links.length} link(s)',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          ...widget.material.links.map((link) => Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.link,
                                color: Colors.blue,
                                size: 32,
                              ),
                              title: Text(
                                link,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: const Text('External Link'),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _openLink(link),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 36),
                                ),
                              ),
                              onTap: () => _openLink(link),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Instructions for students
                if (!_isInstructor) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'How to Use Materials',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('• Click "Download" to save files to your device'),
                        const Text('• Click "Open" to view links in your browser'),
                        const Text('• Your activity is tracked for course analytics'),
                        const Text('• Contact your instructor if you have trouble accessing materials'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _showTrackingDialog() async {
    if (!_isInstructor) return;
    
    try {
      final trackingData = await _materialService.getMaterialTracking(widget.material.id);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${widget.material.title} - Analytics'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary stats
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${trackingData['totalViews'] ?? 0}',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Total Views'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${trackingData['totalDownloads'] ?? 0}',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Total Downloads'),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Detailed tracking data
                    const Text('Detailed Analytics:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(trackingData.toString()),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _exportTracking(),
                child: const Text('Export'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportTracking() async {
    if (!_isInstructor) return;
    
    try {
      final csvContent = await _materialService.exportMaterialTracking(widget.material.id);
      
      // Show CSV content in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Material Tracking Export'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Text(
                  csvContent,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export tracking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}