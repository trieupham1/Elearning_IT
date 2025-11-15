// models/UserSettings.js
const mongoose = require('mongoose');

const userSettingsSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true,
    unique: true 
  },
  theme: { 
    type: String, 
    enum: ['light', 'dark'], 
    default: 'light' 
  }
}, { 
  timestamps: true 
});

// Index for faster lookups
userSettingsSchema.index({ userId: 1 });

module.exports = mongoose.model('UserSettings', userSettingsSchema);
