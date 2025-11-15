// routes/settings.js
const express = require('express');
const UserSettings = require('../models/UserSettings');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// Get user settings
router.get('/', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Find or create settings for the user
    let settings = await UserSettings.findOne({ userId });
    
    if (!settings) {
      // Create default settings if they don't exist
      settings = new UserSettings({
        userId,
        theme: 'light',
        language: 'en',
        emailNotifications: true,
        pushNotifications: true,
        fontSize: 'medium'
      });
      await settings.save();
    }
    
    res.json(settings);
  } catch (error) {
    console.error('Error fetching user settings:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update user settings
router.put('/', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { theme, language, emailNotifications, pushNotifications, fontSize } = req.body;
    
    // Find and update or create if doesn't exist
    let settings = await UserSettings.findOne({ userId });
    
    if (!settings) {
      settings = new UserSettings({ userId });
    }
    
    // Update fields if provided
    if (theme !== undefined) settings.theme = theme;
    if (language !== undefined) settings.language = language;
    if (emailNotifications !== undefined) settings.emailNotifications = emailNotifications;
    if (pushNotifications !== undefined) settings.pushNotifications = pushNotifications;
    if (fontSize !== undefined) settings.fontSize = fontSize;
    
    await settings.save();
    
    res.json(settings);
  } catch (error) {
    console.error('Error updating user settings:', error);
    res.status(400).json({ message: 'Error updating settings', error: error.message });
  }
});

// Reset settings to default
router.post('/reset', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const settings = await UserSettings.findOneAndUpdate(
      { userId },
      {
        theme: 'light',
        language: 'en',
        emailNotifications: true,
        pushNotifications: true,
        fontSize: 'medium'
      },
      { new: true, upsert: true }
    );
    
    res.json(settings);
  } catch (error) {
    console.error('Error resetting user settings:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
