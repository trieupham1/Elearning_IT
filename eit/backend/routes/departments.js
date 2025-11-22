const express = require('express');
const router = express.Router();
const Department = require('../models/Department');
const User = require('../models/User');
const Course = require('../models/Course');
const { auth, adminOnly } = require('../middleware/auth');

// @route   GET /api/departments
// @desc    Get all departments (with optional filters)
// @access  Private
router.get('/', auth, async (req, res) => {
  try {
    const { isActive, search } = req.query;
    let query = {};

    if (isActive !== undefined) {
      query.isActive = isActive === 'true';
    }

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { code: { $regex: search, $options: 'i' } }
      ];
    }

    const departments = await Department.find(query)
      .populate('headOfDepartment', 'fullName email')
      .sort({ name: 1 });

    res.json(departments);
  } catch (error) {
    console.error('Error fetching departments:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/departments/:id
// @desc    Get department by ID with full details
// @access  Private
router.get('/:id', auth, async (req, res) => {
  try {
    const department = await Department.getDetailedDepartment(req.params.id);

    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    res.json(department);
  } catch (error) {
    console.error('Error fetching department:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   POST /api/departments
// @desc    Create new department
// @access  Admin only
router.post('/', auth, adminOnly, async (req, res) => {
  try {
    const { name, code, description, headOfDepartment } = req.body;

    // Validate required fields
    if (!name || !code) {
      return res.status(400).json({ message: 'Name and code are required' });
    }

    // Check if department code already exists
    const existingDept = await Department.findOne({ code: code.toUpperCase() });
    if (existingDept) {
      return res.status(400).json({ message: 'Department code already exists' });
    }

    // Validate head of department if provided
    if (headOfDepartment) {
      const user = await User.findById(headOfDepartment);
      if (!user) {
        return res.status(400).json({ message: 'Head of department user not found' });
      }
    }

    const department = new Department({
      name,
      code: code.toUpperCase(),
      description,
      headOfDepartment
    });

    await department.save();

    // Populate before sending response
    await department.populate('headOfDepartment', 'fullName email');

    res.status(201).json(department);
  } catch (error) {
    console.error('Error creating department:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/departments/:id
// @desc    Update department
// @access  Admin only
router.put('/:id', auth, adminOnly, async (req, res) => {
  try {
    const { name, code, description, headOfDepartment, isActive } = req.body;

    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Check if new code already exists (if code is being changed)
    if (code && code !== department.code) {
      const existingDept = await Department.findOne({ code: code.toUpperCase() });
      if (existingDept) {
        return res.status(400).json({ message: 'Department code already exists' });
      }
      department.code = code.toUpperCase();
    }

    if (name) department.name = name;
    if (description !== undefined) department.description = description;
    if (headOfDepartment !== undefined) department.headOfDepartment = headOfDepartment;
    if (isActive !== undefined) department.isActive = isActive;

    await department.save();
    await department.populate('headOfDepartment', 'fullName email');

    res.json(department);
  } catch (error) {
    console.error('Error updating department:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   DELETE /api/departments/:id
// @desc    Delete department (soft delete - set isActive to false)
// @access  Admin only
router.delete('/:id', auth, adminOnly, async (req, res) => {
  try {
    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Hard delete - permanently remove from database
    await Department.findByIdAndDelete(req.params.id);

    res.json({ message: 'Department deleted successfully' });
  } catch (error) {
    console.error('Error deleting department:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/departments/:id/assign-courses
// @desc    Assign courses to department
// @access  Admin only
router.put('/:id/assign-courses', auth, adminOnly, async (req, res) => {
  try {
    const { courseIds } = req.body;

    if (!Array.isArray(courseIds)) {
      return res.status(400).json({ message: 'courseIds must be an array' });
    }

    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Validate all course IDs exist
    const courses = await Course.find({ _id: { $in: courseIds } });
    if (courses.length !== courseIds.length) {
      return res.status(400).json({ message: 'One or more course IDs are invalid' });
    }

    // Assign courses
    department.courses = courseIds;
    await department.save();

    await department.populate('courses', 'title code description');
    res.json(department);
  } catch (error) {
    console.error('Error assigning courses:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   POST /api/departments/:id/add-course
// @desc    Add a single course to department
// @access  Admin only
router.post('/:id/add-course', auth, adminOnly, async (req, res) => {
  try {
    const { courseId } = req.body;

    if (!courseId) {
      return res.status(400).json({ message: 'courseId is required' });
    }

    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Validate course exists
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(400).json({ message: 'Course not found' });
    }

    await department.assignCourse(courseId);
    await department.populate('courses', 'title code description');

    res.json(department);
  } catch (error) {
    console.error('Error adding course:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   DELETE /api/departments/:id/remove-course/:courseId
// @desc    Remove a course from department
// @access  Admin only
router.delete('/:id/remove-course/:courseId', auth, adminOnly, async (req, res) => {
  try {
    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    await department.removeCourse(req.params.courseId);
    await department.populate('courses', 'title code description');

    res.json(department);
  } catch (error) {
    console.error('Error removing course:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   POST /api/departments/:id/auto-enroll
// @desc    Auto-enroll all department employees to assigned courses
// @access  Admin only
router.post('/:id/auto-enroll', auth, adminOnly, async (req, res) => {
  try {
    const department = await Department.findById(req.params.id)
      .populate('employees')
      .populate('courses');

    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    let enrollmentCount = 0;

    // Enroll each employee to each course
    for (const course of department.courses) {
      for (const employee of department.employees) {
        // Check if already enrolled
        if (!course.students.includes(employee._id)) {
          course.students.push(employee._id);
          enrollmentCount++;
        }
      }
      await course.save();
    }

    res.json({
      message: 'Auto-enrollment completed',
      enrollmentCount,
      employeesProcessed: department.employees.length,
      coursesProcessed: department.courses.length
    });
  } catch (error) {
    console.error('Error auto-enrolling:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   PUT /api/departments/:id/add-employee
// @desc    Add employee to department
// @access  Admin only
router.put('/:id/add-employee', auth, adminOnly, async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Validate user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(400).json({ message: 'User not found' });
    }

    // Update user's department field
    user.department = department.code;
    await user.save();

    // Add to department's employees
    await department.addEmployee(userId);
    await department.populate('employees', 'fullName email role');

    res.json(department);
  } catch (error) {
    console.error('Error adding employee:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// @route   GET /api/departments/:id/statistics
// @desc    Get department statistics
// @access  Admin only
router.get('/:id/statistics', auth, adminOnly, async (req, res) => {
  try {
    const department = await Department.findById(req.params.id)
      .populate('employees')
      .populate('courses');

    if (!department) {
      return res.status(404).json({ message: 'Department not found' });
    }

    // Calculate statistics
    const stats = {
      totalEmployees: department.employees.length,
      totalCourses: department.courses.length,
      employeesByRole: {},
      courseEnrollments: 0
    };

    // Count employees by role
    department.employees.forEach(emp => {
      stats.employeesByRole[emp.role] = (stats.employeesByRole[emp.role] || 0) + 1;
    });

    // Count total enrollments
    department.courses.forEach(course => {
      stats.courseEnrollments += course.students.length;
    });

    res.json(stats);
  } catch (error) {
    console.error('Error fetching statistics:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
