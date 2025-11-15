const express = require('express');
const Message = require('../models/Message');
const User = require('../models/User');
const { authMiddleware } = require('../middleware/auth');
const { notifyPrivateMessage } = require('../utils/notificationHelper');

const router = express.Router();

// Get conversation with a specific user
router.get('/conversation/:userId', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const currentUserId = req.user.userId;
    
    // Get messages between current user and the other user
    const messages = await Message.find({
      $or: [
        { senderId: currentUserId, receiverId: userId },
        { senderId: userId, receiverId: currentUserId }
      ]
    })
    .populate('senderId', 'fullName avatar role username firstName lastName')
    .populate('receiverId', 'fullName avatar role username firstName lastName')
    .sort({ createdAt: 1 });
    
    // Transform messages to include senderName and senderAvatar
    const transformedMessages = messages.map(msg => {
      const msgObj = msg.toObject();
      if (msgObj.senderId && typeof msgObj.senderId === 'object') {
        msgObj.senderName = msgObj.senderId.fullName || msgObj.senderId.username || 'User';
        msgObj.senderAvatar = msgObj.senderId.avatar;
      }
      return msgObj;
    });
    
    // Mark messages from the other user as read
    await Message.updateMany(
      { senderId: userId, receiverId: currentUserId, isRead: false },
      { isRead: true, readAt: new Date() }
    );
    
    res.json(transformedMessages);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all conversations (list of users you've messaged)
router.get('/conversations', authMiddleware, async (req, res) => {
  try {
    const currentUserId = req.user.userId;
    
    // Find all unique users the current user has messaged or received messages from
    const messages = await Message.find({
      $or: [
        { senderId: currentUserId },
        { receiverId: currentUserId }
      ]
    })
    .populate('senderId', 'fullName avatar role')
    .populate('receiverId', 'fullName avatar role')
    .sort({ createdAt: -1 });
    
    // Create a map of conversations with the latest message
    const conversationsMap = new Map();
    
    messages.forEach(msg => {
      const otherUserId = msg.senderId._id.toString() === currentUserId 
        ? msg.receiverId._id.toString()
        : msg.senderId._id.toString();
      
      if (!conversationsMap.has(otherUserId)) {
        const otherUser = msg.senderId._id.toString() === currentUserId 
          ? msg.receiverId 
          : msg.senderId;
        
        conversationsMap.set(otherUserId, {
          user: otherUser,
          lastMessage: msg.content,
          lastMessageTime: msg.createdAt,
          isRead: msg.receiverId._id.toString() === currentUserId ? msg.isRead : true
        });
      }
    });
    
    const conversations = Array.from(conversationsMap.values());
    
    res.json(conversations);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Send a message
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { receiverId, content, attachments, fileId } = req.body; // Add fileId here
    const senderId = req.user.userId;
    
    // Validate that receiver exists
    const receiver = await User.findById(receiverId);
    if (!receiver) {
      return res.status(404).json({ message: 'Receiver not found' });
    }
    
    // Check permissions: students can only message instructors
    if (req.user.role === 'student' && receiver.role === 'student') {
      return res.status(403).json({ 
        message: 'Students can only message instructors' 
      });
    }
    
    const message = new Message({
      senderId,
      receiverId,
      content,
      fileId: fileId || null, // Add fileId to the message
      attachments: attachments || [],
      isRead: false
    });
    
    await message.save();
    
    // Populate sender and receiver details
    await message.populate('senderId', 'fullName avatar role username firstName lastName');
    await message.populate('receiverId', 'fullName avatar role username firstName lastName');
    
    // Transform message to include senderName and senderAvatar
    const msgObj = message.toObject();
    if (msgObj.senderId && typeof msgObj.senderId === 'object') {
      msgObj.senderName = msgObj.senderId.fullName || msgObj.senderId.username || 'User';
      msgObj.senderAvatar = msgObj.senderId.avatar;
    }
    
    // Send notification to receiver
    await notifyPrivateMessage(
      receiverId,
      msgObj.senderName,
      content
    );
    
    res.status(201).json(msgObj);
  } catch (error) {
    res.status(400).json({ message: 'Error sending message', error: error.message });
  }
});

// Mark message as read
router.put('/:id/read', authMiddleware, async (req, res) => {
  try {
    const message = await Message.findById(req.params.id);
    
    if (!message) {
      return res.status(404).json({ message: 'Message not found' });
    }
    
    // Only the receiver can mark a message as read
    if (message.receiverId.toString() !== req.user.userId) {
      return res.status(403).json({ message: 'Unauthorized' });
    }
    
    message.isRead = true;
    message.readAt = new Date();
    await message.save();
    
    res.json(message);
  } catch (error) {
    res.status(400).json({ message: 'Error marking message as read', error: error.message });
  }
});

// Get unread message count
router.get('/unread/count', authMiddleware, async (req, res) => {
  try {
    const count = await Message.countDocuments({
      receiverId: req.user.userId,
      isRead: false
    });
    
    res.json({ count });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
