// routes/assignments.js
const express = require('express');
const router = express.Router();
const Assignment = require('../models/Assignment');
const Submission = require('../models/Submission');
const User = require('../models/User');
const Course = require('../models/Course');
const Group = require('../models/Group');
const authMiddleware = require('../middleware/auth');
const { createNotification } = require('../utils/notifications');
const { notifyAssignmentSubmission, notifyNewAssignment: notifyNewAssignmentHelper, sendSubmissionConfirmation } = require('../utils/notificationHelper');

// Middleware to check if user is instructor
const instructorOnly = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId);
    if (user && user.role === 'instructor') {
      next();
    } else {
      res.status(403).json({ message: 'Access denied. Instructors only.' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Error checking permissions' });
  }
};

// Helper function to check if submission is late
const isSubmissionLate = (assignment, submissionDate) => {
  const deadline = new Date(assignment.deadline);
  const submitted = new Date(submissionDate);
  return submitted > deadline;
};

// Helper function to get student group
const getStudentGroup = async (courseId, studentId) => {
  const groups = await Group.find({ courseId });
  for (const group of groups) {
    // Check if group.members exists and includes the studentId
    if (group.members && group.members.some(memberId => memberId.toString() === studentId.toString())) {
      return { groupId: group._id, groupName: group.name };
    }
  }
  return { groupId: null, groupName: null };
};

// Helper function to notify submission graded
const notifySubmissionGraded = async (studentId, assignmentId, assignmentTitle, grade) => {
  try {
    await createNotification({
      userId: studentId,
      type: 'submission_graded',
      title: 'Assignment Graded',
      message: `Your submission for "${assignmentTitle}" has been graded: ${grade} points`,
      relatedId: assignmentId,
      relatedType: 'assignment'
    });
  } catch (error) {
    console.error('Error sending grade notification:', error);
  }
};

// ==================== ASSIGNMENT CRUD ====================

// Create new assignment
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
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
      allowedFileTypes,
      maxFileSize,
      attachments,
      points
    } = req.body;

    // Get instructor details
    const instructor = await User.findById(req.user.userId);
    if (!instructor) {
      return res.status(404).json({ message: 'Instructor not found' });
    }

    const createdByName = instructor.fullName || instructor.username || instructor.email || 'Unknown';

    const assignment = new Assignment({
      courseId,
      createdBy: req.user.userId,
      createdByName,
      title,
      description,
      groupIds: groupIds || [],
      startDate,
      deadline,
      allowLateSubmission: allowLateSubmission || false,
      lateDeadline,
      maxAttempts: maxAttempts || 1,
      allowedFileTypes: allowedFileTypes || [],
      maxFileSize: maxFileSize || 10485760,
      attachments: attachments || [],
      points: points || 100
    });

    await assignment.save();

    // Send notifications to students using the proper helper
    try {
      const course = await Course.findById(courseId);
      if (course && course.students && course.students.length > 0) {
        const studentIds = course.students.map(s => s.toString());
        await notifyNewAssignmentHelper(
          courseId.toString(),
          course.title,
          title,
          deadline,
          studentIds
        );
        console.log(`📬 Sent assignment notifications to ${studentIds.length} students`);
      }
    } catch (notifError) {
      console.error('Error sending assignment notifications:', notifError);
      // Don't fail the assignment creation if notification fails
    }

    res.status(201).json(assignment);
  } catch (error) {
    console.error('Error creating assignment:', error);
    res.status(400).json({ message: 'Error creating assignment', error: error.message });
  }
});

// Get all assignments for a course
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.params;
    const user = await User.findById(req.user.userId);

    let assignments;

    if (user.role === 'instructor') {
      // Instructors see all assignments
      assignments = await Assignment.find({ courseId }).sort({ createdAt: -1 });
    } else {
      // Students see only assignments for their groups
      const { groupId } = await getStudentGroup(courseId, req.user.userId);
      
      assignments = await Assignment.find({
        courseId,
        $or: [
          { groupIds: { $size: 0 } }, // All groups
          { groupIds: groupId } // Student's specific group
        ]
      }).sort({ createdAt: -1 });
    }

    res.json(assignments);
  } catch (error) {
    console.error('Error fetching assignments:', error);
    res.status(500).json({ message: 'Error fetching assignments' });
  }
});

// Get single assignment by ID
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    // Track view
    const existingView = assignment.viewedBy.find(
      v => v.userId.toString() === req.user.userId
    );
    
    if (!existingView) {
      assignment.viewedBy.push({
        userId: req.user.userId,
        viewedAt: new Date()
      });
      await assignment.save();
    }

    res.json(assignment);
  } catch (error) {
    console.error('Error fetching assignment:', error);
    res.status(500).json({ message: 'Error fetching assignment' });
  }
});

// Update assignment
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    // Update fields
    const allowedUpdates = [
      'title', 'description', 'groupIds', 'startDate', 'deadline',
      'allowLateSubmission', 'lateDeadline', 'maxAttempts',
      'allowedFileTypes', 'maxFileSize', 'attachments', 'points'
    ];

    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) {
        assignment[field] = req.body[field];
      }
    });

    await assignment.save();
    res.json(assignment);
  } catch (error) {
    console.error('Error updating assignment:', error);
    res.status(400).json({ message: 'Error updating assignment', error: error.message });
  }
});

// Delete assignment
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const assignment = await Assignment.findByIdAndDelete(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    // Delete all submissions for this assignment
    await Submission.deleteMany({ assignmentId: req.params.id });

    res.json({ message: 'Assignment and all submissions deleted' });
  } catch (error) {
    console.error('Error deleting assignment:', error);
    res.status(500).json({ message: 'Error deleting assignment' });
  }
});

// ==================== SUBMISSION HANDLING ====================

// Submit assignment
router.post('/:id/submit', authMiddleware, async (req, res) => {
  try {
    const { files } = req.body;
    const assignment = await Assignment.findById(req.params.id);
    
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    // Check if assignment is available
    const now = new Date();
    const startDate = new Date(assignment.startDate);
    const deadline = new Date(assignment.deadline);
    const lateDeadline = assignment.lateDeadline ? new Date(assignment.lateDeadline) : null;

    if (now < startDate) {
      return res.status(400).json({ message: 'Assignment not yet available' });
    }

    const isLate = now > deadline;
    
    if (isLate && !assignment.allowLateSubmission) {
      return res.status(400).json({ message: 'Deadline has passed and late submissions are not allowed' });
    }

    if (isLate && lateDeadline && now > lateDeadline) {
      return res.status(400).json({ message: 'Late deadline has passed' });
    }

    // Get student details
    const student = await User.findById(req.user.userId);
    if (!student) {
      return res.status(404).json({ message: 'Student not found' });
    }

    const studentName = student.fullName || student.username || student.email || 'Unknown';
    const { groupId, groupName } = await getStudentGroup(assignment.courseId, req.user.userId);

    // Check previous attempts
    const previousSubmissions = await Submission.find({
      assignmentId: req.params.id,
      studentId: req.user.userId
    }).sort({ attemptNumber: -1 });

    const attemptNumber = previousSubmissions.length + 1;

    if (attemptNumber > assignment.maxAttempts) {
      return res.status(400).json({ 
        message: `Maximum attempts (${assignment.maxAttempts}) exceeded` 
      });
    }

    // Validate files
    if (!files || files.length === 0) {
      return res.status(400).json({ message: 'At least one file is required' });
    }

    // Check file types and sizes
    for (const file of files) {
      if (file.fileSize > assignment.maxFileSize) {
        return res.status(400).json({ 
          message: `File ${file.fileName} exceeds maximum size limit` 
        });
      }

      if (assignment.allowedFileTypes.length > 0) {
        const fileExt = '.' + file.fileName.split('.').pop().toLowerCase();
        if (!assignment.allowedFileTypes.includes(fileExt)) {
          return res.status(400).json({ 
            message: `File type ${fileExt} is not allowed` 
          });
        }
      }
    }

    // Create submission
    const submission = new Submission({
      assignmentId: req.params.id,
      studentId: req.user.userId,
      studentName,
      studentEmail: student.email,
      groupId,
      groupName,
      attemptNumber,
      files,
      submittedAt: now,
      isLate,
      status: 'submitted'
    });

    await submission.save();

    // Get course and notify instructor
    try {
      const course = await Course.findById(assignment.courseId).populate('instructor');
      if (course && course.instructor) {
        await notifyAssignmentSubmission(
          course.instructor._id,
          course.title,
          assignment.title,
          studentName,
          submission._id.toString()
        );
        console.log(`📬 Notification sent to instructor ${course.instructor.username} for assignment submission`);
      }
      
      // Send confirmation email to student
      await sendSubmissionConfirmation(
        req.user.userId,
        assignment.toObject(),
        submission.toObject(),
        course ? course.title : 'Course'
      );
      console.log(`📧 Confirmation email sent to student ${studentName}`);
    } catch (notifError) {
      console.error('Error sending assignment submission notification:', notifError);
      // Don't fail the submission if notification fails
    }

    res.status(201).json(submission);
  } catch (error) {
    console.error('Error submitting assignment:', error);
    res.status(400).json({ message: 'Error submitting assignment', error: error.message });
  }
});

// Get student's submissions for an assignment
router.get('/:id/my-submissions', authMiddleware, async (req, res) => {
  try {
    const submissions = await Submission.find({
      assignmentId: req.params.id,
      studentId: req.user.userId
    }).sort({ attemptNumber: 1 });

    res.json(submissions);
  } catch (error) {
    console.error('Error fetching submissions:', error);
    res.status(500).json({ message: 'Error fetching submissions' });
  }
});

// Grade a submission
router.post('/submissions/:submissionId/grade', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { grade, feedback } = req.body;
    const submission = await Submission.findById(req.params.submissionId);
    
    if (!submission) {
      return res.status(404).json({ message: 'Submission not found' });
    }

    const assignment = await Assignment.findById(submission.assignmentId);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    // Validate grade
    if (grade < 0 || grade > assignment.points) {
      return res.status(400).json({ 
        message: `Grade must be between 0 and ${assignment.points}` 
      });
    }

    const grader = await User.findById(req.user.userId);
    const graderName = grader ? (grader.fullName || grader.username || 'Instructor') : 'Instructor';

    submission.grade = grade;
    submission.feedback = feedback || '';
    submission.gradedAt = new Date();
    submission.gradedBy = req.user.userId;
    submission.gradedByName = graderName;
    submission.status = 'graded';

    await submission.save();

    // Notify student
    await notifySubmissionGraded(
      submission.studentId,
      assignment._id,
      assignment.title,
      grade
    );

    res.json(submission);
  } catch (error) {
    console.error('Error grading submission:', error);
    res.status(400).json({ message: 'Error grading submission', error: error.message });
  }
});

// ==================== TRACKING & ANALYTICS ====================

// Get tracking data for an assignment
router.get('/:id/tracking', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    // Get all students in the course
    const course = await Course.findById(assignment.courseId).populate('students');
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    // Get all submissions
    const submissions = await Submission.find({ assignmentId: req.params.id });

    // Build tracking data
    const trackingData = [];
    
    for (const student of course.students) {
      const { groupId, groupName } = await getStudentGroup(assignment.courseId, student._id);
      
      // Check if student is in the assignment's target groups
      const isInTargetGroup = assignment.groupIds.length === 0 || 
                             assignment.groupIds.some(gid => gid.toString() === groupId?.toString());
      
      if (!isInTargetGroup) continue;

      const studentSubmissions = submissions.filter(
        s => s.studentId.toString() === student._id.toString()
      );

      const latestSubmission = studentSubmissions.length > 0 
        ? studentSubmissions[studentSubmissions.length - 1]
        : null;

      trackingData.push({
        studentId: student._id,
        studentName: student.fullName || student.username || student.email,
        studentEmail: student.email,
        groupId,
        groupName,
        hasSubmitted: studentSubmissions.length > 0,
        submissionCount: studentSubmissions.length,
        latestSubmission: latestSubmission ? {
          attemptNumber: latestSubmission.attemptNumber,
          submittedAt: latestSubmission.submittedAt,
          isLate: latestSubmission.isLate,
          grade: latestSubmission.grade,
          status: latestSubmission.status,
          feedback: latestSubmission.feedback,
          files: latestSubmission.files || []
        } : null,
        allSubmissions: studentSubmissions.map(s => ({
          id: s._id,
          attemptNumber: s.attemptNumber,
          submittedAt: s.submittedAt,
          isLate: s.isLate,
          grade: s.grade,
          status: s.status
        }))
      });
    }

    // Calculate statistics
    const stats = {
      totalStudents: trackingData.length,
      submitted: trackingData.filter(s => s.hasSubmitted).length,
      notSubmitted: trackingData.filter(s => !s.hasSubmitted).length,
      lateSubmissions: trackingData.filter(
        s => s.latestSubmission && s.latestSubmission.isLate
      ).length,
      graded: trackingData.filter(
        s => s.latestSubmission && s.latestSubmission.grade !== null && s.latestSubmission.grade !== undefined
      ).length,
      averageGrade: null
    };

    const gradedSubmissions = trackingData.filter(
      s => s.latestSubmission && s.latestSubmission.grade !== null && s.latestSubmission.grade !== undefined
    );

    if (gradedSubmissions.length > 0) {
      const totalGrade = gradedSubmissions.reduce(
        (sum, s) => sum + s.latestSubmission.grade, 0
      );
      stats.averageGrade = (totalGrade / gradedSubmissions.length).toFixed(2);
    }

    res.json({
      assignment,
      stats,
      students: trackingData
    });
  } catch (error) {
    console.error('Error fetching tracking data:', error);
    res.status(500).json({ message: 'Error fetching tracking data' });
  }
});

// Export tracking data as CSV
router.get('/:id/export-csv', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found' });
    }

    const course = await Course.findById(assignment.courseId).populate('students');
    const submissions = await Submission.find({ assignmentId: req.params.id });

    let csvData = 'Student Name,Email,Group,Submitted,Attempt,Submission Date,Late,Grade,Status,Feedback\n';

    for (const student of course.students) {
      const { groupId, groupName } = await getStudentGroup(assignment.courseId, student._id);
      
      const isInTargetGroup = assignment.groupIds.length === 0 || 
                             assignment.groupIds.some(gid => gid.toString() === groupId?.toString());
      
      if (!isInTargetGroup) continue;

      const studentSubmissions = submissions.filter(
        s => s.studentId.toString() === student._id.toString()
      );

      if (studentSubmissions.length === 0) {
        csvData += `"${student.fullName || student.username}","${student.email || ''}","${groupName || 'No Group'}",No,0,,,,,\n`;
      } else {
        for (const sub of studentSubmissions) {
          const submittedDate = sub.submittedAt ? new Date(sub.submittedAt).toLocaleString() : '';
          const grade = sub.grade !== null && sub.grade !== undefined ? sub.grade : '';
          const feedback = sub.feedback ? `"${sub.feedback.replace(/"/g, '""')}"` : '';
          
          csvData += `"${student.fullName || student.username}","${student.email || ''}","${groupName || 'No Group'}",Yes,${sub.attemptNumber},"${submittedDate}",${sub.isLate ? 'Yes' : 'No'},"${grade}","${sub.status}",${feedback}\n`;
        }
      }
    }

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="assignment_${assignment.title.replace(/[^a-z0-9]/gi, '_')}_tracking.csv"`);
    res.send(csvData);
  } catch (error) {
    console.error('Error exporting CSV:', error);
    res.status(500).json({ message: 'Error exporting CSV' });
  }
});

// Export all assignments for a course as CSV
router.get('/course/:courseId/export-csv', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { courseId } = req.params;
    const assignments = await Assignment.find({ courseId });
    const course = await Course.findById(courseId).populate('students');

    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    let csvData = 'Assignment,Student Name,Email,Group,Submitted,Attempt,Submission Date,Late,Grade,Status\n';

    for (const assignment of assignments) {
      const submissions = await Submission.find({ assignmentId: assignment._id });

      for (const student of course.students) {
        const { groupId, groupName } = await getStudentGroup(courseId, student._id);
        
        const isInTargetGroup = assignment.groupIds.length === 0 || 
                               assignment.groupIds.some(gid => gid.toString() === groupId?.toString());
        
        if (!isInTargetGroup) continue;

        const studentSubmissions = submissions.filter(
          s => s.studentId.toString() === student._id.toString()
        );

        if (studentSubmissions.length === 0) {
          csvData += `"${assignment.title}","${student.fullName || student.username}","${student.email || ''}","${groupName || 'No Group'}",No,0,,,\n`;
        } else {
          const latestSub = studentSubmissions[studentSubmissions.length - 1];
          const submittedDate = latestSub.submittedAt ? new Date(latestSub.submittedAt).toLocaleString() : '';
          const grade = latestSub.grade !== null && latestSub.grade !== undefined ? latestSub.grade : '';
          
          csvData += `"${assignment.title}","${student.fullName || student.username}","${student.email || ''}","${groupName || 'No Group'}",Yes,${latestSub.attemptNumber},"${submittedDate}",${latestSub.isLate ? 'Yes' : 'No'},"${grade}","${latestSub.status}"\n`;
        }
      }
    }

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="course_${courseId}_all_assignments.csv"`);
    res.send(csvData);
  } catch (error) {
    console.error('Error exporting course CSV:', error);
    res.status(500).json({ message: 'Error exporting course CSV' });
  }
});

module.exports = router;
