const express = require('express');
const router = express.Router();
const Course = require('../models/Course');
const User = require('../models/User');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');

// Get available courses (for students to browse and join)
router.get('/available', auth, async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Only students can browse available courses' });
    }

    const { semesterId, semester } = req.query;
    const semesterFilter = semesterId || semester;
    let query = semesterFilter ? { semester: semesterFilter } : {};
    
    // Get courses where student is NOT enrolled
    query.students = { $ne: req.user.userId };
    
    console.log('Fetching available courses with query:', query);
    
    const courses = await Course.find(query)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'semester',
        select: 'name year isActive',
        strictPopulate: false
      })
      .populate({
        path: 'students',
        select: '_id',
        strictPopulate: false
      });
    
    // Only show courses from active semesters
    const activeCourses = courses.filter(course => course.semester && course.semester.isActive);
    
    console.log(`Found ${activeCourses.length} available courses for student`);
    
    res.json(activeCourses);
  } catch (error) {
    console.error('Get available courses error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get all courses
router.get('/', auth, async (req, res) => {
  try {
    const { semesterId, semester } = req.query;
    // Support both 'semesterId' and 'semester' query parameters
    const semesterFilter = semesterId || semester;
    let query = semesterFilter ? { semester: semesterFilter } : {};
    
    // Filter courses based on user role
    if (req.user.role === 'student') {
      // Students only see courses they're enrolled in
      query.students = req.user.userId;
    } else if (req.user.role === 'instructor') {
      // Instructors only see courses they teach
      query.instructor = req.user.userId;
    }
    // Admin sees all courses (no additional filter)
    
    console.log('Fetching courses with query:', query, 'for user role:', req.user.role);
    
    const courses = await Course.find(query)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'semester',
        select: 'name year',
        strictPopulate: false
      })
      .populate({
        path: 'students',
        select: '_id username email firstName lastName studentId',
        strictPopulate: false
      });
    
    console.log(`Found ${courses.length} courses for ${req.user.role}`);
    
    res.json(courses);
  } catch (error) {
    console.error('Get courses error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get single course
router.get('/:id', auth, async (req, res) => {
  try {
    const course = await Course.findById(req.params.id)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'semester',
        select: 'name year',
        strictPopulate: false
      })
      .populate({
        path: 'students',
        select: 'username email firstName lastName studentId',
        strictPopulate: false
      });
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    res.json(course);
  } catch (error) {
    console.error('Get course error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Create course (instructor only)
router.post('/', auth, async (req, res) => {
  try {
    if (req.userRole !== 'instructor' && req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Only instructors can create courses' });
    }

    const course = await Course.create({
      ...req.body,
      instructor: req.userId
    });

    const populatedCourse = await Course.findById(course._id)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'semester',
        select: 'name year',
        strictPopulate: false
      });

    res.status(201).json(populatedCourse);
  } catch (error) {
    console.error('Create course error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Request to join course (student sends request to instructor)
router.post('/:id/join', auth, async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Only students can request to join courses' });
    }

    const { groupId } = req.body;

    const course = await Course.findById(req.params.id)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      });
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    // Check if already enrolled
    if (course.students.includes(req.user.userId)) {
      return res.status(400).json({ message: 'Already enrolled in this course' });
    }

    // If groupId provided, verify it exists and belongs to this course
    let groupName = null;
    if (groupId) {
      const Group = require('../models/Group');
      const group = await Group.findById(groupId);
      if (!group) {
        return res.status(404).json({ message: 'Group not found' });
      }
      if (group.courseId.toString() !== req.params.id) {
        return res.status(400).json({ message: 'Group does not belong to this course' });
      }
      groupName = group.name;
    }

    // Get student details
    const student = await User.findById(req.user.userId);
    if (!student) {
      return res.status(404).json({ message: 'Student not found' });
    }

    const studentName = student.fullName || student.username || 'A student';

    // Check if there's already a pending request
    const existingRequest = await Notification.findOne({
      userId: course.instructor,
      type: 'course_join_request',
      'data.courseId': course._id,
      'data.studentId': req.user.userId,
      isRead: false
    });

    if (existingRequest) {
      return res.status(400).json({ message: 'You already have a pending request for this course' });
    }

    // Send notification to instructor
    await Notification.createNotification({
      userId: course.instructor,
      type: 'course_join_request',
      title: 'Course Join Request',
      message: groupId 
        ? `${studentName} has requested to join ${course.name} (${groupName})`
        : `${studentName} has requested to join ${course.name}`,
      data: {
        courseId: course._id,
        courseName: course.name,
        courseCode: course.code,
        studentId: req.user.userId,
        studentName: studentName,
        studentEmail: student.email,
        groupId: groupId || null,
        groupName: groupName || null
      }
    });

    res.json({ message: 'Join request sent successfully. Waiting for instructor approval.' });
  } catch (error) {
    console.error('Join course request error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Approve or decline join request (instructor only)
router.post('/:id/join-request/:notificationId/respond', auth, async (req, res) => {
  try {
    if (req.user.role !== 'instructor') {
      return res.status(403).json({ message: 'Only instructors can approve join requests' });
    }

    const { approve } = req.body;
    const { id: courseId, notificationId } = req.params;

    // Find the notification
    const notification = await Notification.findOne({
      _id: notificationId,
      userId: req.user.userId,
      type: 'course_join_request'
    });

    if (!notification) {
      return res.status(404).json({ message: 'Join request not found' });
    }

    const { studentId, studentName, courseName } = notification.data;

    // Find the course
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    // Verify instructor owns this course
    if (course.instructor.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'You are not the instructor of this course' });
    }

    if (approve) {
      // Check if student is already enrolled
      if (!course.students.includes(studentId)) {
        course.students.push(studentId);
        await course.save();
      }

      // If join request has groupId, add student to the group
      if (notification.data.groupId) {
        const Group = require('../models/Group');
        const group = await Group.findById(notification.data.groupId);
        if (group && !group.members.includes(studentId)) {
          group.members.push(studentId);
          await group.save();
        }
      }

      // Mark notification as read
      await notification.markAsRead();

      // Notify student that request was approved
      await Notification.createNotification({
        userId: studentId,
        type: 'message',
        title: 'Join Request Approved',
        message: `Your request to join ${courseName} has been approved!`,
        data: {
          courseId: course._id,
          courseName: courseName
        }
      });

      res.json({ message: 'Join request approved', course });
    } else {
      // Mark notification as read
      await notification.markAsRead();

      // Notify student that request was declined
      await Notification.createNotification({
        userId: studentId,
        type: 'message',
        title: 'Join Request Declined',
        message: `Your request to join ${courseName} has been declined.`,
        data: {
          courseId: course._id,
          courseName: courseName
        }
      });

      res.json({ message: 'Join request declined' });
    }
  } catch (error) {
    console.error('Respond to join request error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Update course
router.put('/:id', auth, async (req, res) => {
  try {
    const course = await Course.findById(req.params.id);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    if (course.instructor.toString() !== req.userId && req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Not authorized to update this course' });
    }

    const updatedCourse = await Course.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    )
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'semester',
        select: 'name year',
        strictPopulate: false
      });

    res.json(updatedCourse);
  } catch (error) {
    console.error('Update course error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Delete course
router.delete('/:id', auth, async (req, res) => {
  try {
    const course = await Course.findById(req.params.id);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    if (course.instructor.toString() !== req.userId && req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Not authorized to delete this course' });
    }

    await Course.findByIdAndDelete(req.params.id);
    res.json({ message: 'Course deleted successfully' });
  } catch (error) {
    console.error('Delete course error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Enroll student in course
router.post('/:id/enroll', auth, async (req, res) => {
  try {
    const course = await Course.findById(req.params.id);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const studentId = req.body.studentId || req.userId;

    if (course.students.includes(studentId)) {
      return res.status(400).json({ message: 'Student already enrolled' });
    }

    course.students.push(studentId);
    await course.save();

    const updatedCourse = await Course.findById(course._id)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'students',
        select: 'username email firstName lastName studentId',
        strictPopulate: false
      });

    res.json(updatedCourse);
  } catch (error) {
    console.error('Enroll student error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Unenroll student from course
router.post('/:id/unenroll', auth, async (req, res) => {
  try {
    const course = await Course.findById(req.params.id);
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const studentId = req.body.studentId || req.userId;

    course.students = course.students.filter(
      id => id.toString() !== studentId
    );
    await course.save();

    const updatedCourse = await Course.findById(course._id)
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'students',
        select: 'username email firstName lastName studentId',
        strictPopulate: false
      });

    res.json(updatedCourse);
  } catch (error) {
    console.error('Unenroll student error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get courses for a specific instructor
router.get('/instructor/:instructorId', auth, async (req, res) => {
  try {
    const courses = await Course.find({ instructor: req.params.instructorId })
      .populate({
        path: 'instructor',
        select: 'username email firstName lastName',
        strictPopulate: false
      })
      .populate({
        path: 'semester',
        select: 'name year',
        strictPopulate: false
      });
    
    res.json(courses);
  } catch (error) {
    console.error('Get instructor courses error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get people in a course (instructors and students)
router.get('/:id/people', auth, async (req, res) => {
  try {
    const course = await Course.findById(req.params.id)
      .populate({
        path: 'instructor',
        select: 'username email avatar role firstName lastName profilePicture studentId',
        strictPopulate: false
      })
      .populate({
        path: 'students',
        select: 'username email avatar role firstName lastName profilePicture studentId',
        strictPopulate: false
      });
    
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    // Transform users to ensure they have proper name fields
    const transformUser = (user) => {
      if (!user) return null;
      const userObj = user.toObject ? user.toObject() : user;
      
      // Ensure firstName and lastName exist
      if (!userObj.firstName || !userObj.lastName) {
        // Try to extract from email (e.g., nguyenvanan@student -> nguyen van an)
        const emailPart = userObj.email ? userObj.email.split('@')[0] : '';
        
        if (emailPart && !userObj.firstName && !userObj.lastName) {
          // Simple extraction: assume format like "nguyenvanan"
          // In Vietnamese names, typically last name is first part
          const cleaned = emailPart.replace(/[^a-z]/gi, '');
          if (cleaned.length > 4) {
            userObj.lastName = cleaned.substring(0, 1).toUpperCase() + cleaned.substring(1, 4);
            userObj.firstName = cleaned.substring(4, 5).toUpperCase() + cleaned.substring(5);
          } else {
            userObj.firstName = userObj.username || 'User';
            userObj.lastName = '';
          }
        }
      }
      
      return userObj;
    };
    
    const instructors = course.instructor ? [transformUser(course.instructor)] : [];
    const students = (course.students || []).map(transformUser).filter(Boolean);
    
    res.json({
      instructors,
      students
    });
  } catch (error) {
    console.error('Get course people error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;