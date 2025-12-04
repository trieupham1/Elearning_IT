const express = require('express');
const Announcement = require('../models/Announcement');
const Course = require('../models/Course');
const Group = require('../models/Group');
const Notification = require('../models/Notification');
const User = require('../models/User');
const { authMiddleware, instructorOnly } = require('../middleware/auth');
const { notifyNewAnnouncement, notifyNewComment } = require('../utils/notificationHelper');

const router = express.Router();

// Helper function to transform attachments from DB format to API format
function transformAttachments(attachments) {
  if (!attachments || !Array.isArray(attachments)) return [];
  return attachments.map(att => ({
    name: att.fileName || att.name || '',
    url: att.fileUrl || att.url || '',
    size: att.fileSize || att.size || 0,
    mimeType: att.mimeType
  }));
}

// Helper function to transform attachments from API format to DB format
function transformAttachmentsToDb(attachments) {
  if (!attachments || !Array.isArray(attachments)) return [];
  return attachments.map(att => ({
    fileName: att.name || att.fileName || '',
    fileUrl: att.url || att.fileUrl || '',
    fileSize: att.size || att.fileSize || 0,
    mimeType: att.mimeType
  }));
}

// Get announcements by course
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.query;
    
    let query = { courseId };
    
    if (req.user.role === 'student') {
      // Get student's groups
      const groups = await Group.find({ 
        courseId, 
        members: req.user.userId 
      });
      const groupIds = groups.map(g => g._id);
      
      // Show announcements for student's groups OR announcements with no groups (all students)
      query.$or = [
        { groupIds: { $in: groupIds } },
        { groupIds: { $size: 0 } }
      ];
    }
    
    const announcements = await Announcement.find(query)
      .populate('authorId', 'fullName avatar username firstName lastName')
      .populate('groupIds', 'name')
      .sort({ createdAt: -1 });
    
    // Transform announcements to ensure authorName exists and attachments are in correct format
    const transformedAnnouncements = announcements.map(announcement => {
      const announcementObj = announcement.toObject();
      
      // If authorName is missing but authorId is populated, set it
      if (!announcementObj.authorName && announcementObj.authorId) {
        if (typeof announcementObj.authorId === 'object') {
          announcementObj.authorName = announcementObj.authorId.fullName || announcementObj.authorId.username || 'Unknown';
          announcementObj.authorAvatar = announcementObj.authorId.avatar;
        }
      }
      
      // Transform attachments to correct field names
      announcementObj.attachments = transformAttachments(announcementObj.attachments);
      
      return announcementObj;
    });
    
    res.json(transformedAnnouncements);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get single announcement
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id)
      .populate('authorId', 'fullName avatar username firstName lastName')
      .populate('groupIds', 'name');
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    // Transform to ensure authorName exists and attachments are in correct format
    const announcementObj = announcement.toObject();
    if (!announcementObj.authorName && announcementObj.authorId) {
      if (typeof announcementObj.authorId === 'object') {
        announcementObj.authorName = announcementObj.authorId.fullName || announcementObj.authorId.username || 'Unknown';
        announcementObj.authorAvatar = announcementObj.authorId.avatar;
      }
    }
    
    // Transform attachments to correct field names
    announcementObj.attachments = transformAttachments(announcementObj.attachments);
    
    res.json(announcementObj);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create announcement
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { courseId, title, content, groupIds, attachments } = req.body;
    
    // Get author details
    const author = await User.findById(req.user.userId);
    if (!author) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const announcement = new Announcement({
      courseId,
      title,
      content,
      authorId: req.user.userId,
      authorName: author.fullName || author.username,
      authorAvatar: author.avatar,
      groupIds: groupIds || [],
      attachments: transformAttachmentsToDb(attachments || []),
      comments: []
    });
    await announcement.save();
    
    // Send notifications to students (optional - can be done asynchronously)
    // This is wrapped in try-catch so it doesn't fail the announcement creation
    try {
      const Course = require('../models/Course');
      const course = await Course.findById(courseId).populate('students', '_id');
      if (course && course.students && course.students.length > 0) {
        const studentIds = course.students.map(s => s._id);
        // Pass full announcement data for email notifications
        await notifyNewAnnouncement(
          courseId, 
          course.name || 'Course', 
          title, 
          studentIds,
          announcement.toObject() // Pass the full announcement object
        );
      }
    } catch (notifError) {
      console.error('Error sending notifications:', notifError);
      // Don't fail the announcement creation if notifications fail
    }
    
    res.status(201).json(announcement);
  } catch (error) {
    res.status(400).json({ message: 'Error creating announcement', error: error.message });
  }
});

// Update announcement
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    // Transform attachments if they exist in the update body
    const updateData = { ...req.body };
    if (updateData.attachments) {
      updateData.attachments = transformAttachmentsToDb(updateData.attachments);
    }
    
    const announcement = await Announcement.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    );
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    // Transform attachments back to API format for response
    const announcementObj = announcement.toObject();
    announcementObj.attachments = transformAttachments(announcementObj.attachments);
    
    res.json(announcementObj);
  } catch (error) {
    res.status(400).json({ message: 'Error updating announcement', error: error.message });
  }
});

// Track announcement view
router.post('/:id/view', authMiddleware, async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id);
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    const alreadyViewed = announcement.viewedBy.some(
      v => v.userId.toString() === req.user.userId
    );
    
    if (!alreadyViewed) {
      announcement.viewedBy.push({
        userId: req.user.userId,
        viewedAt: new Date()
      });
      await announcement.save();
    }
    
    res.json({ message: 'View tracked' });
  } catch (error) {
    res.status(400).json({ message: 'Error tracking view', error: error.message });
  }
});

// Track file download
router.post('/:id/download', authMiddleware, async (req, res) => {
  try {
    const { fileName } = req.body;
    const announcement = await Announcement.findById(req.params.id);
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    // Verify file exists in announcement
    const fileExists = announcement.attachments.some(att => att.name === fileName);
    if (!fileExists) {
      return res.status(404).json({ message: 'File not found in announcement' });
    }
    
    // Add download tracking (allow multiple downloads by same user)
    announcement.downloadedBy.push({
      userId: req.user.userId,
      fileName: fileName,
      downloadedAt: new Date()
    });
    await announcement.save();
    
    res.json({ message: 'Download tracked' });
  } catch (error) {
    res.status(400).json({ message: 'Error tracking download', error: error.message });
  }
});

// Get detailed tracking analytics
router.get('/:id/tracking', authMiddleware, async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id)
      .populate('viewedBy.userId', 'fullName email username firstName lastName studentId')
      .populate('downloadedBy.userId', 'fullName email username firstName lastName studentId');
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    // Only course instructor can view tracking
    const course = await Course.findById(announcement.courseId);
    if (course.instructorId.toString() !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Calculate statistics
    const viewStats = {
      totalViews: announcement.viewedBy.length,
      uniqueViewers: new Set(announcement.viewedBy.map(v => v.userId._id.toString())).size,
      viewers: announcement.viewedBy.map(view => ({
        userId: view.userId._id,
        fullName: view.userId.fullName || `${view.userId.firstName || ''} ${view.userId.lastName || ''}`.trim() || view.userId.username,
        email: view.userId.email,
        studentId: view.userId.studentId,
        viewedAt: view.viewedAt
      }))
    };
    
    const downloadStats = {
      totalDownloads: announcement.downloadedBy.length,
      uniqueDownloaders: new Set(announcement.downloadedBy.map(d => d.userId._id.toString())).size,
      downloads: announcement.downloadedBy.map(download => ({
        userId: download.userId._id,
        fullName: download.userId.fullName || `${download.userId.firstName || ''} ${download.userId.lastName || ''}`.trim() || download.userId.username,
        email: download.userId.email,
        studentId: download.userId.studentId,
        fileName: download.fileName,
        downloadedAt: download.downloadedAt
      }))
    };
    
    // File-specific download stats
    const fileStats = {};
    announcement.attachments.forEach(file => {
      const downloads = announcement.downloadedBy.filter(d => d.fileName === file.name);
      fileStats[file.name] = {
        totalDownloads: downloads.length,
        uniqueDownloaders: new Set(downloads.map(d => d.userId._id.toString())).size
      };
    });
    
    res.json({
      announcementId: announcement._id,
      title: announcement.title,
      createdAt: announcement.createdAt,
      viewStats,
      downloadStats,
      fileStats
    });
  } catch (error) {
    res.status(400).json({ message: 'Error fetching tracking data', error: error.message });
  }
});

// Export tracking data as CSV
router.get('/:id/export', authMiddleware, async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id)
      .populate('viewedBy.userId', 'fullName email username firstName lastName studentId')
      .populate('downloadedBy.userId', 'fullName email username firstName lastName studentId');
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    // Only course instructor can export
    const course = await Course.findById(announcement.courseId);
    if (course.instructorId.toString() !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Create CSV content
    let csv = 'Type,Student ID,Full Name,Email,Action,File Name,Timestamp\n';
    
    // Add view records
    announcement.viewedBy.forEach(view => {
      const user = view.userId;
      const fullName = user.fullName || `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.username;
      csv += `View,"${user.studentId || 'N/A'}","${fullName}","${user.email || 'N/A'}",Viewed,N/A,${view.viewedAt}\n`;
    });
    
    // Add download records
    announcement.downloadedBy.forEach(download => {
      const user = download.userId;
      const fullName = user.fullName || `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.username;
      csv += `Download,"${user.studentId || 'N/A'}","${fullName}","${user.email || 'N/A'}",Downloaded,"${download.fileName}",${download.downloadedAt}\n`;
    });
    
    // Set response headers for CSV download
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="announcement_${announcement._id}_tracking.csv"`);
    res.send(csv);
  } catch (error) {
    res.status(400).json({ message: 'Error exporting data', error: error.message });
  }
});

// Add comment to announcement
router.post('/:id/comments', authMiddleware, async (req, res) => {
  try {
    const { text } = req.body;
    
    if (!text || text.trim() === '') {
      return res.status(400).json({ message: 'Comment text is required' });
    }
    
    const announcement = await Announcement.findById(req.params.id);
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    // Debug: Check if authorName exists
    console.log('Announcement authorName:', announcement.authorName);
    console.log('Announcement authorId:', announcement.authorId);
    
    // If authorName is missing, fetch it from the author
    if (!announcement.authorName) {
      const author = await User.findById(announcement.authorId);
      if (author) {
        announcement.authorName = author.fullName || author.username || author.email || 'Unknown';
      }
    }
    
    // Get commenter details
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Build user name from available fields
    let userName = user.fullName; // This is a virtual that returns firstName + lastName or username
    if (!userName || userName === 'Unknown User') {
      userName = user.username || user.email || 'Anonymous';
    }
    
    const comment = {
      userId: req.user.userId,
      userName: userName,
      userAvatar: user.avatar,
      text: text.trim(),
      createdAt: new Date()
    };
    
    announcement.comments.push(comment);
    const savedAnnouncement = await announcement.save();
    
    // Fetch fresh populated version to avoid validation issues
    const populatedAnnouncement = await Announcement.findById(savedAnnouncement._id)
      .populate('authorId', 'username firstName lastName avatar');
    
    // Notify the announcement author (if commenter is not the author)
    if (populatedAnnouncement.authorId._id.toString() !== req.user.userId) {
      await notifyNewComment(
        populatedAnnouncement.authorId._id,
        populatedAnnouncement.courseId,
        populatedAnnouncement._id,
        userName,
        'announcement'
      );
    }
    
    res.status(201).json(populatedAnnouncement);
  } catch (error) {
    console.error('Error adding comment:', error);
    res.status(400).json({ message: 'Error adding comment', error: error.message });
  }
});

// Delete announcement
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const announcement = await Announcement.findByIdAndDelete(req.params.id);
    
    if (!announcement) {
      return res.status(404).json({ message: 'Announcement not found' });
    }
    
    res.json({ message: 'Announcement deleted successfully' });
  } catch (error) {
    res.status(400).json({ message: 'Error deleting announcement', error: error.message });
  }
});

module.exports = router;