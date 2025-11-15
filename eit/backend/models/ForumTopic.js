// models/ForumTopic.js
const mongoose = require('mongoose');

const forumTopicSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  authorName: { type: String, required: true },
  authorRole: { type: String, enum: ['student', 'instructor'], required: true },
  title: { type: String, required: true },
  content: String,
  attachments: [{
    fileName: String,
    fileUrl: String,
    fileSize: Number,
    mimeType: String
  }],
  isPinned: { type: Boolean, default: false },
  isLocked: { type: Boolean, default: false },
  views: { type: Number, default: 0 },
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  replyCount: { type: Number, default: 0 },
  lastActivityAt: { type: Date, default: Date.now },
  tags: [String]
}, { 
  timestamps: true,
  toJSON: {
    transform: function(doc, ret) {
      ret.id = ret._id.toString();
      return ret;
    }
  }
});

// Indexes for performance
forumTopicSchema.index({ courseId: 1, isPinned: -1, lastActivityAt: -1 });
forumTopicSchema.index({ title: 'text', content: 'text', tags: 'text' });

module.exports = mongoose.model('ForumTopic', forumTopicSchema);