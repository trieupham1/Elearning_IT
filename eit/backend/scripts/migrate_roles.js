// migration_script.js - Update instructor roles to admin
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('MongoDB Connected for migration'))
.catch(err => console.error('MongoDB Connection Error:', err));

const User = require('./models/User');

async function migrateRoles() {
  try {
    console.log('Starting role migration...');
    
    // Update all users with role 'instructor' to 'admin'
    const result = await User.updateMany(
      { role: 'instructor' },
      { $set: { role: 'admin' } }
    );
    
    console.log(`Migration completed: ${result.modifiedCount} users updated from 'instructor' to 'admin'`);
    
    // Display current role distribution
    const roles = await User.aggregate([
      { $group: { _id: '$role', count: { $sum: 1 } } }
    ]);
    
    console.log('Current role distribution:');
    roles.forEach(role => {
      console.log(`  ${role._id}: ${role.count} users`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
migrateRoles();