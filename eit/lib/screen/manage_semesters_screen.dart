import 'package:flutter/material.dart';
import '../services/semester_service.dart';
import '../models/semester.dart';

class ManageSemestersScreen extends StatefulWidget {
  const ManageSemestersScreen({super.key});

  @override
  State<ManageSemestersScreen> createState() => _ManageSemestersScreenState();
}

class _ManageSemestersScreenState extends State<ManageSemestersScreen> {
  final _semesterService = SemesterService();
  List<Semester> _semesters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSemesters();
  }

  Future<void> _loadSemesters() async {
    setState(() => _isLoading = true);
    try {
      final semesters = await _semesterService.getSemesters();
      setState(() {
        _semesters = semesters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading semesters: $e')));
      }
    }
  }

  void _showCreateSemesterDialog() {
    final nameController = TextEditingController();
    final yearController = TextEditingController();
    int selectedSemester = 1;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 120));
    bool setAsActive = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Semester'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Semester Name',
                      hintText: 'e.g., Semester 1, Academic Year 2025-2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: yearController,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      hintText: 'e.g., 2025-2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Semester Number',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3].map((num) {
                      return DropdownMenuItem(
                        value: num,
                        child: Text('Semester $num'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedSemester = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => startDate = date);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => endDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Set as Active Semester'),
                    subtitle: const Text(
                      'This will deactivate all other semesters',
                    ),
                    value: setAsActive,
                    onChanged: (value) {
                      setDialogState(() => setAsActive = value ?? false);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    yearController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                try {
                  Navigator.pop(context);

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final code = '$selectedSemester-${yearController.text}';
                  final name = nameController.text;
                  final year =
                      int.tryParse(yearController.text.split('-')[0]) ??
                      DateTime.now().year;

                  await _semesterService.createSemester(
                    code: code,
                    name: name,
                    year: year,
                    startDate: startDate,
                    endDate: endDate,
                    isActive: setAsActive,
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Semester created successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadSemesters();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating semester: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setActiveSemester(Semester semester) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _semesterService.setActiveSemester(semester.id);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${semester.displayName} is now active'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSemesters();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating semester: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteSemester(Semester semester) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Semester'),
        content: Text(
          'Are you sure you want to delete "${semester.displayName}"?\n\nThis will also remove all associated courses and data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                await _semesterService.deleteSemester(semester.id);

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Semester deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadSemesters();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting semester: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Semester Management')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSemesters,
              child: _semesters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No semesters yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Create your first semester'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _semesters.length,
                      itemBuilder: (context, index) {
                        final semester = _semesters[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: semester.isActive
                                  ? Colors.green
                                  : Colors.blue.shade200,
                              child: Text(
                                '${semester.code.split('-').first.substring(0, 1)}${semester.code.split('-').length > 1 ? semester.code.split('-').last.substring(2, 4) : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              semester.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${semester.startDate.year}-${semester.startDate.month.toString().padLeft(2, '0')}-${semester.startDate.day.toString().padLeft(2, '0')} to ${semester.endDate.year}-${semester.endDate.month.toString().padLeft(2, '0')}-${semester.endDate.day.toString().padLeft(2, '0')}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!semester.isActive)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                    ),
                                    tooltip: 'Set as Active',
                                    onPressed: () =>
                                        _setActiveSemester(semester),
                                  ),
                                if (semester.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteSemester(semester),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSemesterDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Semester'),
      ),
    );
  }
}
