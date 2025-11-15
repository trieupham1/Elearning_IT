// models/Question.js
const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  questionText: { type: String, required: true },
  choices: [{
    text: String,
    isCorrect: Boolean
  }],
  difficulty: { type: String, enum: ['easy', 'medium', 'hard'], required: true },
  explanation: String,
  category: { type: String, default: '' },
  tags: [{ type: String }]
}, { timestamps: true });

questionSchema.index({ courseId: 1, difficulty: 1 });

module.exports = mongoose.model('Question', questionSchema);