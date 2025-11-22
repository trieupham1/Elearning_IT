const mongoose = require('mongoose');

const attendanceRecordSchema = new mongoose.Schema({
  sessionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'AttendanceSession',
    required: true
  },
  studentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['present', 'absent', 'late', 'excused'],
    required: true
  },
  checkInTime: {
    type: Date
  },
  checkInMethod: {
    type: String,
    enum: ['qr_code', 'manual', 'gps'],
    default: 'qr_code'
  },
  // GPS location when checked in (if GPS method used)
  location: {
    latitude: Number,
    longitude: Number,
    accuracy: Number // in meters
  },
  // Instructor notes
  notes: {
    type: String,
    trim: true
  },
  // For excused absences
  excuseReason: {
    type: String,
    trim: true
  },
  excuseDocument: {
    type: mongoose.Schema.Types.ObjectId // GridFS file ID
  },
  markedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User' // Instructor who manually marked attendance
  }
}, {
  timestamps: true
});

// Compound index to ensure one record per student per session
attendanceRecordSchema.index({ sessionId: 1, studentId: 1 }, { unique: true });
attendanceRecordSchema.index({ studentId: 1, createdAt: -1 });

// Calculate if student was late
attendanceRecordSchema.methods.calculateLateStatus = function(sessionStartTime, lateThresholdMinutes = 15) {
  if (!this.checkInTime) return false;
  
  const threshold = new Date(sessionStartTime.getTime() + lateThresholdMinutes * 60000);
  return this.checkInTime > threshold;
};

// Auto-set status based on check-in time
attendanceRecordSchema.pre('save', async function(next) {
  if (this.checkInTime && this.status === 'present') {
    const session = await mongoose.model('AttendanceSession').findById(this.sessionId);
    if (session) {
      const isLate = this.calculateLateStatus(session.startTime);
      if (isLate) {
        this.status = 'late';
      }
    }
  }
  next();
});

const AttendanceRecord = mongoose.model('AttendanceRecord', attendanceRecordSchema);

module.exports = AttendanceRecord;
