const express = require('express');
const router = express.Router();
const Semester = require('../models/Semester');
const Course = require('../models/Course');
const Group = require('../models/Group');
const Assignment = require('../models/Assignment');
const Quiz = require('../models/Quiz');
const auth = require('../middleware/auth');

// Get semester statistics
router.get('/:id/statistics', auth, async (req, res) => {
  try {
    const semester = await Semester.findById(req.params.id);
    
    if (!semester) {
      return res.status(404).json({ message: 'Semester not found' });
    }

    // Get all courses for this semester
    const courses = await Course.find({ semester: req.params.id });
    const courseIds = courses.map(c => c._id);

    // Get all groups for these courses
    const groups = await Group.find({ course: { $in: courseIds } });

    // Get unique students across all courses
    const allStudents = new Set();
    courses.forEach(course => {
      if (course.students && Array.isArray(course.students)) {
        course.students.forEach(student => {
          allStudents.add(student.toString());
        });
      }
    });

    // Get assignments and quizzes
    const assignments = await Assignment.find({ course: { $in: courseIds } });
    const quizzes = await Quiz.find({ course: { $in: courseIds } });

    res.json({
      semesterId: semester._id,
      semesterName: semester.displayName,
      courses: courses.length,
      groups: groups.length,
      students: allStudents.size,
      assignments: assignments.length,
      quizzes: quizzes.length,
    });
  } catch (error) {
    console.error('Get semester statistics error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get all semesters
router.get('/', auth, async (req, res) => {
  try {
    const semesters = await Semester.find().sort({ year: -1, name: -1 });
    res.json(semesters);
  } catch (error) {
    console.error('Get semesters error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get single semester
router.get('/:id', auth, async (req, res) => {
  try {
    const semester = await Semester.findById(req.params.id);
    
    if (!semester) {
      return res.status(404).json({ message: 'Semester not found' });
    }
    
    res.json(semester);
  } catch (error) {
    console.error('Get semester error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Create semester (admin only)
router.post('/', auth, async (req, res) => {
  try {
    if (req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Only admins can create semesters' });
    }

    const semester = await Semester.create(req.body);
    res.status(201).json(semester);
  } catch (error) {
    console.error('Create semester error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Update semester (admin only)
router.put('/:id', auth, async (req, res) => {
  try {
    if (req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Only admins can update semesters' });
    }

    const semester = await Semester.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );

    if (!semester) {
      return res.status(404).json({ message: 'Semester not found' });
    }

    res.json(semester);
  } catch (error) {
    console.error('Update semester error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Activate semester (admin only) - Sets this semester as active and deactivates all others
router.put('/:id/activate', auth, async (req, res) => {
  try {
    if (req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Only admins can activate semesters' });
    }

    // Deactivate all other semesters
    await Semester.updateMany({}, { isActive: false });

    // Activate the specified semester
    const semester = await Semester.findByIdAndUpdate(
      req.params.id,
      { isActive: true },
      { new: true }
    );

    if (!semester) {
      return res.status(404).json({ message: 'Semester not found' });
    }

    res.json(semester);
  } catch (error) {
    console.error('Activate semester error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Delete semester (admin only)
router.delete('/:id', auth, async (req, res) => {
  try {
    if (req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Only admins can delete semesters' });
    }

    const semester = await Semester.findByIdAndDelete(req.params.id);
    
    if (!semester) {
      return res.status(404).json({ message: 'Semester not found' });
    }

    res.json({ message: 'Semester deleted successfully' });
  } catch (error) {
    console.error('Delete semester error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;