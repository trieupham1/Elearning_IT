// models/Quiz.js
const mongoose = require('mongoose');

const quizSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true },
  description: String,
  groupIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Group' }], // Empty array = all groups
  openDate: { type: Date, required: true },
  closeDate: { type: Date, required: true },
  duration: { type: Number, required: true }, // in minutes
  maxAttempts: { type: Number, default: 1 },
  allowRetakes: { type: Boolean, default: false },
  shuffleQuestions: { type: Boolean, default: true },
  showResultsImmediately: { type: Boolean, default: false },
  questionStructure: {
    easy: { type: Number, default: 0 },
    medium: { type: Number, default: 0 },
    hard: { type: Number, default: 0 }
  },
  randomizeQuestions: { type: Boolean, default: true },
  selectedQuestions: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Question' }],
  totalPoints: { type: Number, default: 100 },
  isActive: { type: Boolean, default: true },
  status: { type: String, enum: ['draft', 'active', 'closed', 'archived'], default: 'draft' }
}, { timestamps: true });

quizSchema.index({ courseId: 1 });
quizSchema.index({ openDate: 1, closeDate: 1 });
quizSchema.index({ 'groupIds': 1 });

module.exports = mongoose.model('Quiz', quizSchema);