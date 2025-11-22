const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  action: {
    type: String,
    required: true,
    enum: [
      'login',
      'logout',
      'course_enrollment',
      'course_completion',
      'assignment_submission',
      'quiz_attempt',
      'profile_update',
      'password_change',
      'file_upload',
      'file_download',
      'announcement_created',
      'announcement_viewed',
      'message_sent',
      'account_suspended',
      'account_activated',
      'role_changed',
      'other'
    ]
  },
  description: {
    type: String,
    required: true
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  ipAddress: {
    type: String
  },
  userAgent: {
    type: String
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
}, {
  timestamps: true
});

// Indexes for better query performance
activityLogSchema.index({ user: 1, timestamp: -1 });
activityLogSchema.index({ action: 1, timestamp: -1 });

// Static method to log activity
activityLogSchema.statics.logActivity = async function(userId, action, description, metadata = {}, req = null) {
  try {
    const log = new this({
      user: userId,
      action,
      description,
      metadata,
      ipAddress: req ? req.ip : null,
      userAgent: req ? req.get('user-agent') : null
    });
    await log.save();
    return log;
  } catch (error) {
    console.error('Error logging activity:', error);
    return null;
  }
};

// Static method to get user activity history
activityLogSchema.statics.getUserActivity = function(userId, limit = 50, skip = 0) {
  return this.find({ user: userId })
    .sort({ timestamp: -1 })
    .limit(limit)
    .skip(skip)
    .populate('user', 'fullName email role');
};

// Static method to get activity by action type
activityLogSchema.statics.getActivityByAction = function(action, limit = 100) {
  return this.find({ action })
    .sort({ timestamp: -1 })
    .limit(limit)
    .populate('user', 'fullName email role');
};

module.exports = mongoose.model('ActivityLog', activityLogSchema);
