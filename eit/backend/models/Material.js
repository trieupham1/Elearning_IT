// models/Material.js
const mongoose = require('mongoose');

const materialSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true },
  description: String,
  // Materials are visible to ALL students in a course (no group scoping)
  files: [{
    fileName: String,
    fileUrl: String,
    fileSize: Number,
    mimeType: String
  }],
  links: [String],
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

materialSchema.index({ courseId: 1 });

module.exports = mongoose.model('Material', materialSchema);