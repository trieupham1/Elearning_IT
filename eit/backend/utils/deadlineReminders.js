// utils/deadlineReminders.js
const Assignment = require('../models/Assignment');
const Quiz = require('../models/Quiz');
const Submission = require('../models/Submission');
const Course = require('../models/Course');
const User = require('../models/User');
const emailService = require('./emailService');

/**
 * Check for assignments approaching deadline and send reminder emails
 * This should be run once daily (e.g., via cron job)
 */
async function sendAssignmentDeadlineReminders() {
  try {
    console.log('🔔 Checking for assignment deadlines...');
    
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + (3 * 24 * 60 * 60 * 1000));
    const oneDayFromNow = new Date(now.getTime() + (1 * 24 * 60 * 60 * 1000));
    
    // Find assignments with deadlines in the next 3 days or 1 day
    const upcomingAssignments = await Assignment.find({
      deadline: {
        $gte: now,
        $lte: threeDaysFromNow
      }
    }).populate('courseId', 'title students');
    
    for (const assignment of upcomingAssignments) {
      if (!assignment.courseId || !assignment.courseId.students) continue;
      
      const daysUntilDeadline = Math.ceil(
        (new Date(assignment.deadline) - now) / (1000 * 60 * 60 * 24)
      );
      
      // Only send reminders for 3 days and 1 day before deadline
      if (daysUntilDeadline !== 3 && daysUntilDeadline !== 1) continue;
      
      // Get students who haven't submitted yet
      const submissions = await Submission.find({
        assignmentId: assignment._id
      }).select('studentId');
      
      const submittedStudentIds = submissions.map(s => s.studentId.toString());
      const studentsToNotify = assignment.courseId.students.filter(
        studentId => !submittedStudentIds.includes(studentId.toString())
      );
      
      if (studentsToNotify.length === 0) continue;
      
      // Load student details and send emails
      const students = await User.find({
        _id: { $in: studentsToNotify },
        role: 'student'
      }).select('email fullName');
      
      console.log(`📧 Sending ${daysUntilDeadline}-day reminder for "${assignment.title}" to ${students.length} students`);
      
      for (const student of students) {
        try {
          await emailService.sendAssignmentDeadlineEmail(
            student,
            assignment,
            assignment.courseId.title,
            daysUntilDeadline
          );
        } catch (emailError) {
          console.error(`Error sending deadline email to ${student.email}:`, emailError.message);
        }
      }
    }
    
    console.log('✅ Assignment deadline reminders sent');
  } catch (error) {
    console.error('❌ Error sending assignment deadline reminders:', error);
  }
}

/**
 * Check for quizzes approaching deadline and send reminder emails
 */
async function sendQuizDeadlineReminders() {
  try {
    console.log('🔔 Checking for quiz deadlines...');
    
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + (3 * 24 * 60 * 60 * 1000));
    const oneDayFromNow = new Date(now.getTime() + (1 * 24 * 60 * 60 * 1000));
    
    // Find quizzes closing in the next 3 days or 1 day
    const upcomingQuizzes = await Quiz.find({
      closeDate: {
        $gte: now,
        $lte: threeDaysFromNow
      },
      isPublished: true
    });
    
    for (const quiz of upcomingQuizzes) {
      const daysUntilDeadline = Math.ceil(
        (new Date(quiz.closeDate) - now) / (1000 * 60 * 60 * 24)
      );
      
      // Only send reminders for 3 days and 1 day before deadline
      if (daysUntilDeadline !== 3 && daysUntilDeadline !== 1) continue;
      
      // Get course and students
      const course = await Course.findById(quiz.courseId).populate('students', 'email fullName role');
      if (!course || !course.students) continue;
      
      // Get quiz attempts to exclude students who already took it
      const QuizAttempt = require('../models/QuizAttempt');
      const attempts = await QuizAttempt.find({
        quizId: quiz._id,
        status: { $in: ['submitted', 'completed', 'auto_submitted'] }
      }).select('studentId');
      
      const completedStudentIds = attempts.map(a => a.studentId.toString());
      const studentsToNotify = course.students.filter(
        student => student.role === 'student' && !completedStudentIds.includes(student._id.toString())
      );
      
      if (studentsToNotify.length === 0) continue;
      
      console.log(`📧 Sending ${daysUntilDeadline}-day reminder for quiz "${quiz.title}" to ${studentsToNotify.length} students`);
      
      for (const student of studentsToNotify) {
        try {
          const subject = `Reminder: Quiz "${quiz.title}" - Due in ${daysUntilDeadline} days`;
          const html = `
            <!DOCTYPE html>
            <html>
            <head>
              <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
                .content { padding: 20px; background-color: #f5f5f5; }
                .deadline { background-color: #fff3cd; border-left: 4px solid #ff9800; 
                            padding: 15px; margin: 15px 0; }
                .button { display: inline-block; padding: 10px 20px; background-color: #4CAF50; 
                          color: white; text-decoration: none; border-radius: 5px; margin-top: 15px; }
                .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <h1>⏰ Quiz Deadline Reminder</h1>
                </div>
                <div class="content">
                  <p>This is a reminder about an upcoming quiz in <strong>${course.title || course.name}</strong>:</p>
                  <h2>${quiz.title}</h2>
                  <div class="deadline">
                    <strong>⚠️ Closes in ${daysUntilDeadline} days</strong><br>
                    Deadline: ${new Date(quiz.closeDate).toLocaleString()}<br>
                    Duration: ${quiz.duration} minutes<br>
                    Attempts allowed: ${quiz.maxAttempts}
                  </div>
                  <p>Don't forget to complete this quiz before it closes!</p>
                </div>
                <div class="footer">
                  <p>Faculty of Information Technology - E-Learning System</p>
                </div>
              </div>
            </body>
            </html>
          `;
          
          await emailService.sendEmail(student.email, subject, html);
        } catch (emailError) {
          console.error(`Error sending quiz deadline email to ${student.email}:`, emailError.message);
        }
      }
    }
    
    console.log('✅ Quiz deadline reminders sent');
  } catch (error) {
    console.error('❌ Error sending quiz deadline reminders:', error);
  }
}

/**
 * Run all deadline reminder checks
 */
async function checkDeadlines() {
  console.log('🚀 Starting deadline reminder service...');
  await Promise.all([
    sendAssignmentDeadlineReminders(),
    sendQuizDeadlineReminders()
  ]);
  console.log('🎉 Deadline reminder service completed');
}

module.exports = {
  checkDeadlines,
  sendAssignmentDeadlineReminders,
  sendQuizDeadlineReminders
};
