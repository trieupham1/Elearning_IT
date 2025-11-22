// routes/notifications.js
const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');
const Course = require('../models/Course');
const User = require('../models/User');
const auth = require('../middleware/auth');

// Get all notifications for current user
router.get('/', auth, async (req, res) => {
  try {
    const { unreadOnly } = req.query;
    const query = { userId: req.user.userId };
    
    if (unreadOnly === 'true') {
      query.isRead = false;
    }

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .limit(100); // Limit to last 100 notifications

    res.json(notifications);
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get unread count
router.get('/unread/count', auth, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user.userId,
      isRead: false
    });

    res.json({ count });
  } catch (error) {
    console.error('Error counting unread notifications:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Mark notification as read
router.put('/:id/read', auth, async (req, res) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.id,
      userId: req.user.userId
    });

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    await notification.markAsRead();
    res.json(notification);
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Mark all notifications as read
router.put('/read/all', auth, async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user.userId, isRead: false },
      { $set: { isRead: true, readAt: new Date() } }
    );

    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    console.error('Error marking all as read:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete notification
router.delete('/:id', auth, async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.userId
    });

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    res.json({ message: 'Notification deleted' });
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Send course invitation (instructor only)
router.post('/course-invitation', auth, async (req, res) => {
  try {
    const { courseId, studentIds, groupId } = req.body;

    // Verify the user is an instructor
    if (req.user.role !== 'instructor') {
      return res.status(403).json({ message: 'Only instructors can send course invitations' });
    }

    // Verify the course exists and belongs to the instructor
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'You are not the instructor of this course' });
    }

    // If groupId provided, verify it exists and belongs to this course
    let groupName = null;
    if (groupId) {
      const Group = require('../models/Group');
      const group = await Group.findById(groupId);
      if (!group) {
        return res.status(404).json({ message: 'Group not found' });
      }
      if (group.courseId.toString() !== courseId) {
        return res.status(400).json({ message: 'Group does not belong to this course' });
      }
      groupName = group.name;
    }

    // Create notifications for all students
    const notifications = studentIds.map(studentId => ({
      userId: studentId,
      type: 'course_invite',
      title: 'Course Invitation',
      message: groupId 
        ? `You have been invited to join ${course.name} (${groupName})`
        : `You have been invited to join ${course.name}`,
      data: {
        courseId: course._id,
        courseName: course.name,
        courseCode: course.code,
        instructorId: req.user.userId,
        instructorName: req.user.fullName || req.user.username,
        groupId: groupId || null,
        groupName: groupName || null
      }
    }));

    const createdNotifications = await Notification.createBulkNotifications(notifications);

    res.json({
      message: 'Invitations sent successfully',
      count: createdNotifications.length
    });
  } catch (error) {
    console.error('Error sending course invitations:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Respond to course invitation (student only)
router.post('/:id/respond', auth, async (req, res) => {
  try {
    const { accept } = req.body;
    const notificationId = req.params.id;

    // Find the notification
    const notification = await Notification.findOne({
      _id: notificationId,
      userId: req.user.userId,
      type: 'course_invite'
    });

    if (!notification) {
      return res.status(404).json({ message: 'Course invitation not found' });
    }

    const { courseId, instructorId } = notification.data;

    // Fetch the student's user details
    const student = await User.findById(req.user.userId);
    if (!student) {
      return res.status(404).json({ message: 'Student not found' });
    }

    const studentName = student.fullName || student.username || 'A student';

    if (accept) {
      // Add student to the course
      const course = await Course.findById(courseId);
      if (!course) {
        return res.status(404).json({ message: 'Course not found' });
      }

      // Check if student is already enrolled
      if (!course.students.includes(req.user.userId)) {
        course.students.push(req.user.userId);
        await course.save();
      }

      // If invitation has groupId, add student to the group
      if (notification.data.groupId) {
        const Group = require('../models/Group');
        const group = await Group.findById(notification.data.groupId);
        if (group && !group.members.includes(req.user.userId)) {
          group.members.push(req.user.userId);
          await group.save();
        }
      }

      // Mark notification as read
      await notification.markAsRead();

      // Notify instructor that student accepted
      await Notification.createNotification({
        userId: instructorId,
        type: 'message',
        title: 'Course Invitation Accepted',
        message: `${studentName} has accepted your invitation to join ${course.name}`,
        data: {
          courseId: course._id,
          courseName: course.name,
          studentId: req.user.userId,
          studentName: studentName
        }
      });

      res.json({
        message: 'Course invitation accepted',
        course: course
      });
    } else {
      // Mark notification as read
      await notification.markAsRead();

      // Notify instructor that student declined
      await Notification.createNotification({
        userId: instructorId,
        type: 'message',
        title: 'Course Invitation Declined',
        message: `${studentName} has declined your invitation to join ${notification.data.courseName}`,
        data: {
          courseId: courseId,
          courseName: notification.data.courseName,
          studentId: req.user.userId,
          studentName: studentName
        }
      });

      res.json({ message: 'Course invitation declined' });
    }
  } catch (error) {
    console.error('Error responding to course invitation:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create a notification (for testing or manual creation)
router.post('/', auth, async (req, res) => {
  try {
    const { userId, type, title, message, data } = req.body;

    const notification = await Notification.createNotification({
      userId: userId || req.user.userId,
      type,
      title,
      message,
      data: data || {}
    });

    res.status(201).json(notification);
  } catch (error) {
    console.error('Error creating notification:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
