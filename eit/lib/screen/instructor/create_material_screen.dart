import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/material.dart' as MaterialModel;
import '../../models/course.dart';
import '../../services/material_service.dart';

class CreateMaterialScreen extends StatefulWidget {
  final Course course;
  final MaterialModel.Material? material; // For editing

  const CreateMaterialScreen({
    super.key,
    required this.course,
    this.material,
  });

  @override
  State<CreateMaterialScreen> createState() => _CreateMaterialScreenState();
}

class _CreateMaterialScreenState extends State<CreateMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  
  final MaterialService _materialService = MaterialService();
  
  List<File> _selectedFiles = [];
  List<PlatformFile> _selectedWebFiles = [];
  List<String> _links = [];
  bool _isLoading = false;
  
  bool get _isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.material!.title;
      _descriptionController.text = widget.material!.description ?? '';
      _links = List.from(widget.material!.links);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            // For web, use PlatformFile with bytes
            _selectedWebFiles.addAll(result.files);
          } else {
            // For mobile, use File with paths
            _selectedFiles.addAll(
              result.paths.where((path) => path != null).map((path) => File(path!)),
            );
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedWebFiles.removeAt(index);
      } else {
        _selectedFiles.removeAt(index);
      }
    });
  }

  void _addLink() {
    final link = _linkController.text.trim();
    if (link.isNotEmpty) {
      setState(() {
        _links.add(link);
        _linkController.clear();
      });
    }
  }

  void _removeLink(int index) {
    setState(() {
      _links.removeAt(index);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;
    
    final hasFiles = kIsWeb ? _selectedWebFiles.isNotEmpty : _selectedFiles.isNotEmpty;
    if (!hasFiles && _links.isEmpty && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one file or link'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload files first
      final List<Map<String, dynamic>> uploadedFiles = [];
      
      if (kIsWeb) {
        // Handle web files (PlatformFile with bytes)
        for (final file in _selectedWebFiles) {
          final fileData = await _materialService.uploadMaterialFileBytes(
            file.bytes!,
            file.name,
          );
          uploadedFiles.add({
            'fileName': fileData['fileName'] ?? file.name,
            'fileUrl': fileData['fileUrl'] ?? fileData['url'],
            'fileSize': fileData['fileSize'] ?? file.size,
            'mimeType': fileData['mimeType'] ?? 'application/octet-stream',
          });
        }
      } else {
        // Handle mobile files (File with paths)
        for (final file in _selectedFiles) {
          final fileData = await _materialService.uploadMaterialFile(file);
          uploadedFiles.add({
            'fileName': fileData['fileName'] ?? file.path.split('/').last,
            'fileUrl': fileData['fileUrl'] ?? fileData['url'],
            'fileSize': fileData['fileSize'] ?? await file.length(),
            'mimeType': fileData['mimeType'] ?? 'application/octet-stream',
          });
        }
      }

      // Prepare material data
      final materialData = {
        'courseId': widget.course.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'files': uploadedFiles,
        'links': _links,
      };

      // Create or update material
      if (_isEditing) {
        // For editing, merge with existing files
        final existingFiles = widget.material!.files.map((f) => {
          'fileName': f.fileName,
          'fileUrl': f.fileUrl,
          'fileSize': f.fileSize,
          'mimeType': f.mimeType,
        }).toList();
        materialData['files'] = [...existingFiles, ...uploadedFiles];
        
        await _materialService.updateMaterial(widget.material!.id, materialData);
      } else {
        await _materialService.createMaterial(materialData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material ${_isEditing ? 'updated' : 'created'} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${_isEditing ? 'update' : 'create'} material: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_isEditing ? 'Edit' : 'Create'} Material'),
        actions: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            TextButton(
              onPressed: _saveMaterial,
              child: Text(
                _isEditing ? 'UPDATE' : 'CREATE',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
                      'Course: ${widget.course.code}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(widget.course.name),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Material Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a material title';
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),

            // Files section
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
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickFiles,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Files'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Existing files (for editing)
                    if (_isEditing && widget.material!.hasFiles) ...[
                      const Text('Existing Files:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...widget.material!.files.map((file) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(file.fileName),
                        subtitle: Text(_formatFileSize(file.fileSize)),
                        dense: true,
                      )),
                      const SizedBox(height: 16),
                    ],
                    
                    // New files to upload
                    if ((kIsWeb && _selectedWebFiles.isNotEmpty) || (!kIsWeb && _selectedFiles.isNotEmpty)) ...[
                      const Text('New Files to Upload:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (kIsWeb)
                        ..._selectedWebFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(file.name),
                            subtitle: Text(_formatFileSize(file.size)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeFile(index),
                            ),
                            dense: true,
                          );
                        })
                      else
                        ..._selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return FutureBuilder<FileStat>(
                            future: file.stat(),
                            builder: (context, snapshot) {
                              final size = snapshot.data?.size ?? 0;
                              return ListTile(
                                leading: const Icon(Icons.insert_drive_file),
                                title: Text(file.path.split('/').last),
                                subtitle: Text(_formatFileSize(size)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeFile(index),
                                ),
                                dense: true,
                              );
                            }
                          );
                        }),
                    ] else if (!_isEditing || !widget.material!.hasFiles) ...[
                      const Center(
                        child: Text(
                          'No files selected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Links section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link),
                        SizedBox(width: 8),
                        Text(
                          'Links',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Add link field
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              labelText: 'Add a link (URL)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final uri = Uri.tryParse(value);
                                if (uri == null || !uri.hasAbsolutePath || (!uri.scheme.startsWith('http'))) {
                                  return 'Please enter a valid URL';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addLink,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Links list
                    if (_links.isNotEmpty) ...[
                      const Text('Added Links:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._links.asMap().entries.map((entry) {
                        final index = entry.key;
                        final link = entry.value;
                        return ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(
                            link,
                            style: const TextStyle(color: Colors.blue),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _removeLink(index),
                          ),
                          dense: true,
                        );
                      }),
                    ] else ...[
                      const Center(
                        child: Text(
                          'No links added',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
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
                        'Material Guidelines',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Materials are automatically visible to all students in the course'),
                  const Text('• You can track who views and downloads your materials'),
                  const Text('• Supported file types: PDF, DOC, PPT, images, videos, and more'),
                  const Text('• Links should include http:// or https://'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}