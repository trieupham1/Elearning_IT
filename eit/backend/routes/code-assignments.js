const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Assignment = require('../models/Assignment');
const CodeSubmission = require('../models/CodeSubmission');
const TestCase = require('../models/TestCase');
const Course = require('../models/Course');
const { executeCode, executeWithTestCases, LANGUAGE_IDS } = require('../utils/judge0Helper');
const { notifyNewAssignment } = require('../utils/notificationHelper');

// Create code assignment with test cases
router.post('/assignments', auth, async (req, res) => {
  try {
    const {
      courseId,
      title,
      description,
      groupIds,
      startDate,
      deadline,
      allowLateSubmission,
      lateDeadline,
      maxAttempts,
      points,
      language,
      starterCode,
      solutionCode,
      allowedLanguages,
      timeLimit,
      memoryLimit,
      showTestCases,
      testCases
    } = req.body;

    // Verify user is instructor of the course
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Only course instructor can create assignments' });
    }

    // Get instructor's full name
    const User = require('../models/User');
    const instructor = await User.findById(req.user.userId);
    if (!instructor) {
      return res.status(404).json({ message: 'Instructor not found' });
    }

    // Create code assignment
    const assignment = new Assignment({
      courseId,
      createdBy: req.user.userId,
      createdByName: instructor.fullName,
      title,
      description,
      type: 'code',
      groupIds: groupIds || [],
      startDate,
      deadline,
      allowLateSubmission: allowLateSubmission || false,
      lateDeadline,
      maxAttempts: maxAttempts || 999, // Allow unlimited attempts for code assignments
      points: points || 100,
      codeConfig: {
        language,
        languageId: LANGUAGE_IDS[language],
        starterCode,
        solutionCode,
        allowedLanguages: allowedLanguages || [language],
        timeLimit: timeLimit || 5000,
        memoryLimit: memoryLimit || 128000,
        showTestCases: showTestCases !== false
      }
    });

    await assignment.save();

    // Create test cases
    if (testCases && testCases.length > 0) {
      const testCaseDocuments = testCases.map((tc, index) => ({
        assignmentId: assignment._id,
        name: tc.name || `Test Case ${index + 1}`,
        description: tc.description,
        input: tc.input,
        expectedOutput: tc.expectedOutput,
        weight: tc.weight || 1,
        timeLimit: tc.timeLimit || timeLimit || 5000,
        memoryLimit: tc.memoryLimit || memoryLimit || 128000,
        isHidden: tc.isHidden || false,
        order: index
      }));

      await TestCase.insertMany(testCaseDocuments);
    }

    // Send notifications to students
    const students = course.students || [];
    if (students.length > 0) {
      await notifyNewAssignment(assignment, students);
    }

    res.status(201).json({
      message: 'Code assignment created successfully',
      assignment
    });
  } catch (error) {
    console.error('Create code assignment error:', error);
    res.status(500).json({ message: 'Failed to create code assignment', error: error.message });
  }
});

// Get assignment with test cases
router.get('/assignments/:id', auth, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id)
      .populate('courseId', 'title')
      .populate('createdBy', 'fullName email');

    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    if (assignment.type !== 'code') {
      return res.status(400).json({ message: 'Not a code assignment' });
    }

    // Check if user is instructor or enrolled student
    const courseId = assignment.courseId._id || assignment.courseId;
    const course = await Course.findById(courseId);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    const isInstructor = course.instructor.toString() === req.user.userId;
    const isStudent = course.students.some(s => s.toString() === req.user.userId);

    if (!isInstructor && !isStudent) {
      return res.status(403).json({ message: 'Access denied' });
    }

    // Get test cases (hide solution and hidden test cases for students)
    const testCases = await TestCase.getByAssignment(req.params.id, isInstructor);
    
    const assignmentData = assignment.toObject();
    
    // Remove solution code for students
    if (!isInstructor && assignmentData.codeConfig) {
      delete assignmentData.codeConfig.solutionCode;
    }

    console.log('📤 Sending code assignment to frontend:', JSON.stringify({
      title: assignmentData.title,
      type: assignmentData.type,
      description: assignmentData.description,
      hasCodeConfig: !!assignmentData.codeConfig,
      codeConfigKeys: assignmentData.codeConfig ? Object.keys(assignmentData.codeConfig) : [],
    }, null, 2));

    res.json({
      assignment: assignmentData,
      testCases: testCases.map(tc => ({
        _id: tc._id,
        name: tc.name,
        description: tc.description,
        input: tc.input,
        expectedOutput: tc.expectedOutput,
        weight: tc.weight,
        timeLimit: tc.timeLimit,
        memoryLimit: tc.memoryLimit,
        isHidden: tc.isHidden,
        order: tc.order
      }))
    });
  } catch (error) {
    console.error('Get code assignment error:', error);
    res.status(500).json({ message: 'Failed to get assignment', error: error.message });
  }
});

// Submit code solution
router.post('/assignments/:id/submit', auth, async (req, res) => {
  try {
    const { code, language } = req.body;

    if (!code || !language) {
      return res.status(400).json({ message: 'Code and language are required' });
    }

    const assignment = await Assignment.findById(req.params.id);
    if (!assignment || assignment.type !== 'code') {
      return res.status(404).json({ message: 'Code assignment not found' });
    }

    // Check if language is allowed
    if (!assignment.codeConfig.allowedLanguages.includes(language)) {
      return res.status(400).json({ 
        message: `Language ${language} not allowed for this assignment`,
        allowedLanguages: assignment.codeConfig.allowedLanguages
      });
    }

    // Check deadline
    const now = new Date();
    if (now > new Date(assignment.deadline)) {
      if (!assignment.allowLateSubmission || now > new Date(assignment.lateDeadline)) {
        return res.status(400).json({ message: 'Assignment deadline has passed' });
      }
    }

    // Get test cases
    const testCases = await TestCase.getByAssignment(req.params.id, true); // Include hidden tests
    
    if (testCases.length === 0) {
      return res.status(400).json({ message: 'No test cases found for this assignment' });
    }

    // Create submission record
    const submission = new CodeSubmission({
      assignmentId: assignment._id,
      studentId: req.user.userId,
      code,
      language,
      languageId: LANGUAGE_IDS[language],
      status: 'running'
    });

    await submission.save();

    // Execute code against test cases asynchronously
    executeWithTestCases(
      code,
      language,
      testCases,
      assignment.codeConfig.timeLimit / 1000, // Convert to seconds
      assignment.codeConfig.memoryLimit
    ).then(async (results) => {
      submission.testResults = results;
      submission.calculateScore();
      submission.updateExecutionSummary();
      submission.status = 'completed';
      submission.gradedAt = new Date();

      // Check if this is the best submission
      const bestSubmission = await CodeSubmission.getBestSubmission(assignment._id, req.user.userId);
      if (!bestSubmission || submission.totalScore > bestSubmission.totalScore) {
        // Mark all previous submissions as not best
        await CodeSubmission.updateMany(
          { assignmentId: assignment._id, studentId: req.user.userId },
          { isBestSubmission: false }
        );
        submission.isBestSubmission = true;
      }

      await submission.save();
    }).catch(async (error) => {
      console.error('Code execution error:', error);
      submission.status = 'error';
      submission.testResults = [{
        status: 'error',
        errorMessage: error.message
      }];
      await submission.save();
    });

    console.log('📤 Sending submission response:', {
      submissionId: submission._id.toString(),
      status: 'running',
      message: 'Code submitted successfully'
    });

    res.status(201).json({
      message: 'Code submitted successfully',
      submissionId: submission._id.toString(), // Convert to string
      status: 'running'
    });
  } catch (error) {
    console.error('Submit code error:', error);
    res.status(500).json({ message: 'Failed to submit code', error: error.message });
  }
});

// Get submission result
router.get('/submissions/:id', auth, async (req, res) => {
  try {
    const submission = await CodeSubmission.findById(req.params.id)
      .populate('assignmentId', 'title points codeConfig')
      .populate('studentId', 'fullName email');

    if (!submission) {
      return res.status(404).json({ message: 'Submission not found' });
    }

    // Check authorization
    const assignment = await Assignment.findById(submission.assignmentId);
    const course = await Course.findById(assignment.courseId);
    const isInstructor = course.instructor.toString() === req.user.userId;
    const isOwner = submission.studentId._id.toString() === req.user.userId;

    if (!isInstructor && !isOwner) {
      return res.status(403).json({ message: 'Access denied' });
    }

    // Hide solution code from students
    const submissionData = submission.toObject();
    if (!isInstructor && assignment.codeConfig) {
      delete assignment.codeConfig.solutionCode;
    }

    res.json(submissionData);
  } catch (error) {
    console.error('Get submission error:', error);
    res.status(500).json({ message: 'Failed to get submission', error: error.message });
  }
});

// Get student's submission history for an assignment
router.get('/assignments/:id/my-submissions', auth, async (req, res) => {
  try {
    const submissions = await CodeSubmission.find({
      assignmentId: req.params.id,
      studentId: req.user.userId
    })
    .select('-code') // Exclude code from list
    .sort({ submittedAt: -1 })
    .limit(50); // Last 50 submissions

    res.json(submissions);
  } catch (error) {
    console.error('Get submissions error:', error);
    res.status(500).json({ message: 'Failed to get submissions', error: error.message });
  }
});

// Get all submissions for an assignment (instructor only)
router.get('/assignments/:id/submissions', auth, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    const course = await Course.findById(assignment.courseId);
    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Only instructor can view all submissions' });
    }

    // Get best submission for each student
    const submissions = await CodeSubmission.aggregate([
      {
        $match: {
          assignmentId: assignment._id,
          status: 'completed'
        }
      },
      {
        $sort: { studentId: 1, totalScore: -1, submittedAt: 1 }
      },
      {
        $group: {
          _id: '$studentId',
          bestSubmission: { $first: '$$ROOT' }
        }
      },
      {
        $replaceRoot: { newRoot: '$bestSubmission' }
      },
      {
        $lookup: {
          from: 'users',
          localField: 'studentId',
          foreignField: '_id',
          as: 'student'
        }
      },
      {
        $unwind: '$student'
      },
      {
        $addFields: {
          'student.fullName': {
            $concat: [
              { $ifNull: ['$student.firstName', ''] },
              ' ',
              { $ifNull: ['$student.lastName', ''] }
            ]
          }
        }
      },
      {
        $project: {
          studentId: 1,
          'student.fullName': 1,
          'student.firstName': 1,
          'student.lastName': 1,
          'student.email': 1,
          'student.profilePicture': 1,
          totalScore: 1,
          passedTests: 1,
          totalTests: 1,
          submittedAt: 1,
          executionSummary: 1,
          isBestSubmission: 1
        }
      },
      {
        $sort: { totalScore: -1, submittedAt: 1 }
      }
    ]);

    console.log('📤 Sending submissions to instructor:', {
      count: submissions.length,
      sample: submissions.length > 0 ? {
        hasStudent: !!submissions[0].student,
        studentName: submissions[0].student?.fullName || 'NO NAME',
        studentEmail: submissions[0].student?.email || 'NO EMAIL',
        studentId: submissions[0].studentId,
      } : 'no submissions'
    });

    res.json(submissions);
  } catch (error) {
    console.error('Get all submissions error:', error);
    res.status(500).json({ message: 'Failed to get submissions', error: error.message });
  }
});

// Get leaderboard
router.get('/assignments/:id/leaderboard', auth, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const leaderboard = await CodeSubmission.getLeaderboard(req.params.id, limit);
    
    res.json(leaderboard);
  } catch (error) {
    console.error('Get leaderboard error:', error);
    res.status(500).json({ message: 'Failed to get leaderboard', error: error.message });
  }
});

// Test code without submitting (dry run)
router.post('/assignments/:id/test', auth, async (req, res) => {
  try {
    const { code, language, input } = req.body;

    const assignment = await Assignment.findById(req.params.id);
    if (!assignment || assignment.type !== 'code') {
      return res.status(404).json({ message: 'Code assignment not found' });
    }

    // Run code with provided input
    const result = await executeCode(
      code,
      language,
      input || '',
      assignment.codeConfig.timeLimit / 1000,
      assignment.codeConfig.memoryLimit
    );

    res.json({
      output: result.output,
      error: result.error,
      executionTime: result.executionTime,
      memoryUsed: result.memoryUsed,
      status: result.status,
      message: result.message
    });
  } catch (error) {
    console.error('Test code error:', error);
    res.status(500).json({ message: 'Failed to test code', error: error.message });
  }
});

// Add test case to assignment (instructor only)
router.post('/assignments/:id/test-cases', auth, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    const course = await Course.findById(assignment.courseId);
    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Only instructor can add test cases' });
    }

    const { name, description, input, expectedOutput, weight, timeLimit, memoryLimit, isHidden } = req.body;

    const testCase = new TestCase({
      assignmentId: assignment._id,
      name,
      description,
      input,
      expectedOutput,
      weight: weight || 1,
      timeLimit: timeLimit || assignment.codeConfig.timeLimit,
      memoryLimit: memoryLimit || assignment.codeConfig.memoryLimit,
      isHidden: isHidden || false,
      order: await TestCase.countDocuments({ assignmentId: assignment._id })
    });

    const validation = testCase.validateTestCase();
    if (!validation.isValid) {
      return res.status(400).json({ message: 'Invalid test case', errors: validation.errors });
    }

    await testCase.save();
    res.status(201).json({ message: 'Test case added successfully', testCase });
  } catch (error) {
    console.error('Add test case error:', error);
    res.status(500).json({ message: 'Failed to add test case', error: error.message });
  }
});

// Delete test case (instructor only)
router.delete('/test-cases/:id', auth, async (req, res) => {
  try {
    const testCase = await TestCase.findById(req.params.id);
    if (!testCase) {
      return res.status(404).json({ message: 'Test case not found' });
    }

    const assignment = await Assignment.findById(testCase.assignmentId);
    const course = await Course.findById(assignment.courseId);
    
    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Only instructor can delete test cases' });
    }

    testCase.isActive = false;
    await testCase.save();
    
    res.json({ message: 'Test case deleted successfully' });
  } catch (error) {
    console.error('Delete test case error:', error);
    res.status(500).json({ message: 'Failed to delete test case', error: error.message });
  }
});

module.exports = router;
