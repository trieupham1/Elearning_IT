import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import 'check_in_screen.dart';

class AttendanceDetailScreen extends StatefulWidget {
  final AttendanceSession session;

  const AttendanceDetailScreen({super.key, required this.session});

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  bool _isLoading = true;
  bool _hasCheckedIn = false;
  Map<String, dynamic>? _attendanceRecord;

  @override
  void initState() {
    super.initState();
    _checkAttendanceStatus();
  }

  Future<void> _checkAttendanceStatus() async {
    try {
      final status = await AttendanceService.getMyAttendanceStatus(
        widget.session.id,
      );
      if (mounted) {
        setState(() {
          _hasCheckedIn = status['hasCheckedIn'] ?? false;
          _attendanceRecord = status['record'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking attendance status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _canCheckIn {
    if (_hasCheckedIn) return false; // Already checked in
    final now = DateTime.now();
    return widget.session.isActive &&
        now.isAfter(widget.session.startTime) &&
        now.isBefore(widget.session.endTime);
  }

  String get _statusMessage {
    if (_hasCheckedIn) {
      final checkInTime = _attendanceRecord?['checkInTime'];
      if (checkInTime != null) {
        final time = DateTime.parse(checkInTime).toLocal();
        return 'You checked in at ${DateFormat('h:mm a').format(time)}';
      }
      return 'You have already checked in';
    }

    final now = DateTime.now();

    if (!widget.session.isActive) {
      return 'This session has been closed';
    }

    if (now.isBefore(widget.session.startTime)) {
      final diff = widget.session.startTime.difference(now);
      if (diff.inHours > 0) {
        return 'Check-in opens in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        return 'Check-in opens in ${diff.inMinutes}m';
      }
    }

    if (now.isAfter(widget.session.endTime)) {
      return 'Check-in period has ended';
    }

    return 'Check-in is now open!';
  }

  Color get _statusColor {
    if (_hasCheckedIn) return Colors.green;
    if (_canCheckIn) return Colors.blue;
    return Colors.grey;
  }

  IconData get _statusIcon {
    if (_hasCheckedIn) return Icons.check_circle;
    if (_canCheckIn) return Icons.qr_code_scanner;
    return Icons.lock_clock;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Banner
                  Container(
                    color: _statusColor,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(_statusIcon, color: Colors.white, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Session Details Card
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Details',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),

                          _buildDetailRow(
                            Icons.calendar_today,
                            'Date',
                            DateFormat(
                              'EEEE, MMM dd, yyyy',
                            ).format(widget.session.sessionDate),
                          ),
                          const SizedBox(height: 12),

                          _buildDetailRow(
                            Icons.access_time,
                            'Time',
                            '${DateFormat('h:mm a').format(widget.session.startTime)} - ${DateFormat('h:mm a').format(widget.session.endTime)}',
                          ),
                          const SizedBox(height: 12),

                          if (widget.session.description != null &&
                              widget.session.description!.isNotEmpty) ...[
                            _buildDetailRow(
                              Icons.description,
                              'Description',
                              widget.session.description!,
                            ),
                            const SizedBox(height: 12),
                          ],

                          _buildDetailRow(
                            Icons.how_to_reg,
                            'Check-in Method',
                            widget.session.allowedMethods.contains('qr_code')
                                ? 'QR Code'
                                : 'Manual',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Check-in Button or Already Checked In Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _hasCheckedIn
                        ? Card(
                            color: Colors.green.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Already Checked In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        if (_attendanceRecord?['status'] !=
                                            null)
                                          Text(
                                            'Status: ${_attendanceRecord!['status'].toString().toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _canCheckIn
                        ? ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CheckInScreen(),
                                ),
                              );

                              // Refresh status after check-in
                              if (mounted && result == true) {
                                await _checkAttendanceStatus();
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner, size: 28),
                            label: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Scan QR Code to Check In',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          )
                        : Container(),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
