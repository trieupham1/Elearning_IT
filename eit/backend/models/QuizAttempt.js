// models/QuizAttempt.js
const mongoose = require('mongoose');

const quizAttemptSchema = new mongoose.Schema({
  quizId: { type: mongoose.Schema.Types.ObjectId, ref: 'Quiz', required: true },
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  attemptNumber: { type: Number, required: true }, // 1, 2, 3, etc.
  startTime: { type: Date, required: true },
  endTime: { type: Date }, // null if still in progress
  submissionTime: { type: Date }, // when student clicked submit
  timeSpent: { type: Number, default: 0 }, // in seconds
  duration: { type: Number, required: true }, // quiz duration in minutes
  
  // Question and answer tracking
  questions: [{
    questionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Question', required: true },
    questionText: String, // store snapshot in case question changes later
    choices: [{
      text: String,
      isCorrect: Boolean
    }],
    difficulty: { type: String, enum: ['easy', 'medium', 'hard'] },
    selectedAnswer: [String], // array to support multiple choice
    isCorrect: { type: Boolean, default: false },
    timeSpent: { type: Number, default: 0 } // time spent on this question in seconds
  }],
  
  // Scoring
  totalQuestions: { type: Number, required: true },
  correctAnswers: { type: Number, default: 0 },
  score: { type: Number, default: 0 }, // percentage score
  pointsEarned: { type: Number, default: 0 },
  totalPoints: { type: Number, required: true },
  
  // Status tracking
  status: { 
    type: String, 
    enum: ['in_progress', 'completed', 'submitted', 'auto_submitted', 'expired'], 
    default: 'in_progress' 
  },
  
  // Metadata
  ipAddress: String,
  userAgent: String,
  
}, { timestamps: true });

// Indexes for efficient queries
quizAttemptSchema.index({ quizId: 1, studentId: 1 });
quizAttemptSchema.index({ quizId: 1, status: 1 });
quizAttemptSchema.index({ studentId: 1, status: 1 });
quizAttemptSchema.index({ submissionTime: 1 });

// Calculate score before saving
quizAttemptSchema.pre('save', function(next) {
  if (this.questions && this.questions.length > 0) {
    this.correctAnswers = this.questions.filter(q => q.isCorrect).length;
    this.totalQuestions = this.questions.length;
    this.score = this.totalQuestions > 0 ? Math.round((this.correctAnswers / this.totalQuestions) * 100) : 0;
    
    // Calculate points (assuming each question is worth equal points)
    const pointsPerQuestion = this.totalPoints / this.totalQuestions;
    this.pointsEarned = Math.round(this.correctAnswers * pointsPerQuestion);
  }
  next();
});

// Static method to get attempt count for a student
quizAttemptSchema.statics.getAttemptCount = function(quizId, studentId) {
  return this.countDocuments({ quizId, studentId });
};

// Static method to get latest attempt
quizAttemptSchema.statics.getLatestAttempt = function(quizId, studentId) {
  return this.findOne({ quizId, studentId }).sort({ attemptNumber: -1 });
};

// Instance method to check if attempt is still valid
quizAttemptSchema.methods.isExpired = function() {
  if (this.status !== 'in_progress') return false;
  
  const now = new Date();
  const maxEndTime = new Date(this.startTime.getTime() + (this.duration * 60 * 1000));
  return now > maxEndTime;
};

// Instance method to auto-submit expired attempts
quizAttemptSchema.methods.autoSubmitIfExpired = function() {
  if (this.isExpired() && this.status === 'in_progress') {
    this.status = 'auto_submitted';
    this.endTime = new Date(this.startTime.getTime() + (this.duration * 60 * 1000));
    this.timeSpent = this.duration * 60; // full duration
    return this.save();
  }
  return Promise.resolve(this);
};

module.exports = mongoose.model('QuizAttempt', quizAttemptSchema);