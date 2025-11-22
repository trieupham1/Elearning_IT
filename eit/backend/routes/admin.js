const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Course = require('../models/Course');
const ActivityLog = require('../models/ActivityLog');
const bcrypt = require('bcrypt');
const { auth, adminOnly } = require('../middleware/auth');
const ExcelJS = require('exceljs');
const multer = require('multer');

// Configure multer for file upload
const upload = multer({ storage: multer.memoryStorage() });

// @route   GET /api/admin/users
// @desc    Get all users with advanced filters, search, pagination
// @access  Admin only
router.get('/users', auth, adminOnly, async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      search,
      role,
      department,
      isActive,
      sortBy = 'createdAt',
      sortOrder = 'desc'
    } = req.query;

    // Build query
    let query = {};

    if (search) {
      query.$or = [
        { username: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
        { firstName: { $regex: search, $options: 'i' } },
        { lastName: { $regex: search, $options: 'i' } },
        { studentId: { $regex: search, $options: 'i' } }
      ];
    }

    if (role) query.role = role;
    if (department) query.department = department;
    if (isActive !== undefined) query.isActive = isActive === 'true';

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === 'desc' ? -1 : 1;

    // Execute query
    const users = await User.find(query)
      .select('-password -resetPasswordToken -resetPasswordExpires')
      .sort(sortOptions)
      .limit(parseInt(limit))
      .skip(skip);

    const total = await User.countDocuments(query);

    res.json({
      users,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   POST /api/admin/users
// @desc    Create a new user manually
// @access  Admin only
router.post('/users', auth, adminOnly, async (req, res) => {
  try {
    const { username, email, password, firstName, lastName, role, department, studentId, phoneNumber } = req.body;

    // Validation
    if (!username || !email || !password) {
      return res.status(400).json({ message: 'Username, email, and password are required' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ $or: [{ username }, { email }] });
    if (existingUser) {
      if (existingUser.username === username) {
        return res.status(400).json({ message: 'Username already exists' });
      }
      if (existingUser.email === email) {
        return res.status(400).json({ message: 'Email already exists' });
      }
    }

    // Check if studentId is unique (if provided)
    if (studentId) {
      const existingStudent = await User.findOne({ studentId });
      if (existingStudent) {
        return res.status(400).json({ message: 'Student ID already exists' });
      }
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const user = new User({
      username,
      email,
      password: hashedPassword,
      firstName: firstName || username,
      lastName: lastName || '',
      role: role || 'student',
      department: department || 'Information Technology',
      studentId,
      phoneNumber,
      isActive: true
    });

    await user.save();

    // Log activity
    await ActivityLog.logActivity(
      user._id,
      'user_created',
      'User account created by admin',
      { createdBy: req.userId },
      req
    );

    res.status(201).json({ 
      message: 'User created successfully', 
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   POST /api/admin/users/bulk-import
// @desc    Bulk import users from CSV/Excel file
// @access  Admin only
router.post('/users/bulk-import', auth, adminOnly, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(req.file.buffer);

    const worksheet = workbook.getWorksheet(1);
    const users = [];
    const errors = [];

    // Expected columns: username, email, password, firstName, lastName, role, department, studentId
    worksheet.eachRow((row, rowNumber) => {
      // Skip header row
      if (rowNumber === 1) return;

      const username = row.getCell(1).value;
      const email = row.getCell(2).value;
      const password = row.getCell(3).value;
      const firstName = row.getCell(4).value;
      const lastName = row.getCell(5).value;
      const role = row.getCell(6).value || 'student';
      const department = row.getCell(7).value || 'Information Technology';
      const studentId = row.getCell(8).value;

      if (!username || !email || !password) {
        errors.push({
          row: rowNumber,
          message: 'Missing required fields (username, email, password)'
        });
        return;
      }

      users.push({
        username,
        email,
        password,
        firstName,
        lastName,
        role,
        department,
        studentId
      });
    });

    // Bulk insert users
    const importResults = {
      total: users.length,
      successful: 0,
      failed: 0,
      errors: [...errors]
    };

    for (const userData of users) {
      try {
        // Check if user already exists
        const existingUser = await User.findOne({
          $or: [{ username: userData.username }, { email: userData.email }]
        });

        if (existingUser) {
          importResults.failed++;
          importResults.errors.push({
            username: userData.username,
            message: 'User already exists'
          });
          continue;
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(userData.password, 10);
        userData.password = hashedPassword;

        // Create user
        const user = new User(userData);
        await user.save();

        // Log activity
        await ActivityLog.logActivity(
          user._id,
          'account_created',
          `Account created via bulk import by admin`,
          { importedBy: req.userId },
          req
        );

        importResults.successful++;
      } catch (error) {
        importResults.failed++;
        importResults.errors.push({
          username: userData.username,
          message: error.message
        });
      }
    }

    res.json(importResults);
  } catch (error) {
    console.error('Error importing users:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/admin/users/:id/suspend
// @desc    Suspend user account
// @access  Admin only
router.put('/users/:id/suspend', auth, adminOnly, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.isActive = false;
    await user.save();

    // Log activity
    await ActivityLog.logActivity(
      user._id,
      'account_suspended',
      `Account suspended by admin`,
      { suspendedBy: req.userId },
      req
    );

    res.json({ message: 'User account suspended', user });
  } catch (error) {
    console.error('Error suspending user:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/admin/users/:id/activate
// @desc    Activate user account
// @access  Admin only
router.put('/users/:id/activate', auth, adminOnly, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.isActive = true;
    await user.save();

    // Log activity
    await ActivityLog.logActivity(
      user._id,
      'account_activated',
      `Account activated by admin`,
      { activatedBy: req.userId },
      req
    );

    res.json({ message: 'User account activated', user });
  } catch (error) {
    console.error('Error activating user:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/admin/users/:id/reset-password
// @desc    Reset user password (admin action)
// @access  Admin only
router.put('/users/:id/reset-password', auth, adminOnly, async (req, res) => {
  try {
    const { newPassword } = req.body;

    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.password = hashedPassword;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;
    await user.save();

    // Log activity
    await ActivityLog.logActivity(
      user._id,
      'password_change',
      `Password reset by admin`,
      { resetBy: req.userId },
      req
    );

    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    console.error('Error resetting password:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/admin/users/:id/permissions
// @desc    Update user permissions/role
// @access  Admin only
router.put('/users/:id/permissions', auth, adminOnly, async (req, res) => {
  try {
    const { role } = req.body;

    if (!['student', 'instructor', 'admin'].includes(role)) {
      return res.status(400).json({ message: 'Invalid role' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const oldRole = user.role;
    user.role = role;
    await user.save();

    // Log activity
    await ActivityLog.logActivity(
      user._id,
      'role_changed',
      `Role changed from ${oldRole} to ${role} by admin`,
      { changedBy: req.userId, oldRole, newRole: role },
      req
    );

    res.json({ message: 'User role updated', user });
  } catch (error) {
    console.error('Error updating permissions:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/admin/users/:id
// @desc    Update user profile information
// @access  Admin only
router.put('/users/:id', auth, adminOnly, async (req, res) => {
  try {
    const { firstName, lastName, email, username, role, isActive } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check if email is being changed and if it's already in use
    if (email && email !== user.email) {
      const emailExists = await User.findOne({ email, _id: { $ne: req.params.id } });
      if (emailExists) {
        return res.status(400).json({ message: 'Email already in use' });
      }
      user.email = email;
    }

    // Check if username is being changed and if it's already in use
    if (username && username !== user.username) {
      const usernameExists = await User.findOne({ username, _id: { $ne: req.params.id } });
      if (usernameExists) {
        return res.status(400).json({ message: 'Username already in use' });
      }
      user.username = username;
    }

    // Update other fields
    if (firstName !== undefined) user.firstName = firstName;
    if (lastName !== undefined) user.lastName = lastName;
    if (role && ['student', 'instructor', 'admin'].includes(role)) {
      user.role = role;
    }
    if (isActive !== undefined) user.isActive = isActive;

    await user.save();

    // Log activity
    await ActivityLog.logActivity(
      user._id,
      'profile_updated',
      'Profile updated by admin',
      { 
        changedBy: req.userId,
        changes: { firstName, lastName, email, username, role, isActive }
      },
      req
    );

    res.json({ message: 'User updated successfully', user });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/users/:id/activity-logs
// @desc    Get user activity logs
// @access  Admin only
router.get('/users/:id/activity-logs', auth, adminOnly, async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const logs = await ActivityLog.getUserActivity(
      req.params.id,
      parseInt(limit),
      skip
    );

    const total = await ActivityLog.countDocuments({ user: req.params.id });

    res.json({
      logs,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Error fetching activity logs:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/activity-logs
// @desc    Get all activity logs (system-wide)
// @access  Admin only
router.get('/activity-logs', auth, adminOnly, async (req, res) => {
  try {
    const {
      page = 1,
      limit = 50,
      action,
      userId,
      startDate,
      endDate
    } = req.query;

    let query = {};

    if (action) query.action = action;
    if (userId) query.user = userId;

    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const logs = await ActivityLog.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .skip(skip)
      .populate('user', 'fullName email role');

    const total = await ActivityLog.countDocuments(query);

    res.json({
      logs,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Error fetching activity logs:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/statistics/users
// @desc    Get user statistics
// @access  Admin only
router.get('/statistics/users', auth, adminOnly, async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const activeUsers = await User.countDocuments({ isActive: true });
    const inactiveUsers = await User.countDocuments({ isActive: false });

    const usersByRole = await User.aggregate([
      {
        $group: {
          _id: '$role',
          count: { $sum: 1 }
        }
      }
    ]);

    const usersByDepartment = await User.aggregate([
      {
        $group: {
          _id: '$department',
          count: { $sum: 1 }
        }
      },
      { $sort: { count: -1 } }
    ]);

    // Get user growth in last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const newUsersLast30Days = await User.countDocuments({
      createdAt: { $gte: thirtyDaysAgo }
    });

    res.json({
      totalUsers,
      activeUsers,
      inactiveUsers,
      usersByRole: usersByRole.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
      usersByDepartment,
      newUsersLast30Days
    });
  } catch (error) {
    console.error('Error fetching user statistics:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// ============ INSTRUCTOR ASSIGNMENT ROUTES ============

// @route   PUT /api/admin/courses/:id/assign-instructor
// @desc    Assign or reassign instructor to a course
// @access  Admin only
router.put('/courses/:id/assign-instructor', auth, adminOnly, async (req, res) => {
  try {
    const { instructorId } = req.body;

    if (!instructorId) {
      return res.status(400).json({ message: 'instructorId is required' });
    }

    // Validate instructor exists and has instructor role
    const instructor = await User.findById(instructorId);
    if (!instructor) {
      return res.status(400).json({ message: 'Instructor not found' });
    }

    if (instructor.role !== 'instructor' && instructor.role !== 'admin') {
      return res.status(400).json({ message: 'User must have instructor or admin role' });
    }

    // Update course
    const course = await Course.findById(req.params.id);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const oldInstructorId = course.instructor;
    course.instructor = instructorId;
    await course.save();

    // Log activity
    await ActivityLog.logActivity(
      instructorId,
      'other',
      `Assigned to course ${course.name} by admin`,
      { assignedBy: req.userId, courseId: course._id, oldInstructorId },
      req
    );

    await course.populate('instructor', 'fullName email profilePicture');

    res.json({ message: 'Instructor assigned successfully', course });
  } catch (error) {
    console.error('Error assigning instructor:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/instructors/workload
// @desc    Get instructor workload statistics
// @access  Admin only
router.get('/instructors/workload', auth, adminOnly, async (req, res) => {
  try {
    const instructors = await User.find({
      role: { $in: ['instructor', 'admin'] },
      isActive: true
    }).select('fullName email profilePicture department');

    const workloadData = [];

    for (const instructor of instructors) {
      const courses = await Course.find({ instructor: instructor._id })
        .select('name code students');

      let totalStudents = 0;
      const courseDetails = courses.map(course => {
        totalStudents += course.students.length;
        return {
          courseId: course._id,
          courseName: course.name,
          courseCode: course.code,
          studentCount: course.students.length
        };
      });

      workloadData.push({
        instructor: {
          id: instructor._id,
          fullName: instructor.fullName,
          email: instructor.email,
          profilePicture: instructor.profilePicture,
          department: instructor.department
        },
        totalCourses: courses.length,
        totalStudents,
        courses: courseDetails
      });
    }

    // Sort by total courses (descending)
    workloadData.sort((a, b) => b.totalCourses - a.totalCourses);

    res.json(workloadData);
  } catch (error) {
    console.error('Error fetching instructor workload:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/admin/instructors
// @desc    Get all instructors
// @access  Admin only
router.get('/instructors', auth, adminOnly, async (req, res) => {
  try {
    const instructors = await User.find({
      role: { $in: ['instructor', 'admin'] },
      isActive: true
    }).select('-password -resetPasswordToken -resetPasswordExpires');

    res.json(instructors);
  } catch (error) {
    console.error('Error fetching instructors:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
