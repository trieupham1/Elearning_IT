const express = require('express');
const router = express.Router();
const Material = require('../models/Material');
const User = require('../models/User');
const Course = require('../models/Course');
const { authMiddleware, instructorOnly } = require('../middleware/auth');
const { notifyNewMaterial } = require('../utils/notificationHelper');

// Get materials by course
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    const { courseId } = req.params;
    
    // Verify user has access to this course
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    // Check if user is instructor or enrolled student
    const isInstructor = req.user.role === 'instructor';
    const isEnrolledStudent = course.students.includes(req.user.userId);
    
    if (!isInstructor && !isEnrolledStudent) {
      return res.status(403).json({ message: 'Access denied to this course' });
    }
    
    const materials = await Material.find({ courseId })
      .populate('createdBy', 'firstName lastName username email')
      .sort({ createdAt: -1 });
    
    res.json(materials);
  } catch (error) {
    console.error('Error fetching materials:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get single material
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const material = await Material.findById(req.params.id)
      .populate('createdBy', 'firstName lastName username email')
      .populate('viewedBy.userId', 'firstName lastName username')
      .populate('downloadedBy.userId', 'firstName lastName username');
    
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }
    
    // Verify user has access to this course
    const course = await Course.findById(material.courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    const isInstructor = req.user.role === 'instructor';
    const isEnrolledStudent = course.students.includes(req.user.userId);
    
    if (!isInstructor && !isEnrolledStudent) {
      return res.status(403).json({ message: 'Access denied to this course' });
    }
    
    res.json(material);
  } catch (error) {
    console.error('Error fetching material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create new material (instructors only)
router.post('/', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { courseId, title, description, files, links } = req.body;
    
    // Verify course exists and instructor has access
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    // Create new material
    const material = new Material({
      courseId,
      createdBy: req.user.userId,
      title,
      description,
      files: files || [],
      links: links || [],
      viewedBy: [],
      downloadedBy: []
    });
    
    await material.save();
    
    // Populate creator info for response
    await material.populate('createdBy', 'firstName lastName username email');
    
    // Notify all students in the course
    if (course.students && course.students.length > 0) {
      try {
        await notifyNewMaterial(
          courseId,
          course.name,
          title,
          course.students
        );
      } catch (notificationError) {
        console.error('Error sending notifications:', notificationError);
        // Don't fail the request if notifications fail
      }
    }
    
    res.status(201).json(material);
  } catch (error) {
    console.error('Error creating material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update material (instructors only)
router.put('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { title, description, files, links } = req.body;
    
    const material = await Material.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }
    
    // Verify course exists and instructor has access
    const course = await Course.findById(material.courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    // Update material
    material.title = title || material.title;
    material.description = description !== undefined ? description : material.description;
    material.files = files || material.files;
    material.links = links || material.links;
    
    await material.save();
    
    // Populate creator info for response
    await material.populate('createdBy', 'firstName lastName username email');
    
    res.json(material);
  } catch (error) {
    console.error('Error updating material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete material (instructors only)
router.delete('/:id', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const material = await Material.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }
    
    // Verify course exists and instructor has access
    const course = await Course.findById(material.courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    await Material.findByIdAndDelete(req.params.id);
    
    res.json({ message: 'Material deleted successfully' });
  } catch (error) {
    console.error('Error deleting material:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Track material view
router.post('/:id/view', authMiddleware, async (req, res) => {
  try {
    const material = await Material.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }
    
    // Verify user has access to this course
    const course = await Course.findById(material.courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    const isInstructor = req.user.role === 'instructor';
    const isEnrolledStudent = course.students.includes(req.user.userId);
    
    if (!isInstructor && !isEnrolledStudent) {
      return res.status(403).json({ message: 'Access denied to this course' });
    }
    
    // Check if user has already viewed this material today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const existingView = material.viewedBy.find(view => 
      view.userId.toString() === req.user.userId && 
      view.viewedAt >= today
    );
    
    if (!existingView) {
      // Add new view record
      material.viewedBy.push({
        userId: req.user.userId,
        viewedAt: new Date()
      });
      
      await material.save();
    }
    
    res.json({ message: 'View tracked successfully' });
  } catch (error) {
    console.error('Error tracking view:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Track material download
router.post('/:id/download', authMiddleware, async (req, res) => {
  try {
    const { fileName } = req.body;
    
    const material = await Material.findById(req.params.id);
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }
    
    // Verify user has access to this course
    const course = await Course.findById(material.courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    const isInstructor = req.user.role === 'instructor';
    const isEnrolledStudent = course.students.includes(req.user.userId);
    
    if (!isInstructor && !isEnrolledStudent) {
      return res.status(403).json({ message: 'Access denied to this course' });
    }
    
    // Add download record
    material.downloadedBy.push({
      userId: req.user.userId,
      fileName: fileName || 'Unknown file',
      downloadedAt: new Date()
    });
    
    await material.save();
    
    res.json({ message: 'Download tracked successfully' });
  } catch (error) {
    console.error('Error tracking download:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get material analytics (instructors only)
router.get('/:id/analytics', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const material = await Material.findById(req.params.id)
      .populate('viewedBy.userId', 'firstName lastName username email')
      .populate('downloadedBy.userId', 'firstName lastName username email');
    
    if (!material) {
      return res.status(404).json({ message: 'Material not found' });
    }
    
    // Verify course exists and instructor has access
    const course = await Course.findById(material.courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    // Calculate analytics
    const totalViews = material.viewedBy.length;
    const totalDownloads = material.downloadedBy.length;
    const uniqueViewers = [...new Set(material.viewedBy.map(v => v.userId.toString()))].length;
    const uniqueDownloaders = [...new Set(material.downloadedBy.map(d => d.userId.toString()))].length;
    
    // Get recent activity (last 7 days)
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);
    
    const recentViews = material.viewedBy.filter(v => v.viewedAt >= weekAgo);
    const recentDownloads = material.downloadedBy.filter(d => d.downloadedAt >= weekAgo);
    
    res.json({
      materialId: material._id,
      title: material.title,
      totalViews,
      totalDownloads,
      uniqueViewers,
      uniqueDownloaders,
      recentViews: recentViews.length,
      recentDownloads: recentDownloads.length,
      viewHistory: material.viewedBy,
      downloadHistory: material.downloadedBy
    });
  } catch (error) {
    console.error('Error fetching analytics:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get course materials analytics (instructors only)
router.get('/course/:courseId/analytics', authMiddleware, instructorOnly, async (req, res) => {
  try {
    const { courseId } = req.params;
    
    // Verify course exists and instructor has access
    const course = await Course.findById(courseId);
    if (!course) {
      return res.status(404).json({ message: 'Course not found' });
    }
    
    const materials = await Material.find({ courseId })
      .populate('createdBy', 'firstName lastName username')
      .sort({ createdAt: -1 });
    
    // Calculate overall statistics
    let totalMaterials = materials.length;
    let totalViews = 0;
    let totalDownloads = 0;
    let totalFiles = 0;
    
    const materialStats = materials.map(material => {
      const views = material.viewedBy.length;
      const downloads = material.downloadedBy.length;
      const files = material.files.length;
      
      totalViews += views;
      totalDownloads += downloads;
      totalFiles += files;
      
      return {
        id: material._id,
        title: material.title,
        createdBy: material.createdBy,
        createdAt: material.createdAt,
        views,
        downloads,
        files,
        uniqueViewers: [...new Set(material.viewedBy.map(v => v.userId.toString()))].length,
        uniqueDownloaders: [...new Set(material.downloadedBy.map(d => d.userId.toString()))].length
      };
    });
    
    res.json({
      courseId,
      totalMaterials,
      totalViews,
      totalDownloads,
      totalFiles,
      materials: materialStats
    });
  } catch (error) {
    console.error('Error fetching course analytics:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;