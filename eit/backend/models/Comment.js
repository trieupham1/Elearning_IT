// models/Comment.js
const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  announcementId: { type: mongoose.Schema.Types.ObjectId, ref: 'Announcement', required: true },
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, required: true }
}, { timestamps: true });

commentSchema.index({ announcementId: 1 });

module.exports = mongoose.model('Comment', commentSchema);