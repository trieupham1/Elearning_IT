const mongoose = require('mongoose');

const departmentSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  code: {
    type: String,
    required: true,
    unique: true,
    uppercase: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  courses: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Course'
  }],
  employees: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  headOfDepartment: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index for faster queries
departmentSchema.index({ code: 1 });
departmentSchema.index({ isActive: 1 });

// Virtual for employee count
departmentSchema.virtual('employeeCount').get(function() {
  return this.employees.length;
});

// Virtual for course count
departmentSchema.virtual('courseCount').get(function() {
  return this.courses.length;
});

// Instance method to add employee
departmentSchema.methods.addEmployee = async function(userId) {
  if (!this.employees.includes(userId)) {
    this.employees.push(userId);
    await this.save();
  }
  return this;
};

// Instance method to remove employee
departmentSchema.methods.removeEmployee = async function(userId) {
  this.employees = this.employees.filter(id => !id.equals(userId));
  await this.save();
  return this;
};

// Instance method to assign course
departmentSchema.methods.assignCourse = async function(courseId) {
  if (!this.courses.includes(courseId)) {
    this.courses.push(courseId);
    await this.save();
  }
  return this;
};

// Instance method to remove course
departmentSchema.methods.removeCourse = async function(courseId) {
  this.courses = this.courses.filter(id => !id.equals(courseId));
  await this.save();
  return this;
};

// Static method to get active departments
departmentSchema.statics.getActiveDepartments = function() {
  return this.find({ isActive: true })
    .populate('headOfDepartment', 'fullName email')
    .sort({ name: 1 });
};

// Static method to get department with full details
departmentSchema.statics.getDetailedDepartment = function(departmentId) {
  return this.findById(departmentId)
    .populate('headOfDepartment', 'firstName lastName email profilePicture')
    .populate('courses', 'title code description startDate endDate')
    .populate('employees', 'firstName lastName email role department profilePicture')
    .lean()
    .then(dept => {
      if (!dept) return null;
      
      // Manually compute fullName for populated users
      if (dept.headOfDepartment) {
        dept.headOfDepartment.fullName = 
          (dept.headOfDepartment.firstName && dept.headOfDepartment.lastName)
            ? `${dept.headOfDepartment.firstName} ${dept.headOfDepartment.lastName}`
            : dept.headOfDepartment.email?.split('@')[0] || 'Unknown';
      }
      
      if (dept.employees && Array.isArray(dept.employees)) {
        dept.employees = dept.employees.map(emp => {
          if (!emp) return null;
          return {
            _id: emp._id,
            fullName: (emp.firstName && emp.lastName)
              ? `${emp.firstName} ${emp.lastName}`
              : (emp.email ? emp.email.split('@')[0] : 'Unknown'),
            email: emp.email || '',
            role: emp.role || 'student',
            department: emp.department,
            profilePicture: emp.profilePicture
          };
        }).filter(emp => emp !== null);
      }
      
      return dept;
    });
};

module.exports = mongoose.model('Department', departmentSchema);
