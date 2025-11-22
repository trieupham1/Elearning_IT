const mongoose = require('mongoose');

const videoProgressSchema = new mongoose.Schema({
  videoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Video',
    required: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  watchedDuration: {
    type: Number, // Seconds watched
    default: 0
  },
  lastWatchedPosition: {
    type: Number, // Last position in seconds
    default: 0
  },
  completed: {
    type: Boolean,
    default: false
  },
  completionPercentage: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
  }
}, {
  timestamps: true
});

// Compound index to ensure one progress record per user per video
videoProgressSchema.index({ videoId: 1, userId: 1 }, { unique: true });

// Method to update progress
videoProgressSchema.methods.updateProgress = function(position, videoDuration) {
  this.lastWatchedPosition = position;
  
  if (videoDuration > 0) {
    this.completionPercentage = Math.min(Math.round((position / videoDuration) * 100), 100);
    
    // Mark as completed if watched 75% or more (changed from 90%)
    if (this.completionPercentage >= 75) {
      this.completed = true;
    }
  }
  
  return this.save();
};

const VideoProgress = mongoose.model('VideoProgress', videoProgressSchema);

module.exports = VideoProgress;
