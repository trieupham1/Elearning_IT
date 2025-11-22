const express = require('express');
const router = express.Router();
const { auth, instructorOnly } = require('../middleware/auth');
const AttendanceSession = require('../models/AttendanceSession');
const AttendanceRecord = require('../models/AttendanceRecord');
const Course = require('../models/Course');
const { notifyAbsenceToStudent } = require('../utils/notificationHelper');

// @route   POST /api/attendance/sessions
// @desc    Create attendance session
// @access  Private (Instructor only)
router.post('/sessions', auth, instructorOnly, async (req, res) => {
  try {
    const {
      courseId,
      title,
      description,
      sessionDate,
      startTime,
      endTime,
      allowedMethods,
      location
    } = req.body;

    if (!courseId || !title || !sessionDate || !startTime || !endTime) {
      return res.status(400).json({
        message: 'courseId, title, sessionDate, startTime, and endTime are required'
      });
    }

    // Verify course exists and instructor is assigned
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Not authorized for this course' });
    }

    // Get total students enrolled
    const totalStudents = course.students.length;

    // Create session
    const session = new AttendanceSession({
      courseId,
      title,
      description,
      instructorId: req.user.userId,
      sessionDate: new Date(sessionDate),
      startTime: new Date(startTime),
      endTime: new Date(endTime),
      allowedMethods: allowedMethods || ['qr_code'],
      location,
      totalStudents
    });

    // Generate QR code
    session.generateQRCode();

    await session.save();

    res.status(201).json({
      message: 'Attendance session created successfully',
      session
    });

  } catch (error) {
    console.error('Create attendance session error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/attendance/sessions/course/:courseId
// @desc    Get all sessions for a course
// @access  Private
router.get('/sessions/course/:courseId', auth, async (req, res) => {
  try {
    const sessions = await AttendanceSession.find({
      courseId: req.params.courseId
    })
    .populate('instructorId') // Remove field selection to include virtuals
    .sort({ sessionDate: -1, startTime: -1 });

    // Update statistics for all sessions
    await Promise.all(sessions.map(session => session.updateStatistics()));

    res.json(sessions);

  } catch (error) {
    console.error('Get sessions error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/attendance/sessions/:id
// @desc    Get session details
// @access  Private
router.get('/sessions/:id', auth, async (req, res) => {
  try {
    const session = await AttendanceSession.findById(req.params.id)
      .populate('instructorId'); // Remove field selection to include virtuals

    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    // Update statistics before returning
    await session.updateStatistics();

    res.json(session);

  } catch (error) {
    console.error('Get session error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/attendance/check-in
// @desc    Student check-in with QR code
// @access  Private
router.post('/check-in', auth, async (req, res) => {
  try {
    const { qrCode, location } = req.body;

    if (!qrCode) {
      return res.status(400).json({ message: 'QR code is required' });
    }

    // Find active session with this QR code
    const session = await AttendanceSession.findOne({
      qrCode,
      isActive: true,
      qrCodeExpiry: { $gte: new Date() }
    });

    if (!session) {
      return res.status(404).json({
        message: 'Invalid or expired QR code'
      });
    }

    // Check if session is currently active (within time range)
    if (!session.isSessionActive()) {
      return res.status(400).json({
        message: 'Attendance session is not currently active'
      });
    }

    // Verify student is enrolled in the course
    const course = await Course.findById(session.courseId);
    if (!course.students.includes(req.user.userId)) {
      return res.status(403).json({
        message: 'You are not enrolled in this course'
      });
    }

    // Check if student already checked in
    let record = await AttendanceRecord.findOne({
      sessionId: session._id,
      studentId: req.user.userId
    });

    if (record) {
      return res.status(400).json({
        message: 'You have already checked in for this session'
      });
    }

    // Validate GPS location if required
    if (session.location && location) {
      const distance = calculateDistance(
        session.location.latitude,
        session.location.longitude,
        location.latitude,
        location.longitude
      );

      if (distance > session.location.radius) {
        return res.status(400).json({
          message: 'You are outside the allowed check-in area'
        });
      }
    }

    // Create attendance record
    record = new AttendanceRecord({
      sessionId: session._id,
      studentId: req.user.userId,
      status: 'present', // Will be auto-updated to 'late' if needed
      checkInTime: new Date(),
      checkInMethod: location ? 'gps' : 'qr_code',
      location
    });

    await record.save();

    // Update session statistics
    await session.updateStatistics();

    res.json({
      message: 'Check-in successful',
      record: {
        status: record.status,
        checkInTime: record.checkInTime
      }
    });

  } catch (error) {
    console.error('Check-in error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/attendance/sessions/:id/my-status
// @desc    Check if current student has checked in for this session
// @access  Private (Student)
router.get('/sessions/:id/my-status', auth, async (req, res) => {
  try {
    const record = await AttendanceRecord.findOne({
      sessionId: req.params.id,
      studentId: req.user.userId
    });

    res.json({
      hasCheckedIn: !!record,
      record: record ? {
        status: record.status,
        checkInTime: record.checkInTime,
        checkInMethod: record.checkInMethod
      } : null
    });

  } catch (error) {
    console.error('Error checking attendance status:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/attendance/sessions/:id/mark
// @desc    Manual attendance marking by instructor
// @access  Private (Instructor only)
router.post('/sessions/:id/mark', auth, instructorOnly, async (req, res) => {
  try {
    const { studentId, status, notes, excuseReason } = req.body;

    if (!studentId || !status) {
      return res.status(400).json({
        message: 'studentId and status are required'
      });
    }

    const session = await AttendanceSession.findById(req.params.id);
    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    // Verify instructor owns this session
    if (session.instructorId.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    // Create or update attendance record
    let record = await AttendanceRecord.findOne({
      sessionId: session._id,
      studentId
    });

    if (record) {
      record.status = status;
      record.notes = notes;
      record.excuseReason = excuseReason;
      record.markedBy = req.user.userId;
    } else {
      record = new AttendanceRecord({
        sessionId: session._id,
        studentId,
        status,
        notes,
        excuseReason,
        checkInMethod: 'manual',
        markedBy: req.user.userId
      });
    }

    await record.save();

    // Update session statistics
    await session.updateStatistics();

    // Send notification if marked absent
    if (status === 'absent') {
      notifyAbsenceToStudent(studentId, session.title, session.sessionDate);
    }

    res.json({
      message: 'Attendance marked successfully',
      record
    });

  } catch (error) {
    console.error('Mark attendance error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/attendance/sessions/:id/records
// @desc    Get all attendance records for a session
// @access  Private (Instructor only)
router.get('/sessions/:id/records', auth, instructorOnly, async (req, res) => {
  try {
    const session = await AttendanceSession.findById(req.params.id);
    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    // Update statistics before returning
    await session.updateStatistics();

    const records = await AttendanceRecord.find({
      sessionId: req.params.id
    })
    .populate('studentId') // Remove field selection to include virtuals
    .populate('markedBy') // Remove field selection to include virtuals
    .sort({ createdAt: -1 });

    // Get enrolled students
    const course = await Course.findById(session.courseId)
      .populate('students'); // Remove field selection to include virtuals

    // Create list with all students, marking absent those not in records
    const recordMap = new Map(
      records.map(r => [r.studentId._id.toString(), r])
    );

    const allRecords = course.students.map(student => {
      const record = recordMap.get(student._id.toString());
      if (record) {
        return record;
      } else {
        return {
          studentId: student,
          status: 'absent',
          sessionId: session._id
        };
      }
    });

    res.json(allRecords);

  } catch (error) {
    console.error('Get attendance records error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/attendance/student/history
// @desc    Get student's attendance history
// @access  Private
router.get('/student/history', auth, async (req, res) => {
  try {
    const { courseId } = req.query;

    const query = { studentId: req.user.userId };
    if (courseId) {
      // Get sessions for this course first
      const sessions = await AttendanceSession.find({ courseId });
      const sessionIds = sessions.map(s => s._id);
      query.sessionId = { $in: sessionIds };
    }

    const records = await AttendanceRecord.find(query)
      .populate({
        path: 'sessionId',
        populate: {
          path: 'courseId',
          select: 'name code'
        }
      })
      .sort({ createdAt: -1 });

    res.json(records);

  } catch (error) {
    console.error('Get student history error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/attendance/reports/:courseId
// @desc    Get attendance report for a course
// @access  Private (Instructor only)
router.get('/reports/:courseId', auth, instructorOnly, async (req, res) => {
  try {
    const course = await Course.findById(req.params.courseId)
      .populate('students'); // Remove field selection to include virtuals

    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    // Get all sessions for this course
    const sessions = await AttendanceSession.find({
      courseId: req.params.courseId
    }).sort({ sessionDate: -1 });

    // Get all records for these sessions
    const sessionIds = sessions.map(s => s._id);
    const records = await AttendanceRecord.find({
      sessionId: { $in: sessionIds }
    });

    // Calculate statistics per student
    const studentStats = course.students.map(student => {
      const studentRecords = records.filter(
        r => r.studentId.toString() === student._id.toString()
      );

      const present = studentRecords.filter(r => r.status === 'present').length;
      const late = studentRecords.filter(r => r.status === 'late').length;
      const absent = studentRecords.filter(r => r.status === 'absent').length;
      const excused = studentRecords.filter(r => r.status === 'excused').length;

      const attendanceRate = sessions.length > 0
        ? ((present + late) / sessions.length) * 100
        : 0;

      return {
        student: {
          id: student._id,
          fullName: student.fullName,
          email: student.email
        },
        totalSessions: sessions.length,
        present,
        late,
        absent,
        excused,
        attendanceRate: Math.round(attendanceRate * 10) / 10
      };
    });

    res.json({
      course: {
        id: course._id,
        name: course.name,
        code: course.code
      },
      totalSessions: sessions.length,
      studentStats,
      sessions: sessions.map(s => ({
        id: s._id,
        title: s.title,
        date: s.sessionDate,
        presentCount: s.presentCount,
        absentCount: s.absentCount,
        lateCount: s.lateCount
      }))
    });

  } catch (error) {
    console.error('Get attendance report error:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   PUT /api/attendance/sessions/:id
// @desc    Update session (close, regenerate QR, etc.)
// @access  Private (Instructor only)
router.put('/sessions/:id', auth, instructorOnly, async (req, res) => {
  try {
    const session = await AttendanceSession.findById(req.params.id);
    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    if (session.instructorId.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    const { isActive, regenerateQR } = req.body;

    if (isActive !== undefined) {
      session.isActive = isActive;
    }

    if (regenerateQR) {
      session.generateQRCode();
    }

    await session.save();

    res.json({
      message: 'Session updated successfully',
      session
    });

  } catch (error) {
    console.error('Update session error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Helper function to calculate distance between two GPS coordinates
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

module.exports = router;
