// models/Assignment.js
const mongoose = require('mongoose');

const assignmentSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  createdByName: { type: String, required: true }, // Store creator name to avoid validation issues
  title: { type: String, required: true },
  description: String,
  
  // Assignment type: 'file' for traditional file uploads, 'code' for coding assignments
  type: {
    type: String,
    enum: ['file', 'code'],
    default: 'file'
  },
  
  groupIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Group' }], // Empty array = all groups
  startDate: { type: Date, required: true },
  deadline: { type: Date, required: true },
  allowLateSubmission: { type: Boolean, default: false },
  lateDeadline: Date,
  maxAttempts: { type: Number, default: 1 },
  allowedFileTypes: [String], // e.g., ['.pdf', '.docx', '.jpg']
  maxFileSize: { type: Number, default: 10485760 }, // in bytes, default 10MB
  attachments: [{
    fileName: String,
    fileUrl: String,
    fileSize: Number,
    mimeType: String
  }],
  points: { type: Number, default: 100 },
  
  // Code assignment specific fields
  codeConfig: {
    language: {
      type: String,
      enum: ['python', 'java', 'cpp', 'javascript', 'c']
    },
    languageId: Number, // Judge0 language ID
    starterCode: String,
    solutionCode: String, // Hidden from students
    allowedLanguages: [{
      type: String,
      enum: ['python', 'java', 'cpp', 'javascript', 'c']
    }],
    timeLimit: {
      type: Number,
      default: 5000 // milliseconds
    },
    memoryLimit: {
      type: Number,
      default: 128000 // KB
    },
    showTestCases: {
      type: Boolean,
      default: true // Show visible test cases to students
    }
  },
  
  // Track who has viewed this assignment
  viewedBy: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    viewedAt: { type: Date, default: Date.now }
  }]
}, { timestamps: true });

assignmentSchema.index({ courseId: 1 });
assignmentSchema.index({ deadline: 1 });
assignmentSchema.index({ 'groupIds': 1 });

module.exports = mongoose.model('Assignment', assignmentSchema);