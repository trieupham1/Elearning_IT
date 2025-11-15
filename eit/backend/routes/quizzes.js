const express = require('express');
const Quiz = require('../models/Quiz');
const Question = require('../models/Question');
const Course = require('../models/Course');
const { authMiddleware, instructorOnly } = require('../middleware/auth');
const { notifyNewQuiz } = require('../utils/notificationHelper');

const router = express.Router();

// Get all quizzes for a course
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.params;
    const quizzes = await Quiz.find({ courseId })
      .populate('createdBy', 'name email')
      .sort({ closeDate: -1 });
    
    res.json(quizzes);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get single quiz
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const quiz = await Quiz.findById(req.params.id)
      .populate('createdBy', 'name email')
      .populate('selectedQuestions');
    
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }
    
    res.json(quiz);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create new quiz
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const quizData = {
      ...req.body,
      createdBy: req.user.userId
    };
    
    const quiz = new Quiz(quizData);
    await quiz.save();
    
    await quiz.populate('createdBy', 'name email');
    
    // Send notifications to all enrolled students
    try {
      const course = await Course.findById(quiz.courseId);
      if (course && course.students && course.students.length > 0) {
        const studentIds = course.students.map(s => s.toString());
        // Pass the full quiz object for email notifications
        await notifyNewQuiz(
          quiz.courseId.toString(),
          course.title || course.name || 'Course',
          quiz.title,
          studentIds,
          quiz.toObject() // Pass full quiz data for emails
        );
        console.log(`📬 Sent quiz notifications to ${studentIds.length} students for "${quiz.title}" in ${course.title || course.name}`);
      }
    } catch (notifError) {
      console.error('Error sending quiz notifications:', notifError);
      // Don't fail the quiz creation if notification fails
    }
    
    res.status(201).json(quiz);
  } catch (error) {
    res.status(400).json({ message: 'Error creating quiz', error: error.message });
  }
});

// Update quiz
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const quiz = await Quiz.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    ).populate('createdBy', 'name email');
    
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }
    
    res.json(quiz);
  } catch (error) {
    res.status(400).json({ message: 'Error updating quiz', error: error.message });
  }
});

// Update quiz settings
router.put('/:id/settings', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Check if quiz is currently active with students taking it
    const QuizAttempt = require('../models/QuizAttempt');
    const activeAttempts = await QuizAttempt.countDocuments({ 
      quizId: id, 
      status: 'in_progress' 
    });

    if (activeAttempts > 0) {
      // Only allow certain updates if there are active attempts
      const allowedFields = ['closeDate', 'isActive', 'status'];
      const restrictedFields = Object.keys(updateData).filter(key => !allowedFields.includes(key));
      
      if (restrictedFields.length > 0) {
        return res.status(400).json({ 
          message: `Cannot modify ${restrictedFields.join(', ')} while students are taking the quiz`,
          activeAttempts 
        });
      }
    }

    // Auto-close quiz if closeDate has passed
    if (updateData.closeDate) {
      const closeDate = new Date(updateData.closeDate);
      if (closeDate <= new Date()) {
        updateData.status = 'closed';
        updateData.isActive = false;
      }
    }

    const quiz = await Quiz.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    ).populate('createdBy', 'firstName lastName username email');
    
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }
    
    console.log('✅ Quiz settings updated:', quiz.title);
    res.json(quiz);
  } catch (error) {
    console.error('❌ Error updating quiz settings:', error);
    res.status(400).json({ message: 'Error updating quiz settings', error: error.message });
  }
});

// Delete quiz
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const quiz = await Quiz.findByIdAndDelete(req.params.id);
    
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }
    
    res.json({ message: 'Quiz deleted successfully' });
  } catch (error) {
    res.status(400).json({ message: 'Error deleting quiz', error: error.message });
  }
});

// Get quiz results (instructor only)
router.get('/:id/results', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const quiz = await Quiz.findById(req.params.id)
      .populate('createdBy', 'name email');
    
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }
    
    // TODO: Implement quiz attempts and results aggregation
    // For now, return basic quiz info
    res.json({
      quiz,
      attempts: [],
      statistics: {
        totalStudents: 0,
        attempted: 0,
        completed: 0,
        averageScore: 0
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Auto-close expired quizzes
router.post('/auto-close', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const now = new Date();
    
    // Find quizzes that should be closed
    const expiredQuizzes = await Quiz.find({
      closeDate: { $lte: now },
      status: { $in: ['active', 'draft'] },
      isActive: true
    });

    if (expiredQuizzes.length === 0) {
      return res.json({ message: 'No expired quizzes found', closed: 0 });
    }

    // Auto-submit any in-progress attempts for expired quizzes
    const QuizAttempt = require('../models/QuizAttempt');
    for (const quiz of expiredQuizzes) {
      await QuizAttempt.updateMany(
        { quizId: quiz._id, status: 'in_progress' },
        { 
          status: 'auto_submitted',
          endTime: now,
          submissionTime: now
        }
      );
    }

    // Update quiz status
    const result = await Quiz.updateMany(
      { _id: { $in: expiredQuizzes.map(q => q._id) } },
      { 
        status: 'closed',
        isActive: false
      }
    );

    console.log(`🔒 Auto-closed ${result.modifiedCount} expired quizzes`);
    res.json({ 
      message: `Auto-closed ${result.modifiedCount} expired quizzes`,
      closed: result.modifiedCount,
      quizzes: expiredQuizzes.map(q => ({ id: q._id, title: q.title }))
    });
  } catch (error) {
    console.error('❌ Error auto-closing quizzes:', error);
    res.status(500).json({ message: 'Error auto-closing quizzes', error: error.message });
  }
});

// Export quiz results as CSV
router.get('/:id/export', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get quiz details
    const quiz = await Quiz.findById(id).populate('createdBy', 'firstName lastName username email');
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }

    // Get all quiz attempts with student data
    const QuizAttempt = require('../models/QuizAttempt');
    const attempts = await QuizAttempt.find({ quizId: id })
      .populate('studentId', 'firstName lastName username email')
      .sort({ submissionTime: -1, studentId: 1, attemptNumber: -1 });

    // Prepare CSV data
    const csvRows = [];
    
    // CSV Header
    csvRows.push([
      'Student Name',
      'Email',
      'Username',
      'Attempt Number',
      'Start Time',
      'End Time',
      'Time Spent (minutes)',
      'Score (%)',
      'Points Earned',
      'Total Points',
      'Correct Answers',
      'Total Questions',
      'Status',
      'Submission Time'
    ].join(','));

    // CSV Data rows
    for (const attempt of attempts) {
      const student = attempt.studentId;
      const studentName = student ? 
        (student.firstName && student.lastName ? 
          `${student.firstName} ${student.lastName}` : 
          student.username || 'Unknown Student') : 
        'Unknown Student';
      
      const email = student?.email || '';
      const username = student?.username || '';
      const timeSpentMinutes = Math.round(attempt.timeSpent / 60);
      
      const row = [
        `"${studentName}"`,
        `"${email}"`,
        `"${username}"`,
        attempt.attemptNumber,
        attempt.startTime ? new Date(attempt.startTime).toLocaleString() : '',
        attempt.endTime ? new Date(attempt.endTime).toLocaleString() : '',
        timeSpentMinutes,
        attempt.score,
        attempt.pointsEarned,
        attempt.totalPoints,
        attempt.correctAnswers,
        attempt.totalQuestions,
        `"${attempt.status}"`,
        attempt.submissionTime ? new Date(attempt.submissionTime).toLocaleString() : ''
      ].join(',');
      
      csvRows.push(row);
    }

    const csvContent = csvRows.join('\n');
    const filename = `${quiz.title.replace(/[^a-zA-Z0-9]/g, '_')}_results_${new Date().toISOString().split('T')[0]}.csv`;

    // Set headers for CSV download
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', Buffer.byteLength(csvContent));

    console.log(`📊 Exported ${attempts.length} quiz attempts for quiz: ${quiz.title}`);
    res.send(csvContent);
  } catch (error) {
    console.error('❌ Error exporting quiz results:', error);
    res.status(500).json({ message: 'Error exporting quiz results', error: error.message });
  }
});

module.exports = router;