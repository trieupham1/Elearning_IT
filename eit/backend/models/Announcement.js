// models/Announcement.js
const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: { type: String, required: true },
  userAvatar: String,
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

const announcementSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  title: { type: String, required: true },
  content: { type: String, required: true },
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  authorName: { type: String, required: true },
  authorAvatar: String,
  groupIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Group' }], // Empty array = all groups
  attachments: [{
    fileName: String,
    fileUrl: String,
    fileSize: Number,
    mimeType: String
  }],
  comments: [commentSchema],
  viewedBy: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    viewedAt: { type: Date, default: Date.now }
  }],
  downloadedBy: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    fileName: String,
    downloadedAt: { type: Date, default: Date.now }
  }]
}, { timestamps: true });

announcementSchema.index({ courseId: 1 });
announcementSchema.index({ 'groupIds': 1 });

module.exports = mongoose.model('Announcement', announcementSchema);