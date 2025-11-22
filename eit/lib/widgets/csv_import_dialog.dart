import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/import_models.dart';

class CsvImportDialog<T> extends StatefulWidget {
  final String title;
  final String entityName;
  final List<String> csvHeaders;
  final String csvTemplate;
  final T Function(List<String>) parseRow;
  final Future<List<ImportPreviewItem<T>>> Function(List<T>) validateData;
  final Future<ImportResult<T>> Function(List<ImportPreviewItem<T>>) importData;

  const CsvImportDialog({
    super.key,
    required this.title,
    required this.entityName,
    required this.csvHeaders,
    required this.csvTemplate,
    required this.parseRow,
    required this.validateData,
    required this.importData,
  });

  @override
  State<CsvImportDialog<T>> createState() => _CsvImportDialogState<T>();
}

class _CsvImportDialogState<T> extends State<CsvImportDialog<T>> {
  List<ImportPreviewItem<T>>? _previewItems;
  ImportResult<T>? _importResult;
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _pickAndProcessCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Could not read file';
          _isProcessing = false;
        });
        return;
      }

      // Parse CSV
      final csvString = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(csvString);

      if (rows.isEmpty || rows.length < 2) {
        setState(() {
          _errorMessage = 'CSV file is empty or has no data rows';
          _isProcessing = false;
        });
        return;
      }

      // Skip header row and parse data
      final parsedData = <T>[];
      for (int i = 1; i < rows.length; i++) {
        try {
          final row = rows[i].map((e) => e.toString()).toList();
          parsedData.add(widget.parseRow(row));
        } catch (e) {
          // Skip invalid rows
        }
      }

      // Validate and get preview
      final previewItems = await widget.validateData(parsedData);

      setState(() {
        _previewItems = previewItems;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing CSV: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_previewItems == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await widget.importData(_previewItems!);
      setState(() {
        _importResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error importing data: $e';
        _isProcessing = false;
      });
    }
  }

  void _downloadTemplate() {
    // TODO: Implement template download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template download coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_importResult == null) ...[
              _buildInstructions(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 16),
              if (_errorMessage != null) _buildErrorMessage(),
              if (_isProcessing) _buildProcessingIndicator(),
              if (_previewItems != null) _buildPreviewSection(),
            ] else
              _buildResultSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'CSV Import Instructions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'CSV must include these columns: ${widget.csvHeaders.join(', ')}',
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _pickAndProcessCsv,
          icon: const Icon(Icons.file_upload),
          label: const Text('Select CSV File'),
        ),
        if (_previewItems != null) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _confirmImport,
            icon: const Icon(Icons.check),
            label: Text('Import ${_getImportableCount()} Items'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final stats = _getPreviewStats();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip('Total', stats['total']!, Colors.blue),
                  _buildStatChip('Will Add', stats['willAdd']!, Colors.green),
                  _buildStatChip('Exists', stats['exists']!, Colors.orange),
                  _buildStatChip('Errors', stats['errors']!, Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _previewItems!.length,
              itemBuilder: (context, index) {
                final item = _previewItems![index];
                return _buildPreviewItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(ImportPreviewItem<T> item) {
    Color color;
    IconData icon;
    String statusText;

    switch (item.status) {
      case ImportStatus.willBeAdded:
        color = Colors.green;
        icon = Icons.add_circle;
        statusText = 'Will be added';
        break;
      case ImportStatus.alreadyExists:
        color = Colors.orange;
        icon = Icons.info;
        statusText = 'Already exists';
        break;
      case ImportStatus.error:
        color = Colors.red;
        icon = Icons.error;
        statusText = 'Error';
        break;
      case ImportStatus.updated:
        color = Colors.blue;
        icon = Icons.update;
        statusText = 'Will update';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('Row ${item.rowNumber}: ${item.data.toString()}'),
        subtitle: item.message != null ? Text(item.message!) : Text(statusText),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    return Expanded(
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Import Complete!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildResultRow('Total Rows', _importResult!.totalRows),
                  const Divider(),
                  _buildResultRow('Added', _importResult!.added, Colors.green),
                  _buildResultRow(
                    'Skipped',
                    _importResult!.skipped,
                    Colors.orange,
                  ),
                  _buildResultRow('Errors', _importResult!.errors, Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultRow(String label, int count, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getPreviewStats() {
    if (_previewItems == null) {
      return {'total': 0, 'willAdd': 0, 'exists': 0, 'errors': 0};
    }

    return {
      'total': _previewItems!.length,
      'willAdd': _previewItems!
          .where((i) => i.status == ImportStatus.willBeAdded)
          .length,
      'exists': _previewItems!
          .where((i) => i.status == ImportStatus.alreadyExists)
          .length,
      'errors': _previewItems!
          .where((i) => i.status == ImportStatus.error)
          .length,
    };
  }

  int _getImportableCount() {
    if (_previewItems == null) return 0;
    return _previewItems!
        .where(
          (i) =>
              i.status == ImportStatus.willBeAdded ||
              i.status == ImportStatus.updated,
        )
        .length;
  }
}
