// server.js - Main Express Server
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

// Validate required environment variables
const requiredEnvVars = ['MONGODB_URI', 'JWT_SECRET'];
const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
  console.error('❌ Missing required environment variables:');
  missingVars.forEach(varName => console.error(`   - ${varName}`));
  console.error('\nPlease create a .env file with the required variables.');
  process.exit(1);
}

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
const authRoutes = require('./routes/auth');
const courseRoutes = require('./routes/courses');
const userRoutes = require('./routes/users');
const semesterRoutes = require('./routes/semesters');
const studentRoutes = require('./routes/students');
const notificationRoutes = require('./routes/notifications');
const announcementRoutes = require('./routes/announcements');
const assignmentRoutes = require('./routes/assignments');
const classworkRoutes = require('./routes/classwork');
const messageRoutes = require('./routes/messages');
const groupRoutes = require('./routes/groups');
const quizRoutes = require('./routes/quizzes');
const questionRoutes = require('./routes/questions');
const quizAttemptRoutes = require('./routes/quiz-attempts');
const materialRoutes = require('./routes/materials');
const forumRoutes = require('./routes/forum');
const dashboardRoutes = require('./routes/dashboard');
const exportRoutes = require('./routes/export');
const settingsRoutes = require('./routes/settings');
const departmentRoutes = require('./routes/departments');
const adminRoutes = require('./routes/admin');
const adminDashboardRoutes = require('./routes/adminDashboard');
const adminReportsRoutes = require('./routes/adminReports');
const { router: fileRoutes, initializeGridFS } = require('./routes/files');
const attendanceRoutes = require('./routes/attendance');
const codeAssignmentRoutes = require('./routes/code-assignments');


app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/semesters', semesterRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/assignments', assignmentRoutes);
app.use('/api/classwork', classworkRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/quizzes', quizRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/quiz-attempts', quizAttemptRoutes);
app.use('/api/materials', materialRoutes);
app.use('/api/forum', forumRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/export', exportRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/departments', departmentRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/admin/dashboard', adminDashboardRoutes);
app.use('/api/admin/reports', adminReportsRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/code', codeAssignmentRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// 404 handler for undefined routes
app.use((req, res, next) => {
  res.status(404).json({ 
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('❌ Server Error:', err);
  
  // Don't leak error details in production
  const message = process.env.NODE_ENV === 'production' 
    ? 'Internal Server Error' 
    : err.message;
  
  res.status(err.statusCode || 500).json({
    error: err.name || 'ServerError',
    message: message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
});

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
    
    // Initialize GridFS for file storage
    const { GridFSBucket } = require('mongodb');
    const db = mongoose.connection.db;
    const gfsBucket = new GridFSBucket(db, { bucketName: 'uploads' });
    initializeGridFS(gfsBucket);
    console.log('GridFS initialized');
    
    // Validate Judge0 configuration for code assignments
    const { validateConfig } = require('./utils/judge0Helper');
    if (validateConfig()) {
      console.log('✓ Judge0 API configured');
    } else {
      console.log('✗ Judge0 API not configured - code assignments will not work');
    }
    
    // Start scheduled tasks
    startScheduledTasks();
    
    const PORT = process.env.PORT || 5000;
    const HOST = '0.0.0.0'; // Listen on all network interfaces (allows external connections)
    const server = app.listen(PORT, HOST, () => {
      console.log(`✅ Server running on port ${PORT}`);
      console.log(`📡 Local: http://localhost:${PORT}`);
      console.log(`🌐 Network: http://YOUR_IP:${PORT}`);
      console.log(`📱 Android device can connect to the Network URL`);
    });
    
    // Store server instance globally for graceful shutdown
    global.server = server;
  })
  .catch((error) => {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  });

// Scheduled tasks
function startScheduledTasks() {
  const Quiz = require('./models/Quiz');
  const QuizAttempt = require('./models/QuizAttempt');
  const { checkDeadlines } = require('./utils/deadlineReminders');
  
  // Auto-close expired quizzes every 5 minutes
  setInterval(async () => {
    try {
      const now = new Date();
      
      // Find quizzes that should be closed
      const expiredQuizzes = await Quiz.find({
        closeDate: { $lte: now },
        status: { $in: ['active', 'draft'] },
        isActive: true
      });

      if (expiredQuizzes.length > 0) {
        // Auto-submit any in-progress attempts for expired quizzes
        for (const quiz of expiredQuizzes) {
          await QuizAttempt.updateMany(
            { quizId: quiz._id, status: 'in_progress' },
            { 
              status: 'auto_submitted',
              endTime: now,
              submissionTime: now
            }
          );
        }

        // Update quiz status
        await Quiz.updateMany(
          { _id: { $in: expiredQuizzes.map(q => q._id) } },
          { 
            status: 'closed',
            isActive: false
          }
        );

        console.log(`🔒 Auto-closed ${expiredQuizzes.length} expired quizzes`);
      }
    } catch (error) {
      console.error('❌ Error in scheduled quiz cleanup:', error);
    }
  }, 5 * 60 * 1000); // Every 5 minutes
  
  // Check for assignment/quiz deadlines and send reminder emails daily at 9 AM
  const scheduleDeadlineReminders = () => {
    const now = new Date();
    const nextRun = new Date();
    nextRun.setHours(9, 0, 0, 0); // 9:00 AM
    
    // If it's past 9 AM today, schedule for tomorrow
    if (now.getHours() >= 9) {
      nextRun.setDate(nextRun.getDate() + 1);
    }
    
    const timeUntilNextRun = nextRun.getTime() - now.getTime();
    
    setTimeout(async () => {
      await checkDeadlines();
      // Schedule next run for tomorrow at 9 AM
      setInterval(checkDeadlines, 24 * 60 * 60 * 1000); // Every 24 hours
    }, timeUntilNextRun);
    
    console.log(`📧 Deadline reminder emails scheduled to run daily at 9:00 AM (next run: ${nextRun.toLocaleString()})`);
  };
  
  scheduleDeadlineReminders();
  
  console.log('📅 Scheduled tasks started:');
  console.log('   - Checking for expired quizzes every 5 minutes');
  console.log('   - Checking for deadline reminders daily at 9:00 AM');
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  console.error('Shutting down server due to unhandled promise rejection');
  process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  console.error('Shutting down server due to uncaught exception');
  process.exit(1);
});

// Graceful shutdown on SIGTERM
process.on('SIGTERM', () => {
  console.log('👋 SIGTERM received, closing server gracefully');
  if (global.server) {
    global.server.close(() => {
      console.log('✅ HTTP server closed');
      mongoose.connection.close(false, () => {
        console.log('✅ MongoDB connection closed');
        process.exit(0);
      });
    });
  }
});

// Graceful shutdown on SIGINT (Ctrl+C)
process.on('SIGINT', () => {
  console.log('\n👋 SIGINT received, closing server gracefully');
  if (global.server) {
    global.server.close(() => {
      console.log('✅ HTTP server closed');
      mongoose.connection.close(false, () => {
        console.log('✅ MongoDB connection closed');
        process.exit(0);
      });
    });
  } else {
    mongoose.connection.close(false, () => {
      console.log('✅ MongoDB connection closed');
      process.exit(0);
    });
  }
});

module.exports = app;