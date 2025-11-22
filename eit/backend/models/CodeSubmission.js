const mongoose = require('mongoose');

const codeSubmissionSchema = new mongoose.Schema({
  assignmentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Assignment',
    required: true,
    index: true
  },
  studentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  code: {
    type: String,
    required: true
  },
  language: {
    type: String,
    required: true,
    enum: ['python', 'java', 'cpp', 'javascript', 'c']
  },
  languageId: {
    type: Number,
    required: true
    // Judge0 language IDs: Python=71, Java=62, C++=54, JavaScript=63, C=50
  },
  status: {
    type: String,
    enum: ['pending', 'running', 'completed', 'failed', 'error'],
    default: 'pending'
  },
  testResults: [{
    testCaseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'TestCase'
    },
    input: String,
    expectedOutput: String,
    actualOutput: String,
    status: {
      type: String,
      enum: ['passed', 'failed', 'error', 'timeout']
    },
    executionTime: Number, // in milliseconds
    memoryUsed: Number,    // in KB
    errorMessage: String,
    weight: {
      type: Number,
      default: 1
    }
  }],
  totalScore: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
  },
  passedTests: {
    type: Number,
    default: 0
  },
  totalTests: {
    type: Number,
    default: 0
  },
  executionSummary: {
    totalTime: Number,    // Total execution time
    averageTime: Number,  // Average per test
    maxMemory: Number     // Peak memory usage
  },
  submittedAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  gradedAt: {
    type: Date
  },
  feedback: String,
  isBestSubmission: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

// Compound index for querying submissions by student and assignment
codeSubmissionSchema.index({ assignmentId: 1, studentId: 1, submittedAt: -1 });

// Method to calculate score based on test results
codeSubmissionSchema.methods.calculateScore = function() {
  if (this.testResults.length === 0) {
    this.totalScore = 0;
    return 0;
  }

  let totalWeight = 0;
  let earnedWeight = 0;

  this.testResults.forEach(result => {
    totalWeight += result.weight || 1;
    if (result.status === 'passed') {
      earnedWeight += result.weight || 1;
    }
  });

  this.passedTests = this.testResults.filter(r => r.status === 'passed').length;
  this.totalTests = this.testResults.length;
  
  this.totalScore = totalWeight > 0 ? Math.round((earnedWeight / totalWeight) * 100) : 0;
  return this.totalScore;
};

// Method to update execution summary
codeSubmissionSchema.methods.updateExecutionSummary = function() {
  const validResults = this.testResults.filter(r => r.executionTime);
  
  if (validResults.length === 0) {
    this.executionSummary = {
      totalTime: 0,
      averageTime: 0,
      maxMemory: 0
    };
    return;
  }

  const totalTime = validResults.reduce((sum, r) => sum + r.executionTime, 0);
  const maxMemory = Math.max(...validResults.map(r => r.memoryUsed || 0));

  this.executionSummary = {
    totalTime,
    averageTime: totalTime / validResults.length,
    maxMemory
  };
};

// Static method to get best submission for a student
codeSubmissionSchema.statics.getBestSubmission = async function(assignmentId, studentId) {
  return await this.findOne({
    assignmentId,
    studentId,
    status: 'completed'
  })
  .sort({ totalScore: -1, submittedAt: 1 }) // Highest score, earliest submission
  .limit(1);
};

// Static method to get leaderboard
codeSubmissionSchema.statics.getLeaderboard = async function(assignmentId, limit = 10) {
  const pipeline = [
    {
      $match: {
        assignmentId: mongoose.Types.ObjectId(assignmentId),
        status: 'completed'
      }
    },
    {
      $sort: { studentId: 1, totalScore: -1, submittedAt: 1 }
    },
    {
      $group: {
        _id: '$studentId',
        bestSubmission: { $first: '$$ROOT' }
      }
    },
    {
      $replaceRoot: { newRoot: '$bestSubmission' }
    },
    {
      $sort: { totalScore: -1, submittedAt: 1 }
    },
    {
      $limit: limit
    },
    {
      $lookup: {
        from: 'users',
        localField: 'studentId',
        foreignField: '_id',
        as: 'student'
      }
    },
    {
      $unwind: '$student'
    },
    {
      $project: {
        studentId: 1,
        'student.fullName': 1,
        'student.email': 1,
        totalScore: 1,
        passedTests: 1,
        totalTests: 1,
        submittedAt: 1,
        executionSummary: 1
      }
    }
  ];

  return await this.aggregate(pipeline);
};

const CodeSubmission = mongoose.model('CodeSubmission', codeSubmissionSchema);

module.exports = CodeSubmission;
