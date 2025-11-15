// utils/notificationHelper.js
const Notification = require('../models/Notification');
const User = require('../models/User');
const emailService = require('./emailService');

/**
 * Helper functions to create notifications for various events
 * Now includes email notifications for students
 */

// Notify students when new material is uploaded
async function notifyNewMaterial(courseId, courseName, materialTitle, studentIds) {
  const notifications = studentIds.map(studentId => ({
    userId: studentId,
    type: 'material',
    title: 'New Material Available',
    message: `New material "${materialTitle}" uploaded in ${courseName}`,
    data: {
      courseId,
      courseName,
      materialTitle
    }
  }));

  return await Notification.createBulkNotifications(notifications);
}

// Notify students when new announcement is posted (with email)
async function notifyNewAnnouncement(courseId, courseName, announcementTitle, studentIds, announcementData = {}) {
  const notifications = studentIds.map(studentId => ({
    userId: studentId,
    type: 'announcement',
    title: 'New Announcement',
    message: `New announcement in ${courseName}: ${announcementTitle}`,
    data: {
      courseId,
      courseName,
      announcementTitle
    }
  }));

  const result = await Notification.createBulkNotifications(notifications);
  
  // Send emails to students asynchronously
  if (announcementData && announcementData._id) {
    setImmediate(async () => {
      try {
        const students = await User.find({ 
          _id: { $in: studentIds },
          role: 'student'
        }).select('email fullName');
        
        console.log(`📧 Preparing to send announcement emails to ${students.length} students for "${announcementTitle}"`);
        
        let emailsSent = 0;
        for (const student of students) {
          if (student.email) {
            try {
              await emailService.sendNewAnnouncementEmail(
                student,
                announcementData,
                courseName
              );
              emailsSent++;
            } catch (emailError) {
              console.error(`❌ Failed to send email to ${student.email}:`, emailError.message);
            }
          } else {
            console.log(`⚠️ Student ${student.fullName} has no email address`);
          }
        }
        
        console.log(`✅ Successfully sent ${emailsSent} announcement emails`);
      } catch (error) {
        console.error('Error sending announcement emails:', error);
      }
    });
  }
  
  return result;
}

// Notify students when new assignment is created (with email for approaching deadline)
async function notifyNewAssignment(courseId, courseName, assignmentTitle, dueDate, studentIds, assignmentData = {}) {
  const notifications = studentIds.map(studentId => ({
    userId: studentId,
    type: 'assignment',
    title: 'New Assignment',
    message: `New assignment "${assignmentTitle}" in ${courseName}. Due: ${dueDate}`,
    data: {
      courseId,
      courseName,
      assignmentTitle,
      dueDate
    }
  }));

  return await Notification.createBulkNotifications(notifications);
}

// Notify students when new quiz is available (with email)
async function notifyNewQuiz(courseId, courseName, quizTitle, studentIds, quizData = {}) {
  const notifications = studentIds.map(studentId => ({
    userId: studentId,
    type: 'quiz',
    title: 'New Quiz Available',
    message: `New quiz "${quizTitle}" is now available in ${courseName}`,
    data: {
      courseId,
      courseName,
      quizTitle
    }
  }));

  const result = await Notification.createBulkNotifications(notifications);
  
  // Send emails to students asynchronously
  if (quizData && quizData._id) {
    setImmediate(async () => {
      try {
        const students = await User.find({ 
          _id: { $in: studentIds },
          role: 'student'
        }).select('email fullName');
        
        console.log(`📧 Preparing to send quiz emails to ${students.length} students for "${quizTitle}"`);
        
        let emailsSent = 0;
        for (const student of students) {
          if (student.email) {
            try {
              await emailService.sendQuizAvailableEmail(
                student,
                quizData,
                courseName
              );
              emailsSent++;
            } catch (emailError) {
              console.error(`❌ Failed to send email to ${student.email}:`, emailError.message);
            }
          } else {
            console.log(`⚠️ Student ${student.fullName} has no email address`);
          }
        }
        
        console.log(`✅ Successfully sent ${emailsSent} quiz notification emails`);
      } catch (error) {
        console.error('Error sending quiz emails:', error);
      }
    });
  }
  
  return result;
}

// Send assignment submission confirmation email
async function sendSubmissionConfirmation(studentId, assignmentData, submissionData, courseName) {
  try {
    const student = await User.findById(studentId).select('email fullName');
    if (student) {
      await emailService.sendSubmissionConfirmationEmail(
        student,
        assignmentData,
        submissionData,
        courseName
      );
    }
  } catch (error) {
    console.error('Error sending submission confirmation email:', error);
  }
}

// Send quiz submission confirmation via email
async function sendQuizSubmissionConfirmation(studentId, quizData, attemptData, courseName) {
  try {
    const student = await User.findById(studentId).select('email fullName');
    if (!student) return;
    
    const subject = `Quiz Submitted: ${quizData.title}`;
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .confirmation { background-color: #e8f5e9; padding: 15px; margin: 15px 0; 
                          border-radius: 5px; border-left: 4px solid #4CAF50; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>✅ Quiz Submitted</h1>
          </div>
          <div class="content">
            <p>Your quiz submission for <strong>${quizData.title}</strong> in ${courseName} has been received.</p>
            <div class="confirmation">
              <strong>Submission Details:</strong><br>
              Attempt: ${attemptData.attemptNumber || 1}<br>
              Submitted: ${new Date(attemptData.submittedAt || Date.now()).toLocaleString()}<br>
              ${attemptData.score !== undefined ? `Score: ${attemptData.score}%` : 'Score: Pending review'}
            </div>
            <p>You can view your results and feedback in the course page.</p>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
          </div>
        </div>
      </body>
      </html>
    `;
    
    await emailService.sendEmail(student.email, subject, html);
  } catch (error) {
    console.error('Error sending quiz submission confirmation:', error);
  }
}

// Notify instructor when student submits assignment
async function notifyAssignmentSubmission(instructorId, courseName, assignmentTitle, studentName, submissionId) {
  return await Notification.createNotification({
    userId: instructorId,
    type: 'submission',
    title: 'New Assignment Submission',
    message: `${studentName} submitted "${assignmentTitle}" in ${courseName}`,
    data: {
      courseName,
      assignmentTitle,
      studentName,
      submissionId
    }
  });
}

// Notify instructor when student completes quiz
async function notifyQuizAttempt(instructorId, courseName, quizTitle, studentName, score, attemptId) {
  return await Notification.createNotification({
    userId: instructorId,
    type: 'quiz_attempt',
    title: 'Quiz Completed',
    message: `${studentName} completed "${quizTitle}" in ${courseName}. Score: ${score}`,
    data: {
      courseName,
      quizTitle,
      studentName,
      score,
      attemptId
    }
  });
}

// Notify user when they receive a new comment
async function notifyNewComment(userId, commenterName, topicTitle, commentText, courseId) {
  return await Notification.createNotification({
    userId,
    type: 'comment',
    title: 'New Comment',
    message: `${commenterName} commented on "${topicTitle}": ${commentText.substring(0, 50)}...`,
    data: {
      commenterName,
      topicTitle,
      courseId
    }
  });
}

// Notify user when they receive a private message
async function notifyPrivateMessage(recipientId, senderName, messagePreview) {
  return await Notification.createNotification({
    userId: recipientId,
    type: 'message',
    title: 'New Message',
    message: `${senderName}: ${messagePreview.substring(0, 100)}...`,
    data: {
      senderName
    }
  });
}

// Notify instructor when student requests to join course via code
async function notifyJoinRequest(instructorId, studentName, studentId, courseName, courseId) {
  return await Notification.createNotification({
    userId: instructorId,
    type: 'message',
    title: 'Course Join Request',
    message: `${studentName} is requesting to join ${courseName}`,
    data: {
      studentName,
      studentId,
      courseName,
      courseId,
      isJoinRequest: true
    }
  });
}

// Notify student when instructor approves join request
async function notifyJoinApproved(studentId, courseName, courseId) {
  return await Notification.createNotification({
    userId: studentId,
    type: 'message',
    title: 'Join Request Approved',
    message: `Your request to join ${courseName} has been approved!`,
    data: {
      courseName,
      courseId
    }
  });
}

module.exports = {
  notifyNewMaterial,
  notifyNewAnnouncement,
  notifyNewAssignment,
  notifyNewQuiz,
  notifyAssignmentSubmission,
  notifyQuizAttempt,
  notifyNewComment,
  notifyPrivateMessage,
  notifyJoinRequest,
  notifyJoinApproved,
  sendSubmissionConfirmation,
  sendQuizSubmissionConfirmation
};
