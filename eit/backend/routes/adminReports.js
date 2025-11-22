const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Course = require('../models/Course');
const Assignment = require('../models/Assignment');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const Department = require('../models/Department');
const { auth, adminOnly } = require('../middleware/auth');
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');

// @route   POST /api/admin/reports/generate-department-report
// @desc    Generate department training report (Excel/PDF)
// @access  Admin only
router.post('/generate-department-report', auth, adminOnly, async (req, res) => {
  try {
    const { departmentId, format = 'excel' } = req.body; // format: 'excel' or 'pdf'

    if (!departmentId) {
      return res.status(400).json({ message: 'departmentId is required' });
    }

    const department = await Department.findById(departmentId)
      .populate('courses')
      .populate('employees', 'fullName email department studentId');

    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Collect training data
    const reportData = {
      departmentName: department.name,
      departmentCode: department.code,
      totalEmployees: department.employees.length,
      totalCourses: department.courses.length,
      generatedAt: new Date(),
      courseProgress: []
    };

    for (const course of department.courses) {
      const fullCourse = await Course.findById(course._id).populate('students');
      const assignments = await Assignment.find({ course: course._id });
      const quizzes = await Quiz.find({ course: course._id });

      const enrolledEmployees = fullCourse.students.filter(student =>
        department.employees.some(emp => emp._id.equals(student._id))
      );

      const employeeProgress = [];

      for (const employee of enrolledEmployees) {
        let completedAssignments = 0;
        let totalAssignments = assignments.length;

        // Check assignment completion
        for (const assignment of assignments) {
          const submission = assignment.submissions.find(
            sub => sub.studentId.toString() === employee._id.toString()
          );
          if (submission) completedAssignments++;
        }

        // Check quiz attempts
        const quizAttempts = await QuizAttempt.find({
          student: employee._id,
          quiz: { $in: quizzes.map(q => q._id) },
          isCompleted: true
        });

        const averageQuizScore = quizAttempts.length > 0
          ? quizAttempts.reduce((sum, attempt) => sum + (attempt.score || 0), 0) / quizAttempts.length
          : 0;

        employeeProgress.push({
          employeeName: employee.fullName,
          employeeEmail: employee.email,
          studentId: employee.studentId,
          completedAssignments,
          totalAssignments,
          completedQuizzes: quizAttempts.length,
          totalQuizzes: quizzes.length,
          averageQuizScore: Math.round(averageQuizScore * 100) / 100
        });
      }

      reportData.courseProgress.push({
        courseName: fullCourse.name,
        courseCode: fullCourse.code,
        enrolledCount: enrolledEmployees.length,
        employees: employeeProgress
      });
    }

    if (format === 'excel') {
      // Generate Excel report
      const workbook = new ExcelJS.Workbook();
      const worksheet = workbook.addWorksheet('Department Report');

      // Header
      worksheet.addRow(['Department Training Report']);
      worksheet.addRow(['Department:', reportData.departmentName]);
      worksheet.addRow(['Department Code:', reportData.departmentCode]);
      worksheet.addRow(['Total Employees:', reportData.totalEmployees]);
      worksheet.addRow(['Total Courses:', reportData.totalCourses]);
      worksheet.addRow(['Generated:', reportData.generatedAt.toLocaleString()]);
      worksheet.addRow([]);

      // Course details
      for (const course of reportData.courseProgress) {
        worksheet.addRow([`Course: ${course.courseName} (${course.courseCode})`]);
        worksheet.addRow(['Employee Name', 'Email', 'Student ID', 'Assignments', 'Quizzes', 'Avg Quiz Score']);

        for (const emp of course.employees) {
          worksheet.addRow([
            emp.employeeName,
            emp.employeeEmail,
            emp.studentId || 'N/A',
            `${emp.completedAssignments}/${emp.totalAssignments}`,
            `${emp.completedQuizzes}/${emp.totalQuizzes}`,
            `${emp.averageQuizScore}%`
          ]);
        }

        worksheet.addRow([]);
      }

      const buffer = await workbook.xlsx.writeBuffer();

      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename=department_report_${department.code}_${Date.now()}.xlsx`);
      res.send(buffer);

    } else if (format === 'pdf') {
      // Generate PDF report
      const doc = new PDFDocument();
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=department_report_${department.code}_${Date.now()}.pdf`);

      doc.pipe(res);

      // Title
      doc.fontSize(20).text('Department Training Report', { align: 'center' });
      doc.moveDown();

      // Department info
      doc.fontSize(12);
      doc.text(`Department: ${reportData.departmentName}`);
      doc.text(`Department Code: ${reportData.departmentCode}`);
      doc.text(`Total Employees: ${reportData.totalEmployees}`);
      doc.text(`Total Courses: ${reportData.totalCourses}`);
      doc.text(`Generated: ${reportData.generatedAt.toLocaleString()}`);
      doc.moveDown(2);

      // Course details
      for (const course of reportData.courseProgress) {
        doc.fontSize(14).text(`Course: ${course.courseName} (${course.courseCode})`, { underline: true });
        doc.moveDown();

        doc.fontSize(10);
        for (const emp of course.employees) {
          doc.text(`${emp.employeeName} - ${emp.employeeEmail}`);
          doc.text(`  Assignments: ${emp.completedAssignments}/${emp.totalAssignments} | Quizzes: ${emp.completedQuizzes}/${emp.totalQuizzes} | Avg Score: ${emp.averageQuizScore}%`);
          doc.moveDown(0.5);
        }

        doc.moveDown();
      }

      doc.end();
    } else {
      res.status(400).json({ message: 'Invalid format. Use "excel" or "pdf"' });
    }

  } catch (error) {
    console.error('Error generating department report:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   POST /api/admin/reports/generate-individual-report
// @desc    Generate individual student training report
// @access  Admin only
router.post('/generate-individual-report', auth, adminOnly, async (req, res) => {
  try {
    const { userId, format = 'excel' } = req.body;

    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get all courses user is enrolled in
    const courses = await Course.find({ students: userId })
      .populate('instructor', 'fullName email');

    const reportData = {
      userName: user.fullName,
      userEmail: user.email,
      studentId: user.studentId,
      department: user.department,
      generatedAt: new Date(),
      courseProgress: []
    };

    for (const course of courses) {
      const assignments = await Assignment.find({ course: course._id });
      const quizzes = await Quiz.find({ course: course._id });

      let completedAssignments = 0;

      // Check assignments
      for (const assignment of assignments) {
        const submission = assignment.submissions.find(
          sub => sub.studentId.toString() === userId
        );
        if (submission) completedAssignments++;
      }

      // Check quizzes
      const quizAttempts = await QuizAttempt.find({
        student: userId,
        quiz: { $in: quizzes.map(q => q._id) },
        isCompleted: true
      });

      const quizDetails = [];
      for (const attempt of quizAttempts) {
        const quiz = quizzes.find(q => q._id.equals(attempt.quiz));
        quizDetails.push({
          quizTitle: quiz ? quiz.title : 'Unknown Quiz',
          score: attempt.score || 0,
          completedAt: attempt.completedAt
        });
      }

      const averageQuizScore = quizAttempts.length > 0
        ? quizAttempts.reduce((sum, attempt) => sum + (attempt.score || 0), 0) / quizAttempts.length
        : 0;

      reportData.courseProgress.push({
        courseName: course.name,
        courseCode: course.code,
        instructor: course.instructor ? course.instructor.fullName : 'Unknown',
        completedAssignments,
        totalAssignments: assignments.length,
        completedQuizzes: quizAttempts.length,
        totalQuizzes: quizzes.length,
        averageQuizScore: Math.round(averageQuizScore * 100) / 100,
        quizDetails
      });
    }

    if (format === 'excel') {
      const workbook = new ExcelJS.Workbook();
      const worksheet = workbook.addWorksheet('Individual Report');

      // Header
      worksheet.addRow(['Individual Training Report']);
      worksheet.addRow(['Student Name:', reportData.userName]);
      worksheet.addRow(['Email:', reportData.userEmail]);
      worksheet.addRow(['Student ID:', reportData.studentId || 'N/A']);
      worksheet.addRow(['Department:', reportData.department]);
      worksheet.addRow(['Generated:', reportData.generatedAt.toLocaleString()]);
      worksheet.addRow([]);

      // Course progress
      worksheet.addRow(['Course', 'Instructor', 'Assignments', 'Quizzes', 'Avg Quiz Score']);

      for (const course of reportData.courseProgress) {
        worksheet.addRow([
          `${course.courseName} (${course.courseCode})`,
          course.instructor,
          `${course.completedAssignments}/${course.totalAssignments}`,
          `${course.completedQuizzes}/${course.totalQuizzes}`,
          `${course.averageQuizScore}%`
        ]);
      }

      const buffer = await workbook.xlsx.writeBuffer();

      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename=individual_report_${user.username}_${Date.now()}.xlsx`);
      res.send(buffer);

    } else if (format === 'pdf') {
      const doc = new PDFDocument();
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=individual_report_${user.username}_${Date.now()}.pdf`);

      doc.pipe(res);

      doc.fontSize(20).text('Individual Training Report', { align: 'center' });
      doc.moveDown();

      doc.fontSize(12);
      doc.text(`Student Name: ${reportData.userName}`);
      doc.text(`Email: ${reportData.userEmail}`);
      doc.text(`Student ID: ${reportData.studentId || 'N/A'}`);
      doc.text(`Department: ${reportData.department}`);
      doc.text(`Generated: ${reportData.generatedAt.toLocaleString()}`);
      doc.moveDown(2);

      for (const course of reportData.courseProgress) {
        doc.fontSize(14).text(`${course.courseName} (${course.courseCode})`, { underline: true });
        doc.fontSize(10);
        doc.text(`Instructor: ${course.instructor}`);
        doc.text(`Assignments: ${course.completedAssignments}/${course.totalAssignments}`);
        doc.text(`Quizzes: ${course.completedQuizzes}/${course.totalQuizzes}`);
        doc.text(`Average Quiz Score: ${course.averageQuizScore}%`);
        doc.moveDown();
      }

      doc.end();
    } else {
      res.status(400).json({ message: 'Invalid format. Use "excel" or "pdf"' });
    }

  } catch (error) {
    console.error('Error generating individual report:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/reports/export-all-users
// @desc    Export all users to Excel
// @access  Admin only
router.get('/export-all-users', auth, adminOnly, async (req, res) => {
  try {
    const users = await User.find()
      .select('-password -resetPasswordToken -resetPasswordExpires')
      .sort({ createdAt: -1 });

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('All Users');

    // Header row
    worksheet.addRow([
      'Username',
      'Email',
      'Full Name',
      'Role',
      'Department',
      'Student ID',
      'Phone',
      'Active',
      'Created At'
    ]);

    // Data rows
    for (const user of users) {
      worksheet.addRow([
        user.username,
        user.email,
        user.fullName,
        user.role,
        user.department,
        user.studentId || '',
        user.phoneNumber || '',
        user.isActive ? 'Yes' : 'No',
        user.createdAt.toLocaleString()
      ]);
    }

    const buffer = await workbook.xlsx.writeBuffer();

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=all_users_${Date.now()}.xlsx`);
    res.send(buffer);

  } catch (error) {
    console.error('Error exporting users:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
