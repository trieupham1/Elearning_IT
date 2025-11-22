const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Course = require('../models/Course');
const Assignment = require('../models/Assignment');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const Department = require('../models/Department');
const ActivityLog = require('../models/ActivityLog');
const { auth, adminOnly } = require('../middleware/auth');

// @route   GET /api/admin/dashboard/overview
// @desc    Get admin dashboard overview metrics
// @access  Admin only
router.get('/overview', auth, adminOnly, async (req, res) => {
  try {
    // Get total counts
    const totalUsers = await User.countDocuments();
    const totalCourses = await Course.countDocuments();
    const totalDepartments = await Department.countDocuments();
    const activeCourses = await Course.countDocuments({
      endDate: { $gte: new Date() }
    });

    // Get user breakdown
    const students = await User.countDocuments({ role: 'student' });
    const instructors = await User.countDocuments({ role: 'instructor' });
    const admins = await User.countDocuments({ role: 'admin' });
    const activeUsers = await User.countDocuments({ isActive: true });

    // Get recent activity
    const recentActivity = await ActivityLog.find()
      .sort({ timestamp: -1 })
      .limit(10)
      .populate('user', 'fullName email role');

    // Get course enrollments
    const enrollmentStats = await Course.aggregate([
      {
        $project: {
          title: 1,
          studentCount: { $size: '$students' }
        }
      },
      { $sort: { studentCount: -1 } },
      { $limit: 5 }
    ]);

    res.json({
      totalUsers,
      totalCourses,
      totalDepartments,
      activeCourses,
      userBreakdown: {
        students,
        instructors,
        admins,
        activeUsers
      },
      topCoursesByEnrollment: enrollmentStats,
      recentActivity
    });
  } catch (error) {
    console.error('Error fetching dashboard overview:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/dashboard/user-growth
// @desc    Get user growth statistics
// @access  Admin only
router.get('/user-growth', auth, adminOnly, async (req, res) => {
  try {
    const { period = 'month' } = req.query; // 'week', 'month', 'year'

    let groupBy;
    let dateRange = new Date();

    switch (period) {
      case 'week':
        dateRange.setDate(dateRange.getDate() - 7);
        groupBy = {
          year: { $year: '$createdAt' },
          month: { $month: '$createdAt' },
          day: { $dayOfMonth: '$createdAt' }
        };
        break;
      case 'month':
        dateRange.setMonth(dateRange.getMonth() - 1);
        groupBy = {
          year: { $year: '$createdAt' },
          month: { $month: '$createdAt' },
          day: { $dayOfMonth: '$createdAt' }
        };
        break;
      case 'year':
        dateRange.setFullYear(dateRange.getFullYear() - 1);
        groupBy = {
          year: { $year: '$createdAt' },
          month: { $month: '$createdAt' }
        };
        break;
      default:
        dateRange.setMonth(dateRange.getMonth() - 1);
        groupBy = {
          year: { $year: '$createdAt' },
          month: { $month: '$createdAt' },
          day: { $dayOfMonth: '$createdAt' }
        };
    }

    const userGrowth = await User.aggregate([
      {
        $match: {
          createdAt: { $gte: dateRange }
        }
      },
      {
        $group: {
          _id: groupBy,
          count: { $sum: 1 },
          roles: {
            $push: '$role'
          }
        }
      },
      { $sort: { '_id.year': 1, '_id.month': 1, '_id.day': 1 } }
    ]);

    res.json({ period, data: userGrowth });
  } catch (error) {
    console.error('Error fetching user growth:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/dashboard/completion-rates
// @desc    Get course completion rates
// @access  Admin only
router.get('/completion-rates', auth, adminOnly, async (req, res) => {
  try {
    // Get completion rates by analyzing quiz attempts and assignments
    const courses = await Course.find()
      .select('title code students')
      .populate('students', 'fullName');

    const completionData = [];

    for (const course of courses) {
      const totalStudents = course.students.length;
      
      if (totalStudents === 0) continue;

      // Get assignments for this course
      const assignments = await Assignment.find({ course: course._id });
      const quizzes = await Quiz.find({ course: course._id });

      // Count students who completed all assignments
      let completedStudents = 0;

      for (const student of course.students) {
        let studentCompleted = true;

        // Check assignments
        for (const assignment of assignments) {
          const submission = assignment.submissions.find(
            sub => sub.studentId.toString() === student._id.toString()
          );
          if (!submission) {
            studentCompleted = false;
            break;
          }
        }

        // Check quizzes if still completed
        if (studentCompleted) {
          for (const quiz of quizzes) {
            const attempt = await QuizAttempt.findOne({
              quiz: quiz._id,
              student: student._id,
              isCompleted: true
            });
            if (!attempt) {
              studentCompleted = false;
              break;
            }
          }
        }

        if (studentCompleted) completedStudents++;
      }

      const completionRate = totalStudents > 0
        ? (completedStudents / totalStudents) * 100
        : 0;

      completionData.push({
        courseId: course._id,
        courseTitle: course.title,
        courseCode: course.code,
        totalStudents,
        completedStudents,
        completionRate: Math.round(completionRate * 100) / 100
      });
    }

    // Sort by completion rate
    completionData.sort((a, b) => b.completionRate - a.completionRate);

    res.json(completionData);
  } catch (error) {
    console.error('Error fetching completion rates:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/dashboard/training-progress-by-department
// @desc    Get training progress breakdown by department
// @access  Admin only
router.get('/training-progress-by-department', auth, adminOnly, async (req, res) => {
  try {
    const departments = await Department.find({ isActive: true })
      .populate('courses')
      .populate('employees');

    const departmentProgress = [];

    for (const dept of departments) {
      const deptData = {
        departmentId: dept._id,
        departmentName: dept.name,
        departmentCode: dept.code,
        totalEmployees: dept.employees.length,
        totalCourses: dept.courses.length,
        coursesProgress: []
      };

      // Calculate progress for each course
      for (const course of dept.courses) {
        const fullCourse = await Course.findById(course._id).populate('students');
        
        if (!fullCourse) continue;

        const enrolledDeptEmployees = fullCourse.students.filter(student =>
          dept.employees.some(emp => emp._id.equals(student._id))
        );

        const assignments = await Assignment.find({ course: course._id });
        const quizzes = await Quiz.find({ course: course._id });

        let completedCount = 0;

        // Check completion for department employees
        for (const employee of enrolledDeptEmployees) {
          let hasCompleted = true;

          // Check assignments
          for (const assignment of assignments) {
            const submission = assignment.submissions.find(
              sub => sub.studentId.toString() === employee._id.toString()
            );
            if (!submission) {
              hasCompleted = false;
              break;
            }
          }

          // Check quizzes
          if (hasCompleted) {
            for (const quiz of quizzes) {
              const attempt = await QuizAttempt.findOne({
                quiz: quiz._id,
                student: employee._id,
                isCompleted: true
              });
              if (!attempt) {
                hasCompleted = false;
                break;
              }
            }
          }

          if (hasCompleted) completedCount++;
        }

        deptData.coursesProgress.push({
          courseTitle: fullCourse.title,
          courseCode: fullCourse.code,
          enrolledEmployees: enrolledDeptEmployees.length,
          completedEmployees: completedCount,
          completionRate: enrolledDeptEmployees.length > 0
            ? Math.round((completedCount / enrolledDeptEmployees.length) * 100 * 100) / 100
            : 0
        });
      }

      // Calculate overall department completion rate
      const totalEnrollments = deptData.coursesProgress.reduce((sum, cp) => sum + cp.enrolledEmployees, 0);
      const totalCompletions = deptData.coursesProgress.reduce((sum, cp) => sum + cp.completedEmployees, 0);

      deptData.overallCompletionRate = totalEnrollments > 0
        ? Math.round((totalCompletions / totalEnrollments) * 100 * 100) / 100
        : 0;

      departmentProgress.push(deptData);
    }

    res.json(departmentProgress);
  } catch (error) {
    console.error('Error fetching department training progress:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/dashboard/top-performers
// @desc    Get top performing students
// @access  Admin only
router.get('/top-performers', auth, adminOnly, async (req, res) => {
  try {
    const { limit = 10 } = req.query;

    // Get all quiz attempts with scores
    const topPerformers = await QuizAttempt.aggregate([
      {
        $match: {
          isCompleted: true,
          score: { $exists: true, $ne: null }
        }
      },
      {
        $group: {
          _id: '$student',
          averageScore: { $avg: '$score' },
          totalQuizzes: { $sum: 1 },
          totalPoints: { $sum: '$score' }
        }
      },
      { $sort: { averageScore: -1 } },
      { $limit: parseInt(limit) }
    ]);

    // Populate student details
    await User.populate(topPerformers, {
      path: '_id',
      select: 'fullName email department profilePicture'
    });

    const formattedPerformers = topPerformers.map(p => ({
      student: p._id,
      averageScore: Math.round(p.averageScore * 100) / 100,
      totalQuizzes: p.totalQuizzes,
      totalPoints: p.totalPoints
    }));

    res.json(formattedPerformers);
  } catch (error) {
    console.error('Error fetching top performers:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/dashboard/low-performers
// @desc    Get students who need attention (low scores or incomplete work)
// @access  Admin only
router.get('/low-performers', auth, adminOnly, async (req, res) => {
  try {
    const { threshold = 50, limit = 20 } = req.query;

    const lowPerformers = await QuizAttempt.aggregate([
      {
        $match: {
          isCompleted: true,
          score: { $exists: true, $lte: parseInt(threshold) }
        }
      },
      {
        $group: {
          _id: '$student',
          averageScore: { $avg: '$score' },
          totalQuizzes: { $sum: 1 },
          failedQuizzes: {
            $sum: { $cond: [{ $lte: ['$score', parseInt(threshold)] }, 1, 0] }
          }
        }
      },
      { $sort: { averageScore: 1 } },
      { $limit: parseInt(limit) }
    ]);

    await User.populate(lowPerformers, {
      path: '_id',
      select: 'fullName email department profilePicture'
    });

    const formattedPerformers = lowPerformers.map(p => ({
      student: p._id,
      averageScore: Math.round(p.averageScore * 100) / 100,
      totalQuizzes: p.totalQuizzes,
      failedQuizzes: p.failedQuizzes
    }));

    res.json(formattedPerformers);
  } catch (error) {
    console.error('Error fetching low performers:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
