const express = require('express');
const Question = require('../models/Question');
const { authMiddleware, instructorOnly } = require('../middleware/auth');

const router = express.Router();

// Get all questions for a course
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.params;
    const { difficulty, category } = req.query;
    
    console.log(`🔍 GET /questions/course/${courseId} - Request received`);
    console.log(`🔍 Query params: difficulty=${difficulty}, category=${category}`);
    
    const mongoose = require('mongoose');
    const filter = { courseId: new mongoose.Types.ObjectId(courseId) };
    if (difficulty) filter.difficulty = difficulty;
    if (category) filter.category = category;
    
    console.log(`🔍 MongoDB filter:`, filter);
    
    const questions = await Question.find(filter)
      .populate('createdBy', 'firstName lastName username email')
      .sort({ createdAt: -1 });
    
    console.log(`📊 Raw questions found: ${questions.length}`);
    
    if (questions.length > 0) {
      console.log(`📝 First question sample:`, {
        id: questions[0]._id,
        questionText: questions[0].questionText.substring(0, 50),
        courseId: questions[0].courseId,
        createdBy: questions[0].createdBy
      });
    }
    
    // Transform for frontend compatibility
    const transformedQuestions = questions.map(q => {
      try {
        const transformed = {
          ...q.toObject(),
          id: q._id.toString(),
          createdBy: q.createdBy ? q.createdBy._id.toString() : q.createdBy,
          courseId: q.courseId.toString()
        };
        return transformed;
      } catch (transformError) {
        console.error(`❌ Error transforming question ${q._id}:`, transformError);
        return null;
      }
    }).filter(q => q !== null);
    
    console.log(`✅ Transformed questions: ${transformedQuestions.length}`);
    console.log(`📤 Sending response with ${transformedQuestions.length} questions`);
    
    res.json(transformedQuestions);
  } catch (error) {
    console.error('❌ Error fetching questions:', error);
    console.error('❌ Error stack:', error.stack);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get single question
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const question = await Question.findById(req.params.id)
      .populate('createdBy', 'name email');
    
    if (!question) {
      return res.status(404).json({ message: 'Question not found' });
    }
    
    res.json(question);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create new question
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const questionData = {
      ...req.body,
      createdBy: req.user.userId
    };
    
    const question = new Question(questionData);
    await question.save();
    
    await question.populate('createdBy', 'name email');
    
    res.status(201).json(question);
  } catch (error) {
    res.status(400).json({ message: 'Error creating question', error: error.message });
  }
});

// Update question
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const question = await Question.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    ).populate('createdBy', 'name email');
    
    if (!question) {
      return res.status(404).json({ message: 'Question not found' });
    }
    
    res.json(question);
  } catch (error) {
    res.status(400).json({ message: 'Error updating question', error: error.message });
  }
});

// Delete question
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const question = await Question.findByIdAndDelete(req.params.id);
    
    if (!question) {
      return res.status(404).json({ message: 'Question not found' });
    }
    
    res.json({ message: 'Question deleted successfully' });
  } catch (error) {
    res.status(400).json({ message: 'Error deleting question', error: error.message });
  }
});

// Get random questions for quiz generation
router.get('/course/:courseId/random', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { courseId } = req.params;
    const { easy = 0, medium = 0, hard = 0 } = req.query;
    
    const mongoose = require('mongoose');
    const courseObjectId = new mongoose.Types.ObjectId(courseId);
    
    console.log(`🎲 Generating random questions for course ${courseId}`);
    console.log(`🎲 Requested: easy=${easy}, medium=${medium}, hard=${hard}`);
    
    // First, check available questions by difficulty
    const availableEasy = await Question.countDocuments({ courseId: courseObjectId, difficulty: 'easy' });
    const availableMedium = await Question.countDocuments({ courseId: courseObjectId, difficulty: 'medium' });
    const availableHard = await Question.countDocuments({ courseId: courseObjectId, difficulty: 'hard' });
    
    console.log(`📊 Available questions: easy=${availableEasy}, medium=${availableMedium}, hard=${availableHard}`);
    
    // Limit sample size to available questions to prevent RangeError
    const easyCount = Math.min(parseInt(easy), availableEasy);
    const mediumCount = Math.min(parseInt(medium), availableMedium);
    const hardCount = Math.min(parseInt(hard), availableHard);
    
    console.log(`✅ Adjusted counts: easy=${easyCount}, medium=${mediumCount}, hard=${hardCount}`);
    
    const allQuestions = [];
    
    // Get easy questions if requested and available
    if (easyCount > 0) {
      const easyQuestions = await Question.aggregate([
        { $match: { courseId: courseObjectId, difficulty: 'easy' } },
        { $sample: { size: easyCount } }
      ]);
      allQuestions.push(...easyQuestions);
      console.log(`🟢 Added ${easyQuestions.length} easy questions`);
    }
    
    // Get medium questions if requested and available
    if (mediumCount > 0) {
      const mediumQuestions = await Question.aggregate([
        { $match: { courseId: courseObjectId, difficulty: 'medium' } },
        { $sample: { size: mediumCount } }
      ]);
      allQuestions.push(...mediumQuestions);
      console.log(`🟡 Added ${mediumQuestions.length} medium questions`);
    }
    
    // Get hard questions if requested and available
    if (hardCount > 0) {
      const hardQuestions = await Question.aggregate([
        { $match: { courseId: courseObjectId, difficulty: 'hard' } },
        { $sample: { size: hardCount } }
      ]);
      allQuestions.push(...hardQuestions);
      console.log(`🔴 Added ${hardQuestions.length} hard questions`);
    }
    
    console.log(`🎲 Generated ${allQuestions.length} random questions total`);
    res.json(allQuestions);
  } catch (error) {
    console.error('❌ Error generating random questions:', error);
    console.error('❌ Error stack:', error.stack);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;