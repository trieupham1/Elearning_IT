// Test email configuration
require('dotenv').config();
const emailService = require('./utils/emailService'); // Import the instance directly

async function testEmail() {
  
  // Replace with your test email
  const testEmail = 'khangjaki12@gmail.com'; // Testing with your own email
  
  try {
    console.log('Testing email configuration...');
    console.log('EMAIL_USER:', process.env.EMAIL_USER);
    console.log('EMAIL_SERVICE:', process.env.EMAIL_SERVICE);
    
    const result = await emailService.sendEmail(
      testEmail,
      'Test Email from E-Learning System',
      `
        <h2>Test Email</h2>
        <p>If you receive this email, your nodemailer configuration is working correctly!</p>
        <p>Sent at: ${new Date().toLocaleString()}</p>
      `
    );
    
    if (result) {
      console.log('✅ Email sent successfully!');
    } else {
      console.log('❌ Email failed to send');
    }
  } catch (error) {
    console.error('❌ Email test failed:', error.message);
  }
}

testEmail();