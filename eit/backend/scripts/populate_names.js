// Script to populate missing firstName and lastName from emails
const mongoose = require('mongoose');
const User = require('../models/User');
require('dotenv').config();

async function populateNames() {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/elearning');
    console.log('Connected to MongoDB');

    // Find all users without firstName or lastName
    const users = await User.find({
      $or: [
        { firstName: { $exists: false } },
        { firstName: null },
        { firstName: '' },
        { lastName: { $exists: false } },
        { lastName: null },
        { lastName: '' }
      ]
    });

    console.log(`Found ${users.length} users without proper names`);

    for (const user of users) {
      let firstName = user.firstName;
      let lastName = user.lastName;

      // Extract name from email if not set
      if (!firstName || !lastName) {
        // Try to extract from email (e.g., nguyenvanan@student.fit.edu.vn)
        const emailPart = user.email.split('@')[0];
        
        // Common Vietnamese name patterns
        // Try to split camelCase or extract from username
        let nameParts = [];
        
        if (emailPart.includes('.')) {
          // Email like "nguyen.van.an" -> ["Nguyen", "Van An"]
          nameParts = emailPart.split('.');
        } else {
          // Try to parse camelCase like "nguyenvanan"
          // This is simplified - just take first part as last name
          if (emailPart.length > 3) {
            // Assume first 3-4 chars is last name for Vietnamese names
            nameParts = [emailPart.substring(0, 4), emailPart.substring(4)];
          }
        }

        if (nameParts.length >= 1 && !lastName) {
          // First part is typically last name in Vietnamese
          lastName = capitalize(nameParts[0]);
        }
        
        if (nameParts.length >= 2 && !firstName) {
          // Rest is first name
          firstName = nameParts.slice(1).map(capitalize).join(' ');
        }

        // Fallback to username if still empty
        if (!firstName) {
          firstName = capitalize(user.username);
        }
        if (!lastName) {
          lastName = '';
        }
      }

      // Update user
      user.firstName = firstName;
      user.lastName = lastName;
      await user.save();
      
      console.log(`Updated ${user.email}: ${lastName} ${firstName}`);
    }

    console.log('Migration complete!');
    process.exit(0);
  } catch (error) {
    console.error('Migration error:', error);
    process.exit(1);
  }
}

function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
}

populateNames();
