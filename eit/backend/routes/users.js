const express = require('express');
const router = express.Router();
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const User = require('../models/User');
const Course = require('../models/Course');
const auth = require('../middleware/auth');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Configure multer for profile picture uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit for profile pictures
  },
  fileFilter: (req, file, cb) => {
    console.log('File upload attempt:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      size: file.size
    });
    
    // Allow common image MIME types
    const allowedMimes = [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/svg+xml'
    ];
    
    // Also check file extension as backup
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    const fileExtension = file.originalname.toLowerCase().substring(file.originalname.lastIndexOf('.'));
    
    if (allowedMimes.includes(file.mimetype) || allowedExtensions.includes(fileExtension)) {
      cb(null, true);
    } else {
      console.error('File rejected:', file.mimetype, fileExtension);
      cb(new Error(`File type not allowed. Received: ${file.mimetype}. Please upload an image file.`), false);
    }
  }
});

// Get all users (admin only)
router.get('/', auth, async (req, res) => {
  try {
    if (req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Access denied' });
    }

    const users = await User.find().select('-password');
    res.json(users);
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Search users by name or email (authenticated users)
router.get('/search', auth, async (req, res) => {
  try {
    const { q } = req.query;
    
    if (!q || q.trim().length === 0) {
      return res.json([]);
    }
    
    const searchQuery = q.trim();
    
    // Search by username, firstName, lastName, or email
    const users = await User.find({
      $or: [
        { username: { $regex: searchQuery, $options: 'i' } },
        { firstName: { $regex: searchQuery, $options: 'i' } },
        { lastName: { $regex: searchQuery, $options: 'i' } },
        { email: { $regex: searchQuery, $options: 'i' } }
      ],
      _id: { $ne: req.userId } // Exclude current user from results
    })
    .select('_id username email firstName lastName fullName role profilePicture')
    .limit(20); // Limit to 20 results
    
    res.json(users);
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get user by ID
router.get('/:id', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json(user);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get student's courses
router.get('/:id/courses', auth, async (req, res) => {
  try {
    const courses = await Course.find({ students: req.params.id })
      .populate('instructor', 'username email firstName lastName')
      .populate('semester', 'name year');
    
    res.json({ courses });
  } catch (error) {
    console.error('Get student courses error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Get instructor's taught courses
router.get('/:id/taught-courses', auth, async (req, res) => {
  try {
    const courses = await Course.find({ instructor: req.params.id })
      .populate('instructor', 'username email firstName lastName')
      .populate('semester', 'name year');
    
    res.json({ courses });
  } catch (error) {
    console.error('Get taught courses error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Update current user's profile (MUST come before /:id route)
router.put('/profile', auth, async (req, res) => {
  try {
    const { password, role, _id, ...updateData } = req.body; // Exclude sensitive fields
    
    console.log('Profile update request:', {
      userId: req.userId,
      updateData: updateData
    });
    
    const user = await User.findByIdAndUpdate(
      req.userId,
      { $set: updateData },
      { new: true, runValidators: true }
    ).select('-password');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    console.log('Profile updated successfully:', user._id);
    res.json(user);
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Update user (admin or self)
router.put('/:id', auth, async (req, res) => {
  try {
    if (req.userId !== req.params.id && req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Access denied' });
    }

    const { password, ...updateData } = req.body;
    
    const user = await User.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    ).select('-password');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json(user);
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ message: error.message });
  }
});

// Upload profile picture (user can only update their own)
router.post('/profile-picture', auth, (req, res) => {
  upload.single('profilePicture')(req, res, async (err) => {
    try {
      // Handle multer errors first
      if (err) {
        console.error('Multer error:', err.message);
        return res.status(400).json({ 
          message: err.message || 'File upload error',
          error: err.message 
        });
      }

      if (!req.file) {
        return res.status(400).json({ message: 'No image file provided' });
      }

    // Upload to Cloudinary
    const uploadResult = await new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'profile_pictures',
          transformation: [
            { width: 400, height: 400, crop: 'fill', gravity: 'face' },
            { quality: 'auto', fetch_format: 'auto' }
          ],
          public_id: `user_${req.userId}_${Date.now()}` // Unique filename
        },
        (error, result) => {
          if (error) {
            console.error('Cloudinary upload error:', error);
            reject(error);
          } else {
            resolve(result);
          }
        }
      );
      
      uploadStream.end(req.file.buffer);
    });

      // Update user's profilePicture field with Cloudinary URL
      console.log('Updating user:', req.userId, 'with profilePicture:', uploadResult.secure_url);
      
      // First, let's check if the user exists
      const existingUser = await User.findById(req.userId);
      if (!existingUser) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      console.log('User found, current profilePicture:', existingUser.profilePicture);
      
      // Update the user with the new profile picture
      const updatedUser = await User.findByIdAndUpdate(
        req.userId,
        { $set: { profilePicture: uploadResult.secure_url } },
        { new: true, runValidators: true }
      ).select('-password');

      if (!updatedUser) {
        return res.status(404).json({ message: 'Failed to update user' });
      }

      console.log('Profile picture updated successfully for user:', req.userId);
      console.log('Updated user profilePicture field:', updatedUser.profilePicture);
      console.log('Full updated user data:', JSON.stringify(updatedUser, null, 2));
    
    res.json({
      message: 'Profile picture updated successfully',
      profilePicture: uploadResult.secure_url,
      user: updatedUser
    });

    } catch (error) {
      console.error('Profile picture upload error:', error);
      res.status(500).json({ 
        message: 'Failed to upload profile picture',
        error: error.message 
      });
    }
  });
});

// Test endpoint to manually set profile picture (for debugging)
router.post('/test-profile-picture', auth, async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) {
      return res.status(400).json({ message: 'URL is required' });
    }

    console.log('Testing profile picture update for user:', req.userId, 'with URL:', url);
    
    const updatedUser = await User.findByIdAndUpdate(
      req.userId,
      { $set: { profilePicture: url } },
      { new: true, runValidators: true }
    );

    if (!updatedUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    console.log('Test update successful. User profilePicture:', updatedUser.profilePicture);
    
    res.json({
      message: 'Profile picture updated successfully (test)',
      user: updatedUser
    });
  } catch (error) {
    console.error('Test profile picture update error:', error);
    res.status(500).json({ 
      message: 'Failed to update profile picture (test)',
      error: error.message 
    });
  }
});

// Delete user (admin only)
router.delete('/:id', auth, async (req, res) => {
  try {
    if (req.userRole !== 'admin') {
      return res.status(403).json({ message: 'Access denied' });
    }

    const user = await User.findByIdAndDelete(req.params.id);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;