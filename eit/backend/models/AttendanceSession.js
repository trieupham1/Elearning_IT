const mongoose = require('mongoose');

const attendanceSessionSchema = new mongoose.Schema({
  courseId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Course',
    required: true
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  instructorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  sessionDate: {
    type: Date,
    required: true
  },
  startTime: {
    type: Date,
    required: true
  },
  endTime: {
    type: Date,
    required: true
  },
  // QR Code for attendance
  qrCode: {
    type: String,
    unique: true,
    required: true
  },
  qrCodeExpiry: {
    type: Date,
    required: true
  },
  // Location-based attendance (optional)
  location: {
    latitude: Number,
    longitude: Number,
    radius: Number // in meters
  },
  allowedMethods: [{
    type: String,
    enum: ['qr_code', 'manual', 'gps'],
    default: 'qr_code'
  }],
  isActive: {
    type: Boolean,
    default: true
  },
  // Statistics
  totalStudents: {
    type: Number,
    default: 0
  },
  presentCount: {
    type: Number,
    default: 0
  },
  absentCount: {
    type: Number,
    default: 0
  },
  lateCount: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true
});

// Index for faster queries
attendanceSessionSchema.index({ courseId: 1, sessionDate: -1 });
attendanceSessionSchema.index({ instructorId: 1 });
attendanceSessionSchema.index({ qrCode: 1 });
attendanceSessionSchema.index({ isActive: 1, qrCodeExpiry: 1 });

// Generate QR code
attendanceSessionSchema.methods.generateQRCode = function() {
  const crypto = require('crypto');
  this.qrCode = crypto.randomBytes(32).toString('hex');
  // QR code expires in 24 hours by default
  this.qrCodeExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000);
  return this.qrCode;
};

// Check if session is currently active
attendanceSessionSchema.methods.isSessionActive = function() {
  const now = new Date();
  return this.isActive && 
         now >= this.startTime && 
         now <= this.endTime &&
         now <= this.qrCodeExpiry;
};

// Update statistics
attendanceSessionSchema.methods.updateStatistics = async function() {
  const AttendanceRecord = mongoose.model('AttendanceRecord');
  const Course = mongoose.model('Course');
  
  // Get current course enrollment - count only students with role 'student'
  const course = await Course.findById(this.courseId).populate('students');
  if (course) {
    // Filter to count only users with role 'student'
    const studentCount = course.students.filter(student => student.role === 'student').length;
    this.totalStudents = studentCount;
  }
  
  const stats = await AttendanceRecord.aggregate([
    { $match: { sessionId: this._id } },
    {
      $group: {
        _id: '$status',
        count: { $sum: 1 }
      }
    }
  ]);

  // Reset counts to 0 first
  this.presentCount = 0;
  this.lateCount = 0;

  // Count actual attendance records
  stats.forEach(stat => {
    if (stat._id === 'present') this.presentCount = stat.count;
    else if (stat._id === 'late') this.lateCount = stat.count;
  });

  // Absent = Total students enrolled - (Present + Late)
  this.absentCount = this.totalStudents - this.presentCount - this.lateCount;
  
  // Ensure absent count is never negative
  if (this.absentCount < 0) {
    this.absentCount = 0;
  }

  return this.save();
};

const AttendanceSession = mongoose.model('AttendanceSession', attendanceSessionSchema);

module.exports = AttendanceSession;
