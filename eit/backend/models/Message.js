// models/Message.js
const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  receiverId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, required: true },
  fileId: { type: String }, // Add fileId field for GridFS file references
  attachments: [{
    fileName: String,
    fileUrl: String,
    fileSize: Number,
    mimeType: String
  }],
  isRead: { type: Boolean, default: false },
  readAt: Date,
  // Call history fields
  messageType: { 
    type: String, 
    enum: ['text', 'audio_call', 'video_call'], 
    default: 'text' 
  },
  callDuration: { type: Number }, // Duration in seconds
  callStatus: { 
    type: String, 
    enum: ['completed', 'missed', 'rejected', 'no_answer'], 
    default: 'completed' 
  }
}, { timestamps: true });

messageSchema.index({ senderId: 1, receiverId: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);