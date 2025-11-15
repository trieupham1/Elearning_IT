// models/ForumReply.js
const mongoose = require('mongoose');

const forumReplySchema = new mongoose.Schema({
  topicId: { type: mongoose.Schema.Types.ObjectId, ref: 'ForumTopic', required: true },
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  authorName: { type: String, required: true },
  authorRole: { type: String, enum: ['student', 'instructor'], required: true },
  content: { type: String, required: true },
  parentReplyId: { type: mongoose.Schema.Types.ObjectId, ref: 'ForumReply' },
  attachments: [{
    fileName: String,
    fileUrl: String,
    fileSize: Number,
    mimeType: String
  }],
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  isEdited: { type: Boolean, default: false },
  editedAt: Date
}, { 
  timestamps: true,
  toJSON: {
    transform: function(doc, ret) {
      ret.id = ret._id.toString();
      return ret;
    }
  }
});

forumReplySchema.index({ topicId: 1, createdAt: 1 });
forumReplySchema.index({ parentReplyId: 1 });

module.exports = mongoose.model('ForumReply', forumReplySchema);