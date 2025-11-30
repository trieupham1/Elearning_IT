const express = require('express');
const mongoose = require('mongoose');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const Question = require('../models/Question');
const Course = require('../models/Course');
const User = require('../models/User');
const { authMiddleware, instructorOnly } = require('../middleware/auth');
const { notifyQuizAttempt, sendQuizSubmissionConfirmation } = require('../utils/notificationHelper');

const router = express.Router();

// Start a new quiz attempt
router.post('/start', authMiddleware, async (req, res) => {
  try {
    const { quizId } = req.body;
    const studentId = req.user.userId;

    // Get quiz details with populated questions
    const quiz = await Quiz.findById(quizId).populate('selectedQuestions');
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }

    // Check if quiz is available
    const now = new Date();
    if (quiz.openDate && now < quiz.openDate) {
      return res.status(400).json({ message: 'Quiz has not started yet' });
    }
    if (quiz.closeDate && now > quiz.closeDate) {
      return res.status(400).json({ message: 'Quiz has ended' });
    }

    // Check attempt limit
    const attemptCount = await QuizAttempt.getAttemptCount(quizId, studentId);
    if (quiz.maxAttempts !== -1 && attemptCount >= quiz.maxAttempts) {
      return res.status(400).json({ 
        message: `Maximum attempts (${quiz.maxAttempts}) reached` 
      });
    }

    // Check if there's an active attempt
    const activeAttempt = await QuizAttempt.findOne({
      quizId,
      studentId,
      status: 'in_progress'
    });

    if (activeAttempt) {
      // Check if it's expired and auto-submit
      await activeAttempt.autoSubmitIfExpired();
      if (activeAttempt.status === 'in_progress') {
        return res.status(400).json({ 
          message: 'You already have an active attempt', 
          attemptId: activeAttempt._id 
        });
      }
    }

    // Create questions array with snapshot of current question data
    const questions = quiz.selectedQuestions.map(question => ({
      questionId: question._id,
      questionText: question.questionText,
      choices: question.choices.map(choice => ({
        text: choice.text,
        isCorrect: choice.isCorrect
      })),
      difficulty: question.difficulty,
      selectedAnswer: [],
      isCorrect: false,
      timeSpent: 0
    }));

    // Shuffle questions if enabled
    if (quiz.randomizeQuestions) {
      for (let i = questions.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [questions[i], questions[j]] = [questions[j], questions[i]];
      }
    }

    // Create new attempt
    const newAttempt = new QuizAttempt({
      quizId,
      studentId,
      attemptNumber: attemptCount + 1,
      startTime: now,
      duration: quiz.duration,
      questions,
      totalQuestions: questions.length,
      totalPoints: quiz.totalPoints || 100,
      ipAddress: req.ip,
      userAgent: req.get('User-Agent')
    });

    await newAttempt.save();

    // Return attempt without correct answers
    const attemptResponse = {
      ...newAttempt.toObject(),
      questions: newAttempt.questions.map(q => ({
        questionId: q.questionId,
        questionText: q.questionText,
        choices: q.choices.map(choice => ({ text: choice.text })), // Remove isCorrect
        difficulty: q.difficulty,
        selectedAnswer: q.selectedAnswer,
        timeSpent: q.timeSpent
      }))
    };

    res.status(201).json(attemptResponse);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get current attempt
router.get('/:attemptId', authMiddleware, async (req, res) => {
  try {
    const { attemptId } = req.params;
    const studentId = req.user.userId;

    const attempt = await QuizAttempt.findOne({
      _id: attemptId,
      studentId
    }).populate('quizId', 'title duration');

    if (!attempt) {
      return res.status(404).json({ message: 'Attempt not found' });
    }

    // Auto-submit if expired
    await attempt.autoSubmitIfExpired();

    // Return without correct answers if still in progress
    const attemptResponse = {
      ...attempt.toObject(),
      questions: attempt.questions.map(q => ({
        questionId: q.questionId,
        questionText: q.questionText,
        choices: attempt.status === 'in_progress' 
          ? q.choices.map(choice => ({ text: choice.text }))
          : q.choices, // Show correct answers after submission
        difficulty: q.difficulty,
        selectedAnswer: q.selectedAnswer,
        isCorrect: q.isCorrect,
        timeSpent: q.timeSpent
      }))
    };

    res.json(attemptResponse);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update question answer
router.put('/:attemptId/answer', authMiddleware, async (req, res) => {
  try {
    const { attemptId } = req.params;
    const { questionId, selectedAnswer, timeSpent } = req.body;
    const studentId = req.user.userId;

    const attempt = await QuizAttempt.findOne({
      _id: attemptId,
      studentId,
      status: 'in_progress'
    });

    if (!attempt) {
      return res.status(404).json({ message: 'Active attempt not found' });
    }

    // Check if expired
    if (attempt.isExpired()) {
      await attempt.autoSubmitIfExpired();
      return res.status(400).json({ message: 'Attempt has expired' });
    }

    // Find and update the question
    const questionIndex = attempt.questions.findIndex(
      q => q.questionId.toString() === questionId
    );

    if (questionIndex === -1) {
      return res.status(404).json({ message: 'Question not found in attempt' });
    }

    const question = attempt.questions[questionIndex];
    question.selectedAnswer = Array.isArray(selectedAnswer) ? selectedAnswer : [selectedAnswer];
    question.timeSpent = timeSpent || 0;

    // Check if answer is correct
    const correctChoices = question.choices
      .filter(choice => choice.isCorrect)
      .map(choice => choice.text);
    
    question.isCorrect = correctChoices.length === question.selectedAnswer.length &&
      correctChoices.every(correct => question.selectedAnswer.includes(correct));

    await attempt.save();

    res.json({ 
      message: 'Answer saved',
      questionId,
      selectedAnswer: question.selectedAnswer,
      timeSpent: question.timeSpent
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get student's quiz attempt status for a specific quiz
router.get('/quiz/:quizId/student', authMiddleware, async (req, res) => {
  try {
    const { quizId } = req.params;
    const studentId = req.user.userId;

    console.log(`🎯 Getting student attempt status for quiz: ${quizId}, student: ${studentId}`);

    // Validate ObjectIds
    if (!mongoose.Types.ObjectId.isValid(quizId)) {
      console.log('❌ Invalid quizId format:', quizId);
      return res.status(400).json({ message: 'Invalid quiz ID format' });
    }

    if (!mongoose.Types.ObjectId.isValid(studentId)) {
      console.log('❌ Invalid studentId format:', studentId);
      return res.status(400).json({ message: 'Invalid student ID format' });
    }

    // Get quiz details to check retake settings
    const quiz = await Quiz.findById(quizId);
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }

    console.log(`📋 Quiz settings: allowRetakes=${quiz.allowRetakes}, maxAttempts=${quiz.maxAttempts}`);

    // Get all attempts for this student and quiz
    const allAttempts = await QuizAttempt.find({
      quizId: new mongoose.Types.ObjectId(quizId),
      studentId: new mongoose.Types.ObjectId(studentId)
    }).sort({ attemptNumber: -1 });

    console.log(`📊 Total attempts found for student: ${allAttempts.length}`);
    allAttempts.forEach((att, index) => {
      console.log(`   Attempt ${index + 1}: ${att._id}, status: ${att.status}, score: ${att.score || 0}, number: ${att.attemptNumber}`);
    });

    // Check if student has any completed attempts
    const completedAttempts = allAttempts.filter(att => 
      ['submitted', 'auto_submitted', 'completed'].includes(att.status)
    );

    if (completedAttempts.length === 0) {
      console.log('ℹ️ No completed attempts found for student');
      return res.status(404).json({ message: 'No completed attempt found' });
    }

    // Get the latest completed attempt
    const latestAttempt = completedAttempts[0]; // Already sorted by attemptNumber desc

    console.log(`✅ Found latest completed attempt: ${latestAttempt._id}`);
    console.log(`   Attempt Number: ${latestAttempt.attemptNumber}`);
    console.log(`   Score: ${latestAttempt.pointsEarned || latestAttempt.score}/${latestAttempt.totalPoints}`);
    console.log(`   Status: ${latestAttempt.status}`);

    // Check if student can retake based on quiz settings
    const canRetake = quiz.allowRetakes && 
                     (quiz.maxAttempts === -1 || completedAttempts.length < quiz.maxAttempts);

    console.log(`🔄 Can student retake? ${canRetake} (allowRetakes=${quiz.allowRetakes}, completed=${completedAttempts.length}, max=${quiz.maxAttempts})`);

    // Return attempt data with proper formatting
    const response = {
      _id: latestAttempt._id,
      quizId: latestAttempt.quizId,
      studentId: latestAttempt.studentId,
      attemptNumber: latestAttempt.attemptNumber,
      totalAttempts: completedAttempts.length,
      score: latestAttempt.pointsEarned || latestAttempt.score,
      maxScore: latestAttempt.totalPoints,
      grade: latestAttempt.score, // This is the percentage score (0-100)
      state: 'Finished',
      submittedAt: latestAttempt.submissionTime || latestAttempt.endTime,
      status: latestAttempt.status,
      correctAnswers: latestAttempt.correctAnswers,
      totalQuestions: latestAttempt.totalQuestions,
      timeSpent: latestAttempt.timeSpent,
      canRetake: canRetake,
      // Quiz settings for frontend logic
      quiz: {
        allowRetakes: quiz.allowRetakes,
        maxAttempts: quiz.maxAttempts
      }
    };

    console.log(`📤 Sending response with canRetake=${canRetake}:`, response);
    res.json(response);
  } catch (error) {
    console.error('❌ Error getting student quiz attempt:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Submit quiz attempt
router.post('/:attemptId/submit', authMiddleware, async (req, res) => {
  try {
    const { attemptId } = req.params;
    const studentId = req.user.userId;

    // Find attempt regardless of status so we can gracefully handle already-submitted/auto-submitted cases
    let attempt = await QuizAttempt.findOne({
      _id: attemptId,
      studentId
    });

    if (!attempt) {
      return res.status(404).json({ message: 'Attempt not found' });
    }

    // If still in progress, submit it now (and handle expiration)
    if (attempt.status === 'in_progress') {
      // Auto-submit if expired
      if (attempt.isExpired()) {
        await attempt.autoSubmitIfExpired();
      } else {
        const now = new Date();
        attempt.endTime = now;
        attempt.submissionTime = now;
        attempt.timeSpent = Math.floor((now - attempt.startTime) / 1000); // in seconds
        attempt.status = 'submitted';
        await attempt.save(); // triggers pre-save hook to calculate score
      }

      // Fire-and-forget notification (do not block response)
      (async () => {
        try {
          const [student, quiz] = await Promise.all([
            User.findById(studentId),
            attempt.populate('quizId')
          ]);

          if (quiz && quiz.quizId && quiz.quizId.courseId) {
            const course = await Course.findById(quiz.quizId.courseId).populate('instructor');
            if (course && course.instructor && student) {
              const studentName = student.fullName || student.username || student.email || 'Unknown';
              const scorePercentage = attempt.score ? attempt.score.toFixed(1) : '0';
              
              // Notify instructor
              const courseName = course.name || course.title || 'Course';
              await notifyQuizAttempt(
                course.instructor._id,
                courseName,
                quiz.quizId.title,
                studentName,
                `${scorePercentage}%`,
                attempt._id.toString()
              );
              console.log(`📬 Notification sent to instructor ${course.instructor.username} for quiz attempt`);
              
              // Send confirmation email to student
              await sendQuizSubmissionConfirmation(
                studentId,
                quiz.quizId.toObject(),
                {
                  attemptNumber: attempt.attemptNumber,
                  submittedAt: attempt.submissionTime,
                  score: scorePercentage
                },
                courseName
              );
              console.log(`📧 Confirmation email sent to student ${studentName}`);
            }
          }
        } catch (notifError) {
          console.error('Error sending quiz attempt notification:', notifError);
        }
      })();
    }

    // Return full results including correct answers (works for submitted/auto_submitted/completed)
    const result = {
      ...attempt.toObject(),
      questions: attempt.questions.map(q => ({
        questionId: q.questionId,
        questionText: q.questionText,
        choices: q.choices,
        difficulty: q.difficulty,
        selectedAnswer: q.selectedAnswer,
        isCorrect: q.isCorrect,
        timeSpent: q.timeSpent
      }))
    };

    return res.json(result);
  } catch (error) {
    return res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all student's attempts for a quiz with detailed results
router.get('/quiz/:quizId/student/all', authMiddleware, async (req, res) => {
  try {
    const { quizId } = req.params;
    const studentId = req.user.userId;

    console.log(`📊 Getting ALL attempts for quiz: ${quizId}, student: ${studentId}`);

    // Validate ObjectIds
    if (!mongoose.Types.ObjectId.isValid(quizId)) {
      return res.status(400).json({ message: 'Invalid quiz ID format' });
    }

    if (!mongoose.Types.ObjectId.isValid(studentId)) {
      return res.status(400).json({ message: 'Invalid student ID format' });
    }

    // Get quiz details
    const quiz = await Quiz.findById(quizId);
    if (!quiz) {
      return res.status(404).json({ message: 'Quiz not found' });
    }

    // Get all completed attempts for this student and quiz
    const attempts = await QuizAttempt.find({
      quizId: new mongoose.Types.ObjectId(quizId),
      studentId: new mongoose.Types.ObjectId(studentId),
      status: { $in: ['submitted', 'auto_submitted', 'completed'] }
    }).sort({ attemptNumber: 1 }); // Sort by attempt number ascending (1st, 2nd, 3rd...)

    console.log(`📋 Found ${attempts.length} completed attempts for student`);

    // Format all attempts for display
    const formattedAttempts = attempts.map((attempt, index) => {
      const grade = attempt.totalPoints > 0 ? (attempt.pointsEarned / attempt.totalPoints * 10) : 0;
      
      return {
        _id: attempt._id,
        attemptNumber: attempt.attemptNumber,
        score: attempt.pointsEarned || attempt.score,
        maxScore: attempt.totalPoints,
        grade: grade,
        percentageScore: attempt.score, // This is 0-100 percentage
        state: 'Finished',
        submittedAt: attempt.submissionTime || attempt.endTime,
        status: attempt.status,
        correctAnswers: attempt.correctAnswers,
        totalQuestions: attempt.totalQuestions,
        timeSpent: attempt.timeSpent,
        isLatest: index === attempts.length - 1 // Mark the latest attempt
      };
    });

    // Calculate final grade (usually the highest or latest, depending on quiz settings)
    const finalGrade = formattedAttempts.length > 0 
      ? Math.max(...formattedAttempts.map(a => a.grade))
      : 0;

    const response = {
      quiz: {
        title: quiz.title,
        allowRetakes: quiz.allowRetakes,
        maxAttempts: quiz.maxAttempts
      },
      totalAttempts: formattedAttempts.length,
      finalGrade: finalGrade,
      attempts: formattedAttempts,
      canRetake: quiz.allowRetakes && 
                (quiz.maxAttempts === -1 || formattedAttempts.length < quiz.maxAttempts)
    };

    console.log(`📤 Sending ${formattedAttempts.length} attempts with final grade: ${finalGrade}`);
    res.json(response);
  } catch (error) {
    console.error('❌ Error getting all student attempts:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all attempts for a quiz (instructor only)
router.get('/quiz/:quizId/all', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { quizId } = req.params;

    const attempts = await QuizAttempt.find({ quizId })
      .populate('studentId', 'firstName lastName username email')
      .populate('quizId', 'title')
      .sort({ submissionTime: -1, studentId: 1, attemptNumber: -1 });

    // Get quiz to find all enrolled students
    const quiz = await Quiz.findById(quizId).populate('courseId');
    
    // Group attempts by student and get their best/latest attempt
    const studentAttempts = new Map();
    
    attempts.forEach(attempt => {
      // Skip attempts with null/missing studentId
      if (!attempt.studentId || !attempt.studentId._id) {
        console.warn('⚠️ Skipping attempt with missing studentId:', attempt._id);
        return;
      }
      const studentId = attempt.studentId._id.toString();
      if (!studentAttempts.has(studentId)) {
        studentAttempts.set(studentId, []);
      }
      studentAttempts.get(studentId).push(attempt);
    });

    // For each student, get their best attempt (highest score) or latest if scores are equal
    const bestAttempts = [];
    studentAttempts.forEach((studentAttemptList, studentId) => {
      // Sort by score (desc) then by attempt number (desc)
      studentAttemptList.sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return b.attemptNumber - a.attemptNumber;
      });
      
      const bestAttempt = studentAttemptList[0];
      // Add total attempts count for this student
      bestAttempt.totalStudentAttempts = studentAttemptList.length;
      bestAttempts.push(bestAttempt);
    });

    // Create summary with completion status
    const summary = {
      quiz: quiz.title,
      totalAttempts: attempts.length,
      uniqueStudents: [...new Set(attempts.filter(a => a.studentId && a.studentId._id).map(a => a.studentId._id.toString()))].length,
      completedAttempts: attempts.filter(a => ['submitted', 'auto_submitted'].includes(a.status)).length,
      averageScore: attempts.length > 0 
        ? Math.round(attempts.reduce((sum, a) => sum + a.score, 0) / attempts.length)
        : 0,
      attempts: bestAttempts, // Show only best attempts (one per student)
      allAttempts: attempts.filter(a => a.studentId) // Keep all attempts with valid studentId for detailed view
    };

    res.json(summary);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all attempts for a specific student on a specific quiz (instructor only)
router.get('/student/:studentId/quiz/:quizId', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { studentId, quizId } = req.params;
    
    console.log('📋 Getting all attempts for student:', studentId, 'quiz:', quizId);
    
    const attempts = await QuizAttempt.find({
      studentId: studentId,
      quizId: quizId
    })
    .populate('studentId', 'firstName lastName username email')
    .populate('quizId', 'title description')
    .sort({ attemptNumber: 1 });
    
    console.log('📋 Found attempts:', attempts.length);
    
    const formattedAttempts = attempts.map(attempt => ({
      _id: attempt._id,
      attemptNumber: attempt.attemptNumber,
      score: attempt.score,
      correctAnswers: attempt.correctAnswers,
      totalQuestions: attempt.totalQuestions,
      timeSpent: attempt.timeSpent,
      submissionTime: attempt.submissionTime,
      status: attempt.status,
      pointsEarned: attempt.pointsEarned,
      totalPoints: attempt.totalPoints,
      student: {
        name: `${attempt.studentId.firstName} ${attempt.studentId.lastName}`.trim() || attempt.studentId.username,
        email: attempt.studentId.email
      },
      quiz: {
        title: attempt.quizId.title,
        description: attempt.quizId.description
      }
    }));
    
    res.json({
      success: true,
      attempts: formattedAttempts
    });
  } catch (error) {
    console.error('❌ Error getting student attempts:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to get student attempts',
      error: error.message 
    });
  }
});

// Get detailed attempt with student's answers (instructor only)
router.get('/:attemptId/details', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { attemptId } = req.params;

    console.log(`🔍 Getting detailed attempt: ${attemptId}`);

    const attempt = await QuizAttempt.findById(attemptId)
      .populate('studentId', 'firstName lastName username email')
      .populate('quizId', 'title');

    if (!attempt) {
      return res.status(404).json({ message: 'Attempt not found' });
    }

    // Format the response with detailed question answers
    const detailedAttempt = {
      _id: attempt._id,
      student: {
        name: `${attempt.studentId.firstName} ${attempt.studentId.lastName}`.trim() || attempt.studentId.username,
        email: attempt.studentId.email
      },
      quiz: {
        title: attempt.quizId.title
      },
      attemptNumber: attempt.attemptNumber,
      startTime: attempt.startTime,
      endTime: attempt.endTime,
      submissionTime: attempt.submissionTime,
      timeSpent: attempt.timeSpent,
      status: attempt.status,
      score: attempt.score,
      pointsEarned: attempt.pointsEarned,
      totalPoints: attempt.totalPoints,
      correctAnswers: attempt.correctAnswers,
      totalQuestions: attempt.totalQuestions,
      
      // Detailed question answers
      questions: attempt.questions.map((q, index) => ({
        questionNumber: index + 1,
        questionText: q.questionText,
        difficulty: q.difficulty,
        choices: q.choices.map(choice => ({
          text: choice.text,
          isCorrect: choice.isCorrect
        })),
        studentAnswer: q.selectedAnswer,
        correctAnswer: q.choices.filter(choice => choice.isCorrect).map(choice => choice.text),
        isCorrect: q.isCorrect,
        timeSpent: q.timeSpent
      }))
    };

    console.log(`✅ Returning detailed attempt with ${detailedAttempt.questions.length} questions`);
    res.json(detailedAttempt);
  } catch (error) {
    console.error('❌ Error getting detailed attempt:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Auto-submit expired attempts (cleanup job)
router.post('/cleanup-expired', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const expiredAttempts = await QuizAttempt.find({ status: 'in_progress' });
    
    let submittedCount = 0;
    for (const attempt of expiredAttempts) {
      const wasExpired = attempt.isExpired();
      await attempt.autoSubmitIfExpired();
      if (wasExpired) submittedCount++;
    }

    res.json({ 
      message: `Cleaned up ${submittedCount} expired attempts`,
      submittedCount 
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;