// models/Notification.js
const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  type: {
    type: String,
    required: true,
    enum: [
      'material',        // New material uploaded
      'announcement',    // New announcement posted
      'assignment',      // New assignment created
      'comment',         // New comment on forum/discussion
      'message',         // Private message or join request
      'quiz',            // New quiz available
      'submission',      // Student submitted assignment (instructor only)
      'quiz_attempt',    // Student completed quiz (instructor only)
      'course_invite',   // Course invitation
      'course_join_request' // Student request to join course
    ]
  },
  title: {
    type: String,
    required: true
  },
  message: {
    type: String,
    required: true
  },
  data: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
    // Can contain: courseId, assignmentId, quizId, materialId, submissionId, studentId, etc.
  },
  isRead: {
    type: Boolean,
    default: false,
    index: true
  },
  readAt: {
    type: Date
  }
}, {
  timestamps: true,
  toJSON: {
    transform: function(doc, ret) {
      ret.id = ret._id.toString();
      return ret;
    }
  }
});

// Indexes for efficient queries
notificationSchema.index({ userId: 1, isRead: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, createdAt: -1 });

// Static method to create notification
notificationSchema.statics.createNotification = async function(notificationData) {
  const notification = new this(notificationData);
  return await notification.save();
};

// Static method to create multiple notifications (bulk)
notificationSchema.statics.createBulkNotifications = async function(notificationsArray) {
  return await this.insertMany(notificationsArray);
};

// Instance method to mark as read
notificationSchema.methods.markAsRead = async function() {
  this.isRead = true;
  this.readAt = new Date();
  return await this.save();
};

module.exports = mongoose.model('Notification', notificationSchema);