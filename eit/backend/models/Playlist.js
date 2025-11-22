const mongoose = require('mongoose');

const playlistSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  courseId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Course',
    required: true
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  videos: [{
    videoId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Video'
    },
    order: Number
  }],
  isPublished: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

// Index for faster queries
playlistSchema.index({ courseId: 1 });

const Playlist = mongoose.model('Playlist', playlistSchema);

module.exports = Playlist;
