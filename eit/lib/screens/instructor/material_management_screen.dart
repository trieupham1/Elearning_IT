import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/material.dart' as MaterialModel;
import '../../models/course.dart';
import '../../services/material_service.dart';
import 'create_material_screen.dart';
import 'material_detail_screen.dart';

class MaterialManagementScreen extends StatefulWidget {
  final Course course;

  const MaterialManagementScreen({
    super.key,
    required this.course,
  });

  @override
  State<MaterialManagementScreen> createState() => _MaterialManagementScreenState();
}

class _MaterialManagementScreenState extends State<MaterialManagementScreen> {
  final MaterialService _materialService = MaterialService();
  List<MaterialModel.Material> _materials = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      setState(() => _isLoading = true);
      final materials = await _materialService.getMaterialsForCourse(widget.course.id);
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load materials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<MaterialModel.Material> get _filteredMaterials {
    if (_searchQuery.isEmpty) return _materials;
    return _materials.where((material) {
      return material.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (material.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  Future<void> _deleteMaterial(MaterialModel.Material material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete "${material.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _materialService.deleteMaterial(material.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMaterials();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportTracking() async {
    try {
      final csvContent = await _materialService.exportCourseTracking(widget.course.id);
      
      // Show CSV content in a dialog for now
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Materials Tracking Export'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.course.code} - Materials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportTracking,
            tooltip: 'Export Tracking',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadMaterials();
                  break;
                case 'export':
                  _exportTracking();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Export Tracking'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateMaterialScreen(course: widget.course),
            ),
          );
          if (result == true) {
            _loadMaterials();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Material',
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search materials...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          
          // Statistics cards
          if (!_isLoading && _materials.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard('Total Materials', _materials.length.toString(), Icons.folder)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Total Views', _materials.fold(0, (sum, m) => sum + m.totalViews).toString(), Icons.visibility)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Total Downloads', _materials.fold(0, (sum, m) => sum + m.totalDownloads).toString(), Icons.download)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Materials list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMaterials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No materials found'
                                  : 'No materials match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateMaterialScreen(course: widget.course),
                                  ),
                                );
                                if (result == true) {
                                  _loadMaterials();
                                }
                              },
                              child: const Text('Create First Material'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          return _buildMaterialCard(material);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(MaterialModel.Material material) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            material.hasFiles ? Icons.attach_file : Icons.link,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          material.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (material.description != null && material.description!.isNotEmpty) ...[
              Text(
                material.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                if (material.hasFiles) ...[
                  Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
                  Text(' ${material.files.length} files', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                if (material.hasLinks) ...[
                  Icon(Icons.link, size: 16, color: Colors.grey[600]),
                  Text(' ${material.links.length} links', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                Text(' ${material.totalViews} views', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.download, size: 16, color: Colors.grey[600]),
                Text(' ${material.totalDownloads} downloads', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Created ${DateFormat('MMM dd, yyyy').format(material.createdAt)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'view':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaterialDetailScreen(
                      material: material,
                      course: widget.course,
                    ),
                  ),
                );
                break;
              case 'edit':
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateMaterialScreen(
                      course: widget.course,
                      material: material,
                    ),
                  ),
                );
                if (result == true) {
                  _loadMaterials();
                }
                break;
              case 'delete':
                _deleteMaterial(material);
                break;
              case 'tracking':
                _showTrackingDialog(material);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('View'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'tracking',
              child: ListTile(
                leading: Icon(Icons.analytics),
                title: Text('View Tracking'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialDetailScreen(
                material: material,
                course: widget.course,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTrackingDialog(MaterialModel.Material material) async {
    try {
      final trackingData = await _materialService.getMaterialTracking(material.id);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${material.title} - Tracking'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Views: ${trackingData['totalViews'] ?? 0}'),
                    Text('Downloads: ${trackingData['totalDownloads'] ?? 0}'),
                    const SizedBox(height: 16),
                    const Text('Recent Activity:', style: TextStyle(fontWeight: FontWeight.bold)),
                    // Add more tracking details here
                    Text(trackingData.toString()),
                  ],
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
          content: Text('Failed to load tracking data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}