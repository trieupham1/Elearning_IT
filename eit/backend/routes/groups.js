const express = require('express');
const Group = require('../models/Group');
const { authMiddleware, instructorOnly } = require('../middleware/auth');

const router = express.Router();

// Get groups by course
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.query;
    const groups = await Group.find({ courseId })
      .populate('members', 'firstName lastName fullName email studentId username');
    res.json(groups);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get single group
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id)
      .populate('members', 'firstName lastName fullName email studentId username');
    
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }
    
    res.json(group);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create group
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const group = new Group(req.body);
    await group.save();
    res.status(201).json(group);
  } catch (error) {
    res.status(400).json({ message: 'Error creating group', error: error.message });
  }
});

// Update group
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const group = await Group.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }
    
    res.json(group);
  } catch (error) {
    res.status(400).json({ message: 'Error updating group', error: error.message });
  }
});

// Assign students to group
router.post('/:groupId/students', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { studentIds } = req.body;
    const group = await Group.findById(req.params.groupId);
    
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }
    
    // Remove duplicates
    const newStudents = studentIds.filter(id => !group.members.includes(id));
    group.members.push(...newStudents);
    await group.save();
    
    res.json(group);
  } catch (error) {
    res.status(400).json({ message: 'Error assigning students', error: error.message });
  }
});

// Remove student from group
router.delete('/:groupId/students/:studentId', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }
    
    group.members = group.members.filter(id => id.toString() !== req.params.studentId);
    await group.save();
    
    res.json(group);
  } catch (error) {
    res.status(400).json({ message: 'Error removing student', error: error.message });
  }
});

// Delete group
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const group = await Group.findByIdAndDelete(req.params.id);
    
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }
    
    res.json({ message: 'Group deleted successfully' });
  } catch (error) {
    res.status(400).json({ message: 'Error deleting group', error: error.message });
  }
});

module.exports = router;