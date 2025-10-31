// models/User.js
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  role: { type: String, enum: ['student', 'instructor', 'admin'], default: 'student' },
  firstName: { type: String },
  lastName: { type: String },
  studentId: { type: String, sparse: true },
  department: { type: String, default: 'Information Technology' },
  year: { type: Number },
  profilePicture: { type: String },
  phoneNumber: { type: String },
  bio: { type: String },
  isActive: { type: Boolean, default: true },
  // Password reset fields
  resetPasswordToken: { type: String },
  resetPasswordExpires: { type: Date }
}, { 
  timestamps: true
});

// Virtual for full name
userSchema.virtual('fullName').get(function() {
  if (this.firstName && this.lastName) {
    return `${this.firstName} ${this.lastName}`;
  }
  return this.username || 'Unknown User';
});

// Configure JSON output with both transform and virtuals
userSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    ret.id = ret._id.toString();
    delete ret.password;  // Remove password but keep everything else including profilePicture
    return ret;
  }
});

userSchema.set('toObject', { virtuals: true });

userSchema.index({ username: 1 });
userSchema.index({ email: 1 });
userSchema.index({ role: 1 });

module.exports = mongoose.model('User', userSchema);