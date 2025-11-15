// routes/forum.js
const express = require('express');
const router = express.Router();
const ForumTopic = require('../models/ForumTopic');
const ForumReply = require('../models/ForumReply');
const User = require('../models/User');
const Course = require('../models/Course');
const authMiddleware = require('../middleware/auth');

// Get all topics for a course
router.get('/course/:courseId/topics', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.params;
    const { search, sortBy = 'recent', page = 1, limit = 20 } = req.query;

    const query = { courseId };

    // Add search if provided
    if (search) {
      query.$text = { $search: search };
    }

    // Determine sort order
    let sort = {};
    switch (sortBy) {
      case 'recent':
        sort = { isPinned: -1, lastActivityAt: -1 };
        break;
      case 'popular':
        sort = { isPinned: -1, views: -1 };
        break;
      case 'mostReplies':
        sort = { isPinned: -1, replyCount: -1 };
        break;
      case 'mostLikes':
        sort = { isPinned: -1, likes: -1 };
        break;
      default:
        sort = { isPinned: -1, lastActivityAt: -1 };
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [topics, total] = await Promise.all([
      ForumTopic.find(query)
        .sort(sort)
        .skip(skip)
        .limit(parseInt(limit))
        .select('-__v'),
      ForumTopic.countDocuments(query)
    ]);

    res.json({
      topics,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error fetching topics:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get a single topic with details
router.get('/topics/:topicId', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;

    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    // Increment view count
    topic.views += 1;
    await topic.save();

    res.json(topic);
  } catch (error) {
    console.error('Error fetching topic:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create a new topic
router.post('/course/:courseId/topics', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.params;
    const { title, content, attachments, tags } = req.body;
    const userId = req.user.userId;

    // Get user details
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Verify user is enrolled in the course
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const isEnrolled = course.instructor.toString() === userId || 
                      course.students.some(s => s.toString() === userId);

    if (!isEnrolled) {
      return res.status(403).json({ message: 'You are not enrolled in this course' });
    }

    const newTopic = new ForumTopic({
      courseId,
      authorId: userId,
      authorName: user.fullName || user.username || user.email,
      authorRole: user.role,
      title,
      content,
      attachments: attachments || [],
      tags: tags || [],
      lastActivityAt: new Date()
    });

    await newTopic.save();
    res.status(201).json(newTopic);
  } catch (error) {
    console.error('Error creating topic:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update a topic
router.put('/topics/:topicId', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;
    const { title, content, attachments, tags } = req.body;
    const userId = req.user.userId;

    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    // Only author can edit
    if (topic.authorId.toString() !== userId) {
      return res.status(403).json({ message: 'You can only edit your own topics' });
    }

    if (title) topic.title = title;
    if (content !== undefined) topic.content = content;
    if (attachments) topic.attachments = attachments;
    if (tags) topic.tags = tags;

    await topic.save();
    res.json(topic);
  } catch (error) {
    console.error('Error updating topic:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete a topic
router.delete('/topics/:topicId', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;
    const userId = req.user.userId;

    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    // Check if user is author or instructor
    const user = await User.findById(userId);
    const isAuthor = topic.authorId.toString() === userId;
    const isInstructor = user.role === 'instructor';

    if (!isAuthor && !isInstructor) {
      return res.status(403).json({ message: 'You do not have permission to delete this topic' });
    }

    // Delete all replies for this topic
    await ForumReply.deleteMany({ topicId });
    
    // Delete the topic
    await ForumTopic.findByIdAndDelete(topicId);

    res.json({ message: 'Topic deleted successfully' });
  } catch (error) {
    console.error('Error deleting topic:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Toggle like on a topic
router.post('/topics/:topicId/like', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;
    const userId = req.user.userId;

    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    const likeIndex = topic.likes.indexOf(userId);
    
    if (likeIndex > -1) {
      // Unlike
      topic.likes.splice(likeIndex, 1);
    } else {
      // Like
      topic.likes.push(userId);
    }

    await topic.save();
    res.json({ likes: topic.likes.length, isLiked: likeIndex === -1 });
  } catch (error) {
    console.error('Error toggling like:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Pin/Unpin a topic (instructors only)
router.post('/topics/:topicId/pin', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (user.role !== 'instructor') {
      return res.status(403).json({ message: 'Only instructors can pin topics' });
    }

    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    topic.isPinned = !topic.isPinned;
    await topic.save();

    res.json({ isPinned: topic.isPinned });
  } catch (error) {
    console.error('Error pinning topic:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Lock/Unlock a topic (instructors only)
router.post('/topics/:topicId/lock', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (user.role !== 'instructor') {
      return res.status(403).json({ message: 'Only instructors can lock topics' });
    }

    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    topic.isLocked = !topic.isLocked;
    await topic.save();

    res.json({ isLocked: topic.isLocked });
  } catch (error) {
    console.error('Error locking topic:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all replies for a topic
router.get('/topics/:topicId/replies', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;

    const replies = await ForumReply.find({ topicId })
      .sort({ createdAt: 1 })
      .select('-__v');

    res.json(replies);
  } catch (error) {
    console.error('Error fetching replies:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create a reply
router.post('/topics/:topicId/replies', authMiddleware, async (req, res) => {
  try {
    const { topicId } = req.params;
    const { content, parentReplyId, attachments } = req.body;
    const userId = req.user.userId;

    // Check if topic exists and is not locked
    const topic = await ForumTopic.findById(topicId);
    if (!topic) {
      return res.status(404).json({ message: 'Topic not found' });
    }

    if (topic.isLocked) {
      return res.status(403).json({ message: 'This topic is locked' });
    }

    // Get user details
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const newReply = new ForumReply({
      topicId,
      authorId: userId,
      authorName: user.fullName || user.username || user.email,
      authorRole: user.role,
      content,
      parentReplyId: parentReplyId || null,
      attachments: attachments || []
    });

    await newReply.save();

    // Update topic reply count and last activity
    topic.replyCount += 1;
    topic.lastActivityAt = new Date();
    await topic.save();

    res.status(201).json(newReply);
  } catch (error) {
    console.error('Error creating reply:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update a reply
router.put('/replies/:replyId', authMiddleware, async (req, res) => {
  try {
    const { replyId } = req.params;
    const { content, attachments } = req.body;
    const userId = req.user.userId;

    const reply = await ForumReply.findById(replyId);
    if (!reply) {
      return res.status(404).json({ message: 'Reply not found' });
    }

    // Only author can edit
    if (reply.authorId.toString() !== userId) {
      return res.status(403).json({ message: 'You can only edit your own replies' });
    }

    if (content) reply.content = content;
    if (attachments) reply.attachments = attachments;
    reply.isEdited = true;
    reply.editedAt = new Date();

    await reply.save();
    res.json(reply);
  } catch (error) {
    console.error('Error updating reply:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete a reply
router.delete('/replies/:replyId', authMiddleware, async (req, res) => {
  try {
    const { replyId } = req.params;
    const userId = req.user.userId;

    const reply = await ForumReply.findById(replyId);
    if (!reply) {
      return res.status(404).json({ message: 'Reply not found' });
    }

    // Check if user is author or instructor
    const user = await User.findById(userId);
    const isAuthor = reply.authorId.toString() === userId;
    const isInstructor = user.role === 'instructor';

    if (!isAuthor && !isInstructor) {
      return res.status(403).json({ message: 'You do not have permission to delete this reply' });
    }

    // Delete child replies (if any)
    await ForumReply.deleteMany({ parentReplyId: replyId });

    // Delete the reply
    await ForumReply.findByIdAndDelete(replyId);

    // Update topic reply count
    const topic = await ForumTopic.findById(reply.topicId);
    if (topic) {
      const remainingReplies = await ForumReply.countDocuments({ topicId: topic._id });
      topic.replyCount = remainingReplies;
      await topic.save();
    }

    res.json({ message: 'Reply deleted successfully' });
  } catch (error) {
    console.error('Error deleting reply:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Toggle like on a reply
router.post('/replies/:replyId/like', authMiddleware, async (req, res) => {
  try {
    const { replyId } = req.params;
    const userId = req.user.userId;

    const reply = await ForumReply.findById(replyId);
    if (!reply) {
      return res.status(404).json({ message: 'Reply not found' });
    }

    const likeIndex = reply.likes.indexOf(userId);
    
    if (likeIndex > -1) {
      // Unlike
      reply.likes.splice(likeIndex, 1);
    } else {
      // Like
      reply.likes.push(userId);
    }

    await reply.save();
    res.json({ likes: reply.likes.length, isLiked: likeIndex === -1 });
  } catch (error) {
    console.error('Error toggling like:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
