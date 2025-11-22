const express = require('express');
const router = express.Router();
const { authMiddleware, instructorOnly } = require('../middleware/auth');
const dbExporter = require('../exports/dashboardExporter');
const User = require('../models/User');
const Course = require('../models/Course');
const Assignment = require('../models/Assignment');
const Submission = require('../models/Submission');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const Question = require('../models/Question');
const Announcement = require('../models/Announcement');
const Notification = require('../models/Notification');
const Semester = require('../models/Semester');
const Group = require('../models/Group');
const Material = require('../models/Material');

/**
 * @route   GET /api/export/users/:format
 * @desc    Export all users data
 * @access  Private (Instructor/Admin)
 */
router.get('/users/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { role } = req.query; // Optional filter

    console.log(`📥 Exporting users in ${format} format`);

    const query = role ? { role } : {};
    const users = await User.find(query)
      .select('-password') // Exclude passwords
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('users', users, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('users', users);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('users', users);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/courses/:format
 * @desc    Export all courses data
 * @access  Private (Instructor/Admin)
 */
router.get('/courses/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { semesterId } = req.query;

    console.log(`📥 Exporting courses in ${format} format`);

    const query = semesterId ? { semester: semesterId } : {};
    const courses = await Course.find(query)
      .populate('instructor', 'username fullName email')
      .populate('semester', 'name year')
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('courses', courses, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('courses', courses);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('courses', courses);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/assignments/:format
 * @desc    Export all assignments data
 * @access  Private (Instructor/Admin)
 */
router.get('/assignments/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { courseId } = req.query;

    console.log(`📥 Exporting assignments in ${format} format`);

    const query = courseId ? { courseId } : {};
    const assignments = await Assignment.find(query)
      .populate('courseId', 'name code')
      .populate('createdBy', 'username fullName')
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('assignments', assignments, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('assignments', assignments);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('assignments', assignments);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/submissions/:format
 * @desc    Export all submissions data
 * @access  Private (Instructor/Admin)
 */
router.get('/submissions/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { courseId, assignmentId } = req.query;

    console.log(`📥 Exporting submissions in ${format} format`);

    let query = {};
    if (assignmentId) {
      query.assignmentId = assignmentId;
    } else if (courseId) {
      const assignments = await Assignment.find({ courseId }).select('_id');
      query.assignmentId = { $in: assignments.map(a => a._id) };
    }

    const submissions = await Submission.find(query)
      .populate('studentId', 'username fullName email studentId')
      .populate('assignmentId', 'title')
      .populate('gradedBy', 'username fullName')
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('submissions', submissions, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('submissions', submissions);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('submissions', submissions);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/quizzes/:format
 * @desc    Export all quizzes data
 * @access  Private (Instructor/Admin)
 */
router.get('/quizzes/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { courseId } = req.query;

    console.log(`📥 Exporting quizzes in ${format} format`);

    const query = courseId ? { courseId } : {};
    const quizzes = await Quiz.find(query)
      .populate('courseId', 'name code')
      .populate('createdBy', 'username fullName')
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('quizzes', quizzes, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('quizzes', quizzes);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('quizzes', quizzes);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/quiz-attempts/:format
 * @desc    Export all quiz attempts data
 * @access  Private (Instructor/Admin)
 */
router.get('/quiz-attempts/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { quizId } = req.query;

    console.log(`📥 Exporting quiz attempts in ${format} format`);

    const query = quizId ? { quizId } : {};
    const attempts = await QuizAttempt.find(query)
      .populate('studentId', 'username fullName email studentId')
      .populate('quizId', 'title')
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('quiz_attempts', attempts, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('quiz_attempts', attempts);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('quiz_attempts', attempts);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/announcements/:format
 * @desc    Export all announcements data
 * @access  Private (Instructor/Admin)
 */
router.get('/announcements/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;
    const { courseId } = req.query;

    console.log(`📥 Exporting announcements in ${format} format`);

    const query = courseId ? { courseId } : {};
    const announcements = await Announcement.find(query)
      .populate('courseId', 'name code')
      .populate('authorId', 'username fullName')
      .lean();

    let result;
    if (format === 'json') {
      result = await dbExporter.exportToJSON('announcements', announcements, query);
    } else if (format === 'csv') {
      result = await dbExporter.exportToCSV('announcements', announcements);
    } else if (format === 'excel') {
      result = await dbExporter.exportToExcel('announcements', announcements);
    } else {
      return res.status(400).json({ message: 'Invalid format. Use: json, csv, or excel' });
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/database/:format
 * @desc    Export entire database (all collections)
 * @access  Private (Admin only)
 */
router.get('/database/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { format } = req.params;

    if (format !== 'excel' && format !== 'json') {
      return res.status(400).json({ message: 'Full database export only supports excel or json format' });
    }

    console.log(`📥 Exporting entire database in ${format} format`);

    // Fetch all collections
    const [users, courses, assignments, submissions, quizzes, quizAttempts, announcements, semesters] = await Promise.all([
      User.find().select('-password').lean(),
      Course.find().populate('instructor', 'username').populate('semester', 'name').lean(),
      Assignment.find().populate('courseId', 'name').lean(),
      Submission.find().populate('studentId', 'username').populate('assignmentId', 'title').lean(),
      Quiz.find().populate('courseId', 'name').lean(),
      QuizAttempt.find().populate('studentId', 'username').populate('quizId', 'title').lean(),
      Announcement.find().populate('courseId', 'name').lean(),
      Semester.find().lean()
    ]);

    let result;
    
    if (format === 'excel') {
      const collections = [
        { name: 'Users', data: users },
        { name: 'Courses', data: courses },
        { name: 'Assignments', data: assignments },
        { name: 'Submissions', data: submissions },
        { name: 'Quizzes', data: quizzes },
        { name: 'Quiz Attempts', data: quizAttempts },
        { name: 'Announcements', data: announcements },
        { name: 'Semesters', data: semesters }
      ];

      result = await dbExporter.exportMultipleToExcel(collections);
    } else {
      const databaseData = {
        exportedAt: new Date().toISOString(),
        collections: {
          users,
          courses,
          assignments,
          submissions,
          quizzes,
          quizAttempts,
          announcements,
          semesters
        },
        statistics: {
          totalUsers: users.length,
          totalCourses: courses.length,
          totalAssignments: assignments.length,
          totalSubmissions: submissions.length,
          totalQuizzes: quizzes.length,
          totalQuizAttempts: quizAttempts.length,
          totalAnnouncements: announcements.length,
          totalSemesters: semesters.length
        }
      };

      result = await dbExporter.exportToJSON('full_database', [databaseData]);
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/student/:studentId/:format
 * @desc    Export all data related to a specific student
 * @access  Private (Instructor/Admin)
 */
router.get('/student/:studentId/:format', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { studentId, format } = req.params;

    if (format !== 'excel' && format !== 'json') {
      return res.status(400).json({ message: 'Student export only supports excel or json format' });
    }

    console.log(`📥 Exporting all data for student ${studentId} in ${format} format`);

    // Get student info
    const student = await User.findById(studentId).select('-password').lean();
    if (!student) {
      return res.status(404).json({ message: 'Student not found' });
    }

    // Get all student's courses
    const courses = await Course.find({ students: studentId })
      .populate('instructor', 'username fullName')
      .populate('semester', 'name year')
      .lean();

    const courseIds = courses.map(c => c._id);

    // Get all assignments for those courses
    const assignments = await Assignment.find({ courseId: { $in: courseIds } })
      .populate('courseId', 'name code')
      .populate('createdBy', 'username fullName')
      .lean();

    // Get all student's submissions
    const submissions = await Submission.find({ studentId })
      .populate({
        path: 'assignmentId',
        select: 'title courseId',
        populate: { path: 'courseId', select: 'name code' }
      })
      .populate('gradedBy', 'username fullName')
      .lean();

    // Get all quizzes for those courses
    const quizzes = await Quiz.find({ courseId: { $in: courseIds } })
      .populate('courseId', 'name code')
      .populate('createdBy', 'username fullName')
      .lean();

    // Get all student's quiz attempts
    const quizAttempts = await QuizAttempt.find({ studentId })
      .populate({
        path: 'quizId',
        select: 'title courseId',
        populate: { path: 'courseId', select: 'name code' }
      })
      .lean();

    // Get all announcements for those courses
    const announcements = await Announcement.find({ courseId: { $in: courseIds } })
      .populate('courseId', 'name code')
      .populate('authorId', 'username fullName')
      .lean();

    // Get student's notifications (no populate - courseId is in data field, not a direct reference)
    const notifications = await Notification.find({ userId: studentId })
      .sort({ createdAt: -1 })
      .lean();

    // Get student's groups
    const groups = await Group.find({ members: studentId })
      .populate('courseId', 'name code')
      .lean();

    // Calculate statistics
    const stats = {
      totalCourses: courses.length,
      totalAssignments: assignments.length,
      submittedAssignments: submissions.length,
      totalQuizzes: quizzes.length,
      completedQuizzes: quizAttempts.filter(a => a.status !== 'in_progress').length,
      averageAssignmentGrade: submissions.filter(s => s.grade).reduce((sum, s) => sum + s.grade, 0) / (submissions.filter(s => s.grade).length || 1),
      averageQuizScore: quizAttempts.reduce((sum, a) => sum + a.score, 0) / (quizAttempts.length || 1),
      totalAnnouncements: announcements.length,
      unreadNotifications: notifications.filter(n => !n.isRead).length,
      totalGroups: groups.length
    };

    let result;

    if (format === 'excel') {
      const collections = [
        { 
          name: 'Student Info', 
          data: [{ 
            ...student,
            exportedAt: new Date().toISOString(),
            ...stats
          }]
        },
        { name: 'Enrolled Courses', data: courses },
        { name: 'Submissions', data: submissions },
        { name: 'Quiz Attempts', data: quizAttempts },
        { name: 'Available Assignments', data: assignments },
        { name: 'Available Quizzes', data: quizzes },
        { name: 'Announcements', data: announcements },
        { name: 'Notifications', data: notifications },
        { name: 'Groups', data: groups }
      ];

      result = await dbExporter.exportMultipleToExcel(collections);
    } else {
      const studentData = {
        exportedAt: new Date().toISOString(),
        student: student,
        statistics: stats,
        courses: courses,
        submissions: submissions,
        quizAttempts: quizAttempts,
        assignments: assignments,
        quizzes: quizzes,
        announcements: announcements,
        notifications: notifications,
        groups: groups
      };

      result = await dbExporter.exportToJSON(`student_${studentId}_complete`, [studentData]);
    }

    res.download(result.filepath, result.filename);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route   GET /api/export/cleanup
 * @desc    Clean up old exported files
 * @access  Private (Admin)
 */
router.get('/cleanup', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const daysOld = parseInt(req.query.days) || 7;
    const deletedCount = dbExporter.cleanupOldExports(daysOld);
    
    res.json({
      message: 'Cleanup completed',
      deletedFiles: deletedCount,
      olderThan: `${daysOld} days`
    });
  } catch (error) {
    console.error('Cleanup error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
