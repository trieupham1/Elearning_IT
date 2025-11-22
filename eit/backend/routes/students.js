const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { authMiddleware, instructorOnly } = require('../middleware/auth');

const router = express.Router();

// Get all students
router.get('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const students = await User.find({ role: 'student' })
      .select('-password')
      .sort({ createdAt: -1 });
    res.json(students);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get single student
router.get('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const student = await User.findById(req.params.id)
      .select('-password');
    
    if (!student || student.role !== 'student') {
      return res.status(404).json({ message: 'Student not found' });
    }
    
    res.json(student);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create student
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { username, password, firstName, lastName, email, studentId, phoneNumber, department, year } = req.body;
    
    // Validation
    if (!username || !email || !firstName || !lastName || !studentId) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    // Check if student exists
    const existing = await User.findOne({ 
      $or: [
        { username }, 
        { email },
        { studentId }
      ] 
    });
    
    if (existing) {
      if (existing.username === username) {
        return res.status(400).json({ message: 'Username already exists' });
      }
      if (existing.email === email) {
        return res.status(400).json({ message: 'Email already exists' });
      }
      if (existing.studentId === studentId) {
        return res.status(400).json({ message: 'Student ID already exists' });
      }
    }
    
    // Hash password (default if not provided)
    const hashedPassword = await bcrypt.hash(password || 'student123', 10);
    
    const student = new User({
      username,
      password: hashedPassword,
      firstName,
      lastName,
      email,
      studentId,
      phoneNumber,
      department: department || 'Information Technology',
      year,
      role: 'student'
    });
    
    await student.save();
    
    const studentObj = student.toObject();
    delete studentObj.password;
    
    res.status(201).json(studentObj);
  } catch (error) {
    res.status(400).json({ message: 'Error creating student', error: error.message });
  }
});

// Update student
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { email, phoneNumber, password, year, bio } = req.body;
    
    const student = await User.findById(req.params.id);
    
    if (!student || student.role !== 'student') {
      return res.status(404).json({ message: 'Student not found' });
    }

    // Check email uniqueness if changing
    if (email && email !== student.email) {
      const emailExists = await User.findOne({ email, _id: { $ne: req.params.id } });
      if (emailExists) {
        return res.status(400).json({ message: 'Email already exists' });
      }
      student.email = email;
    }

    // Update allowed fields
    if (phoneNumber !== undefined) student.phoneNumber = phoneNumber;
    if (year !== undefined) student.year = year;
    if (bio !== undefined) student.bio = bio;
    
    // Hash new password if provided
    if (password) {
      student.password = await bcrypt.hash(password, 10);
    }
    
    await student.save();
    
    const studentObj = student.toObject();
    delete studentObj.password;
    
    res.json(studentObj);
  } catch (error) {
    res.status(400).json({ message: 'Error updating student', error: error.message });
  }
});

// CSV Import Preview - validates data and checks for duplicates
router.post('/import/preview', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { students } = req.body;
    
    if (!Array.isArray(students) || students.length === 0) {
      return res.status(400).json({ message: 'Invalid data: students array required' });
    }

    const preview = [];
    let rowNumber = 1;

    for (const studentData of students) {
      const item = {
        rowNumber,
        data: studentData,
        status: 'willBeAdded',
        message: null
      };

      // Validation
      if (!studentData.username || !studentData.email || !studentData.firstName || 
          !studentData.lastName || !studentData.studentId) {
        item.status = 'error';
        item.message = 'Missing required fields';
      } else if (!studentData.email.includes('@')) {
        item.status = 'error';
        item.message = 'Invalid email format';
      } else {
        // Check for duplicates
        const existing = await User.findOne({
          $or: [
            { username: studentData.username },
            { email: studentData.email },
            { studentId: studentData.studentId }
          ]
        });

        if (existing) {
          item.status = 'alreadyExists';
          if (existing.username === studentData.username) {
            item.message = 'Username already exists';
          } else if (existing.email === studentData.email) {
            item.message = 'Email already exists';
          } else if (existing.studentId === studentData.studentId) {
            item.message = 'Student ID already exists';
          }
        }
      }

      preview.push(item);
      rowNumber++;
    }

    // Calculate statistics
    const stats = {
      total: preview.length,
      willAdd: preview.filter(i => i.status === 'willBeAdded').length,
      exists: preview.filter(i => i.status === 'alreadyExists').length,
      errors: preview.filter(i => i.status === 'error').length
    };

    res.json({
      success: true,
      preview,
      stats
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// CSV Import Confirm - actually imports the validated data
router.post('/import/confirm', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { items } = req.body; // Items from preview with status
    
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'Invalid data: items array required' });
    }

    const results = {
      totalRows: items.length,
      added: 0,
      skipped: 0,
      errors: 0,
      items: []
    };

    for (const item of items) {
      // Only import items marked as 'willBeAdded'
      if (item.status === 'willBeAdded') {
        try {
          const hashedPassword = await bcrypt.hash(
            item.data.password || 'student123', 
            10
          );
          
          const student = new User({
            username: item.data.username,
            password: hashedPassword,
            firstName: item.data.firstName,
            lastName: item.data.lastName,
            email: item.data.email,
            studentId: item.data.studentId,
            phoneNumber: item.data.phoneNumber,
            department: item.data.department || 'Information Technology',
            year: item.data.year,
            role: 'student'
          });
          
          await student.save();
          results.added++;
          results.items.push({
            ...item,
            status: 'added',
            message: 'Successfully added'
          });
        } catch (error) {
          results.errors++;
          results.items.push({
            ...item,
            status: 'error',
            message: error.message
          });
        }
      } else {
        // Skip items that already exist or have errors
        results.skipped++;
        results.items.push({
          ...item,
          status: 'skipped'
        });
      }
    }

    res.json({
      success: true,
      ...results
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete student
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const student = await User.findById(req.params.id);
    
    if (!student || student.role !== 'student') {
      return res.status(404).json({ message: 'Student not found' });
    }
    
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: 'Student deleted successfully' });
  } catch (error) {
    res.status(400).json({ message: 'Error deleting student', error: error.message });
  }
});

module.exports = router;