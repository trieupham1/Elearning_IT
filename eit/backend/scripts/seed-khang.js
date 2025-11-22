// ============================================
// SEED SPECIFIC STUDENT ACCOUNT - Tran Manh Khang
// ============================================

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');

// Load environment variables from parent directory
dotenv.config({ path: '../.env' });

// Import User model
const User = require('../models/User');

const SALT_ROUNDS = 10;

async function seedKhangAccount() {
  try {
    // Check if MONGODB_URI is available
    if (!process.env.MONGODB_URI) {
      console.error('❌ MONGODB_URI environment variable not found');
      console.error('Please make sure you have a .env file in the backend directory with MONGODB_URI');
      process.exit(1);
    }

    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✓ Connected to MongoDB Atlas');

    // Check if user already exists
    const existingUser = await User.findOne({ 
      $or: [
        { email: 'kxckhang123@gmail.com' },
        { username: 'tranmanhkhang' }
      ]
    });

    if (existingUser) {
      console.log('⚠️ User already exists with this email or username');
      console.log('Existing user:', {
        username: existingUser.username,
        email: existingUser.email,
        fullName: `${existingUser.firstName} ${existingUser.lastName}`
      });
      
      // Ask if want to update
      console.log('\nWould you like to update the existing user? (Delete and recreate)');
      // For this script, we'll just update the existing one
      await User.deleteOne({ _id: existingUser._id });
      console.log('✓ Deleted existing user');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash('khang123', SALT_ROUNDS);

    // Create your student account
    const khangStudent = await User.create({
      username: 'tranmanhkhang',
      password: hashedPassword,
      role: 'student',
      firstName: 'Tran Manh',
      lastName: 'Khang',
      email: 'kxckhang123@gmail.com',
      profilePicture: 'https://ui-avatars.com/api/?name=Tran+Manh+Khang&size=200',
      phoneNumber: '+84123456789', // You can update this
      studentId: '20210021', // Adjust the student ID as needed
      department: 'Faculty of Information Technology',
      bio: 'Computer Science Student',
      isActive: true
    });

    console.log('\n========================================');
    console.log('✅ STUDENT ACCOUNT CREATED SUCCESSFULLY!');
    console.log('========================================\n');
    
    console.log('Account Details:');
    console.log('================');
    console.log(`Name: ${khangStudent.firstName} ${khangStudent.lastName}`);
    console.log(`Username: ${khangStudent.username}`);
    console.log(`Email: ${khangStudent.email}`);
    console.log(`Student ID: ${khangStudent.studentId}`);
    console.log(`Role: ${khangStudent.role}`);
    console.log(`Password: khang123`);
    console.log(`Department: ${khangStudent.department}\n`);

    console.log('Login Credentials:');
    console.log('==================');
    console.log('Username: tranmanhkhang');
    console.log('Password: khang123\n');

    console.log('✅ You can now login to the e-learning system with these credentials!');

  } catch (error) {
    console.error('❌ Error creating student account:', error);
    process.exit(1);
  } finally {
    await mongoose.connection.close();
    console.log('\nDatabase connection closed');
    process.exit(0);
  }
}

// Run the function
seedKhangAccount();