import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/announcement.dart';
import '../../models/announcement_tracking.dart';
import '../../services/announcement_service.dart';

class AnnouncementTrackingScreen extends StatefulWidget {
  final Announcement announcement;

  const AnnouncementTrackingScreen({super.key, required this.announcement});

  @override
  State<AnnouncementTrackingScreen> createState() =>
      _AnnouncementTrackingScreenState();
}

class _AnnouncementTrackingScreenState extends State<AnnouncementTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _announcementService = AnnouncementService();
  AnnouncementTracking? _tracking;
  bool _isLoading = false;
  String _searchQuery = '';
  late TabController _tabController;

  // Sort option
  String _sortBy = 'name'; // name, date, downloads

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTracking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTracking() async {
    setState(() => _isLoading = true);
    try {
      final tracking = await _announcementService.getTracking(
        widget.announcement.id,
      );
      setState(() {
        _tracking = tracking;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load tracking data: $e');
    }
  }

  Future<void> _exportCSV() async {
    try {
      _showMessage('Exporting...', isLoading: true);

      final csv = await _announcementService.exportTrackingCSV(
        widget.announcement.id,
      );
      final fileName =
          'announcement_${widget.announcement.id}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      final file = await _announcementService.saveCSVFile(csv, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccess('Exported to: ${file.path}');
      }
    } catch (e) {
      _showError('Failed to export: $e');
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showMessage(String message, {bool isLoading = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(message),
          ],
        ),
        duration: isLoading
            ? const Duration(days: 1)
            : const Duration(seconds: 2),
      ),
    );
  }

  List<ViewerInfo> get _filteredViewers {
    if (_tracking == null) return [];

    var viewers = _tracking!.viewStats.viewers;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      viewers = viewers.where((v) {
        final query = _searchQuery.toLowerCase();
        return v.fullName.toLowerCase().contains(query) ||
            (v.email?.toLowerCase().contains(query) ?? false) ||
            (v.studentId?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sort
    switch (_sortBy) {
      case 'name':
        viewers.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'date':
        viewers.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
        break;
    }

    return viewers;
  }

  List<DownloadInfo> get _filteredDownloads {
    if (_tracking == null) return [];

    var downloads = _tracking!.downloadStats.downloads;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      downloads = downloads.where((d) {
        final query = _searchQuery.toLowerCase();
        return d.fullName.toLowerCase().contains(query) ||
            (d.email?.toLowerCase().contains(query) ?? false) ||
            (d.studentId?.toLowerCase().contains(query) ?? false) ||
            d.fileName.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sort
    switch (_sortBy) {
      case 'name':
        downloads.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'date':
        downloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
        break;
      case 'downloads':
        // Group by user and count
        downloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
        break;
    }

    return downloads;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTracking,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _tracking != null ? _exportCSV : null,
            tooltip: 'Export CSV',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.visibility), text: 'Views'),
            Tab(icon: Icon(Icons.download), text: 'Downloads'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tracking == null
          ? const Center(child: Text('No tracking data available'))
          : Column(
              children: [
                // Summary Cards
                _buildSummarySection(),

                // Search and Filter
                _buildSearchAndFilter(),

                // Content Tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildViewsTab(), _buildDownloadsTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.announcement.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${DateFormat('MMM d, yyyy h:mm a').format(_tracking!.createdAt)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Views',
                  '${_tracking!.viewStats.totalViews}',
                  Icons.visibility,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Unique Viewers',
                  '${_tracking!.viewStats.uniqueViewers}',
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Downloads',
                  '${_tracking!.downloadStats.totalDownloads}',
                  Icons.download,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Unique Downloaders',
                  '${_tracking!.downloadStats.uniqueDownloaders}',
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, email, or student ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: 12),

          // Sort options
          Row(
            children: [
              const Text('Sort by: '),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'name', label: Text('Name')),
                    ButtonSegment(value: 'date', label: Text('Date')),
                  ],
                  selected: {_sortBy},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _sortBy = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewsTab() {
    final viewers = _filteredViewers;

    if (viewers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No viewers found matching "$_searchQuery"'
                  : 'No views yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: viewers.length,
      itemBuilder: (context, index) {
        final viewer = viewers[index];
        return _buildViewerTile(viewer);
      },
    );
  }

  Widget _buildViewerTile(ViewerInfo viewer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            viewer.fullName.isNotEmpty ? viewer.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.blue.shade900),
          ),
        ),
        title: Text(viewer.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (viewer.studentId != null) Text('ID: ${viewer.studentId}'),
            if (viewer.email != null) Text(viewer.email!),
            Text(
              'Viewed: ${DateFormat('MMM d, yyyy h:mm a').format(viewer.viewedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildDownloadsTab() {
    final downloads = _filteredDownloads;

    if (downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No downloads found matching "$_searchQuery"'
                  : widget.announcement.hasAttachments
                  ? 'No downloads yet'
                  : 'No files attached',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Show file statistics first
    return Column(
      children: [
        if (_tracking!.fileStats.isNotEmpty) _buildFileStatsSection(),
        Expanded(
          child: ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final download = downloads[index];
              return _buildDownloadTile(download);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'File Download Statistics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._tracking!.fileStats.entries.map((entry) {
            final fileName = entry.key;
            final stats = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_getFileIcon(fileName), color: Colors.orange),
                title: Text(fileName),
                subtitle: Text(
                  '${stats.totalDownloads} downloads by ${stats.uniqueDownloaders} student(s)',
                ),
                trailing: Text(
                  '${stats.downloadRate.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDownloadTile(DownloadInfo download) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Text(
            download.fullName.isNotEmpty
                ? download.fullName[0].toUpperCase()
                : '?',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ),
        title: Text(download.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (download.studentId != null) Text('ID: ${download.studentId}'),
            Text(
              'File: ${download.fileName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              'Downloaded: ${DateFormat('MMM d, yyyy h:mm a').format(download.downloadedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Icon(_getFileIcon(download.fileName), color: Colors.orange),
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
}
