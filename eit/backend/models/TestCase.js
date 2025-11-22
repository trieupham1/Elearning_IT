const mongoose = require('mongoose');

const testCaseSchema = new mongoose.Schema({
  assignmentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Assignment',
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true
  },
  description: String,
  input: {
    type: String,
    required: true
  },
  expectedOutput: {
    type: String,
    required: true
  },
  weight: {
    type: Number,
    default: 1,
    min: 0,
    max: 100
  },
  timeLimit: {
    type: Number,
    default: 5000, // 5 seconds in milliseconds
    min: 100,
    max: 30000
  },
  memoryLimit: {
    type: Number,
    default: 128000, // 128MB in KB
    min: 1000,
    max: 512000
  },
  isHidden: {
    type: Boolean,
    default: false // Hidden test cases not visible to students
  },
  order: {
    type: Number,
    default: 0
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Compound index for efficient querying
testCaseSchema.index({ assignmentId: 1, order: 1 });

// Method to validate input/output format (renamed to avoid Mongoose conflict)
testCaseSchema.methods.validateTestCase = function() {
  const errors = [];

  if (!this.input || this.input.trim() === '') {
    errors.push('Input cannot be empty');
  }

  if (!this.expectedOutput || this.expectedOutput.trim() === '') {
    errors.push('Expected output cannot be empty');
  }

  if (this.weight < 0 || this.weight > 100) {
    errors.push('Weight must be between 0 and 100');
  }

  if (this.timeLimit < 100 || this.timeLimit > 30000) {
    errors.push('Time limit must be between 100ms and 30000ms');
  }

  if (this.memoryLimit < 1000 || this.memoryLimit > 512000) {
    errors.push('Memory limit must be between 1MB and 512MB');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};

// Static method to get all test cases for an assignment
testCaseSchema.statics.getByAssignment = async function(assignmentId, includeHidden = false) {
  const query = { assignmentId, isActive: true };
  
  if (!includeHidden) {
    query.isHidden = false;
  }

  return await this.find(query).sort({ order: 1 });
};

// Static method to count test cases
testCaseSchema.statics.countByAssignment = async function(assignmentId) {
  return {
    total: await this.countDocuments({ assignmentId, isActive: true }),
    visible: await this.countDocuments({ assignmentId, isActive: true, isHidden: false }),
    hidden: await this.countDocuments({ assignmentId, isActive: true, isHidden: true })
  };
};

// Virtual for display name
testCaseSchema.virtual('displayName').get(function() {
  return this.isHidden ? `Hidden Test Case ${this.order}` : this.name;
});

// Ensure virtuals are included in JSON
testCaseSchema.set('toJSON', { virtuals: true });
testCaseSchema.set('toObject', { virtuals: true });

const TestCase = mongoose.model('TestCase', testCaseSchema);

module.exports = TestCase;
