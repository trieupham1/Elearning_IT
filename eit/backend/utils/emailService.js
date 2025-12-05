// ====================
// utils/emailService.js
// ====================
const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    // Check if email is configured
    this.isConfigured = !!(
      process.env.EMAIL_SERVICE &&
      process.env.EMAIL_USER &&
      process.env.EMAIL_PASSWORD &&
      process.env.EMAIL_FROM
    );

    if (!this.isConfigured) {
      console.warn('⚠️ Email service not configured. Set EMAIL_SERVICE, EMAIL_USER, EMAIL_PASSWORD, and EMAIL_FROM in .env file');
      console.warn('⚠️ Email notifications will be skipped until configuration is complete');
      return;
    }

    try {
      this.transporter = nodemailer.createTransport({
        service: process.env.EMAIL_SERVICE || 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASSWORD
        }
      });
      console.log('✅ Email service initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize email service:', error.message);
      this.isConfigured = false;
    }
  }

  async sendEmail(to, subject, html) {
    if (!this.isConfigured) {
      console.log(`📧 Email would be sent to ${to}: ${subject} (Email not configured)`);
      return false;
    }

    try {
      const mailOptions = {
        from: process.env.EMAIL_FROM,
        to,
        subject,
        html
      };

      // Add timeout to prevent hanging (20 seconds max)
      const emailPromise = this.transporter.sendMail(mailOptions);
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Email sending timeout after 20 seconds')), 20000)
      );

      await Promise.race([emailPromise, timeoutPromise]);
      console.log(`✅ Email sent to ${to}: ${subject}`);
      return true;
    } catch (error) {
      console.error(`❌ Email send error to ${to}:`, error.message);
      return false;
    }
  }

  async sendNewAnnouncementEmail(user, announcement, courseTitle) {
    const subject = `New Announcement: ${announcement.title}`;
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #1976D2; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .button { display: inline-block; padding: 10px 20px; background-color: #1976D2; 
                    color: white; text-decoration: none; border-radius: 5px; margin-top: 15px; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📢 New Announcement</h1>
          </div>
          <div class="content">
            <p>A new announcement has been posted in <strong>${courseTitle}</strong>:</p>
            <h2>${announcement.title}</h2>
            <div>${announcement.content.substring(0, 200)}...</div>
            <a href="${process.env.FRONTEND_URL}/courses/${announcement.courseId}/announcements/${announcement._id}" 
               class="button">View Announcement</a>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
          </div>
        </div>
      </body>
      </html>
    `;

    return this.sendEmail(user.email, subject, html);
  }

  async sendAssignmentDeadlineEmail(user, assignment, courseTitle, daysRemaining) {
    const subject = `Reminder: ${assignment.title} - Due in ${daysRemaining} days`;
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #FF9800; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .deadline { background-color: #fff3cd; border-left: 4px solid #ff9800; 
                      padding: 15px; margin: 15px 0; }
          .button { display: inline-block; padding: 10px 20px; background-color: #FF9800; 
                    color: white; text-decoration: none; border-radius: 5px; margin-top: 15px; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>⏰ Assignment Deadline Reminder</h1>
          </div>
          <div class="content">
            <p>This is a reminder about an upcoming assignment deadline in <strong>${courseTitle}</strong>:</p>
            <h2>${assignment.title}</h2>
            <div class="deadline">
              <strong>⚠️ Due in ${daysRemaining} days</strong><br>
              Deadline: ${new Date(assignment.deadline).toLocaleString()}
            </div>
            <p>${assignment.description}</p>
            <a href="${process.env.FRONTEND_URL}/courses/${assignment.courseId}/assignments/${assignment._id}" 
               class="button">View Assignment</a>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
          </div>
        </div>
      </body>
      </html>
    `;

    return this.sendEmail(user.email, subject, html);
  }

  async sendQuizAvailableEmail(user, quiz, courseTitle) {
    const subject = `New Quiz Available: ${quiz.title}`;
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .quiz-info { background-color: #e8f5e9; padding: 15px; margin: 15px 0; 
                       border-radius: 5px; }
          .button { display: inline-block; padding: 10px 20px; background-color: #4CAF50; 
                    color: white; text-decoration: none; border-radius: 5px; margin-top: 15px; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📝 New Quiz Available</h1>
          </div>
          <div class="content">
            <p>A new quiz is now available in <strong>${courseTitle}</strong>:</p>
            <h2>${quiz.title}</h2>
            <div class="quiz-info">
              <strong>Quiz Details:</strong><br>
              Duration: ${quiz.duration} minutes<br>
              Attempts allowed: ${quiz.maxAttempts}<br>
              Opens: ${new Date(quiz.openDate).toLocaleString()}<br>
              Closes: ${new Date(quiz.closeDate).toLocaleString()}
            </div>
            <p>${quiz.description}</p>
            <a href="${process.env.FRONTEND_URL}/courses/${quiz.courseId}/quizzes/${quiz._id}" 
               class="button">Take Quiz</a>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
          </div>
        </div>
      </body>
      </html>
    `;

    return this.sendEmail(user.email, subject, html);
  }

  async sendSubmissionConfirmationEmail(user, assignment, submission, courseTitle) {
    const subject = `Submission Confirmed: ${assignment.title}`;
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .confirmation { background-color: #e3f2fd; padding: 15px; margin: 15px 0; 
                          border-radius: 5px; border-left: 4px solid #2196F3; }
          .button { display: inline-block; padding: 10px 20px; background-color: #2196F3; 
                    color: white; text-decoration: none; border-radius: 5px; margin-top: 15px; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>✅ Submission Confirmed</h1>
          </div>
          <div class="content">
            <p>Your submission for <strong>${assignment.title}</strong> in ${courseTitle} has been received.</p>
            <div class="confirmation">
              <strong>Submission Details:</strong><br>
              Attempt: ${submission.attemptNumber} of ${assignment.maxAttempts}<br>
              Submitted: ${new Date(submission.submittedAt).toLocaleString()}<br>
              Status: ${submission.isLate ? '⚠️ Late Submission' : '✓ On Time'}<br>
              Files submitted: ${submission.files.length}
            </div>
            ${submission.isLate ? '<p style="color: #ff9800;">⚠️ Note: This was a late submission.</p>' : ''}
            <a href="${process.env.FRONTEND_URL}/courses/${assignment.courseId}/assignments/${assignment._id}" 
               class="button">View Submission</a>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
          </div>
        </div>
      </body>
      </html>
    `;

    return this.sendEmail(user.email, subject, html);
  }

  async sendGradeFeedbackEmail(user, assignment, submission, courseTitle) {
    const subject = `Assignment Graded: ${assignment.title}`;
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #9C27B0; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .grade { background-color: #f3e5f5; padding: 20px; margin: 15px 0; 
                   border-radius: 5px; text-align: center; }
          .grade-score { font-size: 48px; font-weight: bold; color: #9C27B0; }
          .feedback { background-color: white; padding: 15px; margin: 15px 0; 
                      border-radius: 5px; border-left: 4px solid #9C27B0; }
          .button { display: inline-block; padding: 10px 20px; background-color: #9C27B0; 
                    color: white; text-decoration: none; border-radius: 5px; margin-top: 15px; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📊 Assignment Graded</h1>
          </div>
          <div class="content">
            <p>Your assignment <strong>${assignment.title}</strong> in ${courseTitle} has been graded.</p>
            <div class="grade">
              <p style="margin: 0; color: #666;">Your Grade</p>
              <div class="grade-score">${submission.grade}</div>
            </div>
            ${submission.feedback ? `
              <div class="feedback">
                <strong>Instructor Feedback:</strong><br>
                ${submission.feedback}
              </div>
            ` : ''}
            <a href="${process.env.FRONTEND_URL}/courses/${assignment.courseId}/assignments/${assignment._id}" 
               class="button">View Details</a>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
          </div>
        </div>
      </body>
      </html>
    `;

    return this.sendEmail(user.email, subject, html);
  }

  async sendPasswordResetEmail(user, resetCode) {
    const subject = 'Password Reset Verification Code - E-Learning System';
    
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #FF5722; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f5f5f5; }
          .warning { background-color: #fff3cd; border-left: 4px solid #ff9800; 
                     padding: 15px; margin: 15px 0; }
          .code-box { background-color: #e3f2fd; border: 2px solid #2196f3; 
                      padding: 20px; margin: 20px 0; text-align: center; border-radius: 10px; }
          .verification-code { font-size: 32px; font-weight: bold; color: #1976d2; 
                               letter-spacing: 8px; font-family: monospace; }
          .footer { padding: 20px; text-align: center; font-size: 12px; color: #666; }
          .security-note { background-color: #e8f5e9; padding: 15px; margin: 15px 0; 
                           border-left: 4px solid #4caf50; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔐 Password Reset Code</h1>
          </div>
          <div class="content">
            <p>We received a request to reset your password for your E-Learning System account.</p>
            
            <div class="warning">
              <strong>⚠️ Important:</strong> If you did not request this password reset, please ignore this email. Your account is still secure.
            </div>
            
            <p>Use the following verification code to reset your password:</p>
            
            <div class="code-box">
              <p style="margin: 0; color: #666; font-size: 14px;">Your Verification Code:</p>
              <div class="verification-code">${resetCode}</div>
              <p style="margin: 10px 0 0 0; color: #666; font-size: 12px;">Enter this code in the password reset form</p>
            </div>
            
            <div class="security-note">
              <strong>🔒 Security Information:</strong><br>
              • This code will expire in 15 minutes for security reasons<br>
              • You can only use this code once<br>
              • If the code expires, you can request a new password reset<br>
              • Never share this code with anyone
            </div>
            
            <p><strong>How to use this code:</strong></p>
            <ol>
              <li>Go back to the password reset page in your browser</li>
              <li>Enter your email address</li>
              <li>Enter the verification code: <strong>${resetCode}</strong></li>
              <li>Set your new password</li>
            </ol>
            
            <p>If you're having trouble, please contact your instructor or system administrator.</p>
          </div>
          <div class="footer">
            <p>Faculty of Information Technology - E-Learning System</p>
            <p>This is an automated message, please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    return this.sendEmail(user.email, subject, html);
  }
}

module.exports = new EmailService();