// server.js - Main Express Server
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

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
const videoRoutes = require('./routes/videos');
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
app.use('/api/videos', videoRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/code', codeAssignmentRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
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
      console.log(`🌐 Network: http://192.168.1.224:${PORT}`);
      console.log(`📱 Android device can connect to the Network URL`);
    });
    
    // Setup Socket.IO for WebRTC signaling
    const socketIO = require('socket.io');
    const io = socketIO(server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      }
    });
    
    // Initialize WebRTC signaling
    const setupWebRTCSignaling = require('./utils/webrtcSignaling');
    setupWebRTCSignaling(io);
    console.log('✓ WebRTC signaling server initialized');
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

module.exports = app;