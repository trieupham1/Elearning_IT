const mongoose = require('mongoose');

const codeAssignmentSchema = new mongoose.Schema({
  courseId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Course',
    required: true,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    default: ''
  },
  language: {
    type: String,
    required: true,
    enum: ['python', 'java', 'cpp', 'javascript', 'c']
  },
  languageId: {
    type: Number,
    required: true
    // Judge0 language IDs: Python=71, Java=62, C++=54, JavaScript=63, C=50
  },
  starterCode: {
    type: String,
    default: ''
  },
  dueDate: {
    type: Date,
    required: true
  },
  points: {
    type: Number,
    default: 100
  },
  difficulty: {
    type: String,
    enum: ['easy', 'medium', 'hard'],
    default: 'medium'
  },
  timeLimit: {
    type: Number,
    default: 5000, // milliseconds
  },
  memoryLimit: {
    type: Number,
    default: 256000, // KB
  },
  testCases: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'TestCase'
  }],
  hints: [{
    type: String
  }],
  isActive: {
    type: Boolean,
    default: true
  },
  allowedAttempts: {
    type: Number,
    default: -1 // -1 means unlimited
  },
  showTestCases: {
    type: Boolean,
    default: false // Whether students can see test case details
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Update the updatedAt timestamp on save
codeAssignmentSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Index for efficient queries
codeAssignmentSchema.index({ courseId: 1, dueDate: -1 });
codeAssignmentSchema.index({ createdBy: 1 });

const CodeAssignment = mongoose.model('CodeAssignment', codeAssignmentSchema);

module.exports = CodeAssignment;
