const mongoose = require('mongoose');

const videoSchema = new mongoose.Schema({
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
  uploadedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  fileId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true // GridFS file ID
  },
  filename: {
    type: String,
    required: true
  },
  mimeType: {
    type: String,
    required: true
  },
  size: {
    type: Number,
    required: true
  },
  duration: {
    type: Number, // Duration in seconds
    default: 0
  },
  thumbnail: {
    type: String // URL or GridFS file ID for thumbnail
  },
  subtitles: [{
    language: String,
    fileId: mongoose.Schema.Types.ObjectId, // GridFS file ID for subtitle file
    filename: String
  }],
  tags: [{
    type: String,
    trim: true
  }],
  isPublished: {
    type: Boolean,
    default: false
  },
  viewCount: {
    type: Number,
    default: 0
  },
  // For playlist organization
  playlistId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Playlist'
  },
  orderInPlaylist: {
    type: Number
  }
}, {
  timestamps: true
});

// Index for faster queries
videoSchema.index({ courseId: 1, createdAt: -1 });
videoSchema.index({ uploadedBy: 1 });
videoSchema.index({ isPublished: 1 });

// Virtual for file URL (if needed)
videoSchema.virtual('fileUrl').get(function() {
  return `/api/videos/${this._id}/stream`;
});

// Method to increment view count
videoSchema.methods.incrementViewCount = async function() {
  this.viewCount += 1;
  return this.save();
};

const Video = mongoose.model('Video', videoSchema);

module.exports = Video;
