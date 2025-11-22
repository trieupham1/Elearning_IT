// ============================================
// E-LEARNING MANAGEMENT APP - MONGODB SEED FILE
// Using Mongoose with existing models
// ============================================

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');

// Load environment variables from parent directory
dotenv.config({ path: '../.env' });

// Import all models
const User = require('../models/User');
const Semester = require('../models/Semester');
const Course = require('../models/Course');
const Group = require('../models/Group');
const Announcement = require('../models/Announcement');
const Assignment = require('../models/Assignment');
const Submission = require('../models/Submission');
const Question = require('../models/Question');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const Material = require('../models/Material');
const ForumTopic = require('../models/ForumTopic');
const ForumReply = require('../models/ForumReply');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const Comment = require('../models/Comment');

const SALT_ROUNDS = 10;

// Store IDs for relationships
const ids = {
  instructor: null,
  students: [],
  semesters: [],
  courses: [],
  groups: [],
  announcements: [],
  assignments: [],
  materials: [],
  questions: [],
  quizzes: [],
  forumTopics: []
};

async function seedDatabase() {
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

    // Clear existing data
    console.log('\nClearing existing collections...');
    await User.deleteMany({});
    await Semester.deleteMany({});
    await Course.deleteMany({});
    await Group.deleteMany({});
    await Announcement.deleteMany({});
    await Assignment.deleteMany({});
    await Submission.deleteMany({});
    await Question.deleteMany({});
    await Quiz.deleteMany({});
    await QuizAttempt.deleteMany({});
    await Material.deleteMany({});
    await ForumTopic.deleteMany({});
    await ForumReply.deleteMany({});
    await Message.deleteMany({});
    await Notification.deleteMany({});
    await Comment.deleteMany({});
    console.log('✓ All collections cleared');

    const now = new Date();

    // ============================================
    // 1. SEED USERS (INSTRUCTOR + STUDENTS)
    // ============================================
    console.log('\nSeeding users...');
    
    // Hash passwords
    const hashedAdminPassword = await bcrypt.hash('admin', SALT_ROUNDS);
    const hashedStudentPassword = await bcrypt.hash('student123', SALT_ROUNDS);

    // Create instructor
    const instructor = await User.create({
      username: 'maivanmanh',
      password: hashedAdminPassword,
      role: 'instructor',
      firstName: 'Mai Van',
      lastName: 'Manh',
      email: 'admin@fit.edu.vn',
      profilePicture: 'https://ui-avatars.com/api/?name=Mai+Van+Manh&size=200',
      phoneNumber: '+84123456789',
      department: 'Faculty of Information Technology',
      bio: 'Lecturer in Cross-Platform Mobile Application Development',
      isActive: true
    });

    ids.instructor = instructor._id;
    console.log('✓ Created instructor account');

    // Student data
    const studentData = [
      { firstName: 'Nguyen Van', lastName: 'An', studentId: '20210001', email: 'nguyenvanan@student.fit.edu.vn' },
      { firstName: 'Tran Thi', lastName: 'Binh', studentId: '20210002', email: 'tranthbinh@student.fit.edu.vn' },
      { firstName: 'Le Hoang', lastName: 'Cuong', studentId: '20210003', email: 'lehoangcuong@student.fit.edu.vn' },
      { firstName: 'Pham Thi', lastName: 'Dung', studentId: '20210004', email: 'phamthidung@student.fit.edu.vn' },
      { firstName: 'Hoang Van', lastName: 'Em', studentId: '20210005', email: 'hoangvanem@student.fit.edu.vn' },
      { firstName: 'Vo Thi', lastName: 'Phuong', studentId: '20210006', email: 'vothiphuong@student.fit.edu.vn' },
      { firstName: 'Dang Van', lastName: 'Giang', studentId: '20210007', email: 'dangvangiang@student.fit.edu.vn' },
      { firstName: 'Bui Thi', lastName: 'Ha', studentId: '20210008', email: 'buithiha@student.fit.edu.vn' },
      { firstName: 'Ngo Van', lastName: 'Hieu', studentId: '20210009', email: 'ngovanhieu@student.fit.edu.vn' },
      { firstName: 'Tran Thi', lastName: 'Kim', studentId: '20210010', email: 'tranthikim@student.fit.edu.vn' },
      { firstName: 'Le Van', lastName: 'Long', studentId: '20210011', email: 'levanlong@student.fit.edu.vn' },
      { firstName: 'Pham Thi', lastName: 'Mai', studentId: '20210012', email: 'phamthimai@student.fit.edu.vn' },
      { firstName: 'Nguyen Van', lastName: 'Nam', studentId: '20210013', email: 'nguyenvannam@student.fit.edu.vn' },
      { firstName: 'Tran Thi', lastName: 'Oanh', studentId: '20210014', email: 'tranthioanh@student.fit.edu.vn' },
      { firstName: 'Le Van', lastName: 'Phong', studentId: '20210015', email: 'levanphong@student.fit.edu.vn' },
      { firstName: 'Hoang Thi', lastName: 'Quynh', studentId: '20210016', email: 'hoangthiquynh@student.fit.edu.vn' },
      { firstName: 'Vo Van', lastName: 'Son', studentId: '20210017', email: 'vovanson@student.fit.edu.vn' },
      { firstName: 'Dang Thi', lastName: 'Thao', studentId: '20210018', email: 'dangthithao@student.fit.edu.vn' },
      { firstName: 'Bui Van', lastName: 'Tuan', studentId: '20210019', email: 'buivantuan@student.fit.edu.vn' },
      { firstName: 'Ngo Thi', lastName: 'Uyen', studentId: '20210020', email: 'ngothiuyen@student.fit.edu.vn' }
    ];

    // Create students
    const students = [];
    for (const data of studentData) {
      const username = `${data.firstName}${data.lastName}`.replace(/\s+/g, '').toLowerCase();
      const fullName = `${data.firstName} ${data.lastName}`;
      
      const student = await User.create({
        username: username,
        password: hashedStudentPassword,
        role: 'student',
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
        profilePicture: `https://ui-avatars.com/api/?name=${encodeURIComponent(fullName)}&size=200`,
        phoneNumber: `+849${Math.floor(10000000 + Math.random() * 90000000)}`,
        studentId: data.studentId,
        department: 'Faculty of Information Technology',
        bio: '',
        isActive: true
      });
      students.push(student);
      ids.students.push(student._id);
    }

    console.log(`✓ Created ${students.length} students`);

    // ============================================
    // 2. SEED SEMESTERS
    // ============================================
    console.log('\nSeeding semesters...');

    const semester1 = await Semester.create({
      code: '2024-2',
      name: 'Semester 2, Academic Year 2024-2025',
      year: 2024,
      startDate: new Date('2025-01-15'),
      endDate: new Date('2025-05-30'),
      isActive: false
    });

    const semester2 = await Semester.create({
      code: '2025-1',
      name: 'Semester 1, Academic Year 2025-2026',
      year: 2025,
      startDate: new Date('2025-08-01'),
      endDate: new Date('2026-01-15'),
      isActive: true
    });

    ids.semesters = [semester1._id, semester2._id];
    console.log('✓ Created 2 semesters');

    // ============================================
    // 3. SEED COURSES
    // ============================================
    console.log('\nSeeding courses...');

    const courses = await Course.insertMany([
      {
        code: 'CPM502071',
        name: 'Cross-Platform Mobile Application Development',
        description: 'Learn Flutter and Dart for building cross-platform mobile applications',
        instructor: ids.instructor,
        semester: semester2._id,
        sessions: 15,
        color: '#2196F3',
        students: ids.students.slice(0, 10)
      },
      {
        code: 'DB502042',
        name: 'Database Management Systems',
        description: 'Advanced concepts in database design, SQL, and NoSQL databases',
        instructor: ids.instructor,
        semester: semester2._id,
        sessions: 15,
        color: '#4CAF50',
        students: ids.students.slice(5, 15)
      },
      {
        code: 'AI502083',
        name: 'Artificial Intelligence',
        description: 'Introduction to AI concepts, machine learning, and neural networks',
        instructor: ids.instructor,
        semester: semester2._id,
        sessions: 15,
        color: '#9C27B0',
        students: ids.students.slice(8, 18)
      },
      {
        code: 'WEB502031',
        name: 'Web Programming and Applications',
        description: 'HTML, CSS, JavaScript, and modern web frameworks',
        instructor: ids.instructor,
        semester: semester1._id,
        sessions: 15,
        color: '#FF9800',
        students: ids.students.slice(0, 12)
      }
    ]);

    ids.courses = courses.map(c => c._id);
    console.log(`✓ Created ${courses.length} courses`);

    // ============================================
    // 4. SEED GROUPS
    // ============================================
    console.log('\nSeeding groups...');

    const groups = [];
    
    // Create 3 groups for each current semester course
    for (let i = 0; i < 3; i++) {
      for (let j = 0; j < 3; j++) {
        groups.push({
          name: `Group ${j + 1}`,
          courseId: ids.courses[i],
          members: ids.students.slice(j * 3, j * 3 + 3),
          createdBy: ids.students[0],
          description: `Study group ${j + 1} for ${courses[i].name}`
        });
      }
    }

    // Create 2 groups for past semester course
    for (let j = 0; j < 2; j++) {
      groups.push({
        name: `Group ${j + 1}`,
        courseId: ids.courses[3],
        members: ids.students.slice(j * 5, j * 5 + 5),
        createdBy: ids.students[0],
        description: `Study group ${j + 1} for ${courses[3].name}`
      });
    }

    const createdGroups = await Group.insertMany(groups);
    ids.groups = createdGroups.map(g => g._id);
    console.log(`✓ Created ${groups.length} groups`);

    // ============================================
    // 5. SEED ANNOUNCEMENTS
    // ============================================
    console.log('\nSeeding announcements...');

    const announcements = await Announcement.insertMany([
      {
        courseId: ids.courses[0],
        title: 'Welcome to Cross-Platform Mobile Development!',
        content: '<p>Welcome to the course! We will be learning <strong>Flutter</strong> and <strong>Dart</strong> to build amazing mobile applications.</p><p>Please review the syllabus attached below.</p>',
        attachments: [
          {
            filename: 'syllabus.pdf',
            url: 'https://example.com/files/syllabus.pdf',
            size: 1024000,
            mimeType: 'application/pdf'
          }
        ],
        authorId: ids.instructor,
        authorName: 'Mai Van Manh',
        publishedAt: new Date()
      },
      {
        courseId: ids.courses[0],
        title: 'Lab Session Schedule',
        content: '<p>Lab sessions will be held every Monday and Wednesday. Please check the schedule for your group.</p>',
        attachments: [],
        authorId: ids.instructor,
        authorName: 'Mai Van Manh',
        publishedAt: new Date()
      }
    ]);

    ids.announcements = announcements.map(a => a._id);
    console.log(`✓ Created ${announcements.length} announcements`);

    // ============================================
    // 6. SEED ASSIGNMENTS
    // ============================================
    console.log('\nSeeding assignments...');

    const assignments = await Assignment.insertMany([
      {
        courseId: ids.courses[0],
        title: 'Lab 01: Flutter Basics',
        description: 'Complete the basic Flutter exercises including widget creation and state management.',
        attachments: [
          {
            filename: 'lab01_instructions.pdf',
            url: 'https://example.com/assignments/lab01.pdf',
            size: 2048000,
            mimeType: 'application/pdf'
          }
        ],
        startDate: new Date(),
        deadline: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
        maxScore: 10,
        createdBy: ids.instructor,
        createdByName: 'Mai Van Manh',
        authorId: ids.instructor
      },
      {
        courseId: ids.courses[0],
        title: 'Lab 02: State Management',
        description: 'Implement state management using Provider and Riverpod.',
        attachments: [],
        startDate: new Date(),
        deadline: new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000),
        maxScore: 10,
        createdBy: ids.instructor,
        createdByName: 'Mai Van Manh',
        authorId: ids.instructor
      }
    ]);

    ids.assignments = assignments.map(a => a._id);
    console.log(`✓ Created ${assignments.length} assignments`);

    // ============================================
    // 7. SEED SUBMISSIONS
    // ============================================
    console.log('\nSeeding submissions...');

    const submissions = await Submission.insertMany([
      {
        assignmentId: ids.assignments[0],
        studentId: ids.students[0],
        studentName: 'Nguyen Van An',
        files: [
          {
            filename: 'lab01_nguyen_van_an.zip',
            url: 'https://example.com/submissions/abc123.zip',
            size: 3145728,
            mimeType: 'application/zip'
          }
        ],
        submittedAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
        grade: 9.5,
        feedback: 'Excellent work! Very clean code.',
        gradedAt: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000),
        gradedBy: ids.instructor
      },
      {
        assignmentId: ids.assignments[0],
        studentId: ids.students[1],
        studentName: 'Tran Thi Binh',
        files: [
          {
            filename: 'lab01_tran_thi_binh.zip',
            url: 'https://example.com/submissions/def456.zip',
            size: 2621440,
            mimeType: 'application/zip'
          }
        ],
        submittedAt: new Date()
      }
    ]);

    console.log(`✓ Created ${submissions.length} submissions`);

    // ============================================
    // 8. SEED QUESTION BANK
    // ============================================
    console.log('\nSeeding question bank...');

    const questions = await Question.insertMany([
      {
        courseId: ids.courses[0],
        questionText: 'What is Flutter?',
        choices: [
          { label: 'A', text: 'A mobile framework by Google', isCorrect: true },
          { label: 'B', text: 'A programming language', isCorrect: false },
          { label: 'C', text: 'A database system', isCorrect: false },
          { label: 'D', text: 'An operating system', isCorrect: false }
        ],
        difficulty: 'easy',
        topic: 'Flutter Basics',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'Which programming language is used by Flutter?',
        choices: [
          { label: 'A', text: 'Java', isCorrect: false },
          { label: 'B', text: 'Kotlin', isCorrect: false },
          { label: 'C', text: 'Dart', isCorrect: true },
          { label: 'D', text: 'Swift', isCorrect: false }
        ],
        difficulty: 'easy',
        topic: 'Flutter Basics',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'What is a StatefulWidget in Flutter?',
        choices: [
          { label: 'A', text: 'A widget that never changes', isCorrect: false },
          { label: 'B', text: 'A widget that can change its state during runtime', isCorrect: true },
          { label: 'C', text: 'A widget for displaying images', isCorrect: false },
          { label: 'D', text: 'A widget for handling HTTP requests', isCorrect: false }
        ],
        difficulty: 'medium',
        topic: 'Widgets',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'Which method is called when a StatefulWidget is first created?',
        choices: [
          { label: 'A', text: 'build()', isCorrect: false },
          { label: 'B', text: 'initState()', isCorrect: true },
          { label: 'C', text: 'dispose()', isCorrect: false },
          { label: 'D', text: 'setState()', isCorrect: false }
        ],
        difficulty: 'medium',
        topic: 'Widget Lifecycle',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'What is the purpose of the BuildContext in Flutter?',
        choices: [
          { label: 'A', text: 'To store application state', isCorrect: false },
          { label: 'B', text: 'To locate widgets in the widget tree', isCorrect: true },
          { label: 'C', text: 'To manage HTTP connections', isCorrect: false },
          { label: 'D', text: 'To handle user input', isCorrect: false }
        ],
        difficulty: 'hard',
        topic: 'Advanced Concepts',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'Which Flutter widget is used to display scrollable content?',
        choices: [
          { label: 'A', text: 'Container', isCorrect: false },
          { label: 'B', text: 'ListView', isCorrect: true },
          { label: 'C', text: 'Text', isCorrect: false },
          { label: 'D', text: 'AppBar', isCorrect: false }
        ],
        difficulty: 'easy',
        topic: 'Widgets',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'What is hot reload in Flutter?',
        choices: [
          { label: 'A', text: 'A feature to restart the entire application', isCorrect: false },
          { label: 'B', text: 'A feature to inject updated source code into the running app', isCorrect: true },
          { label: 'C', text: 'A debugging tool', isCorrect: false },
          { label: 'D', text: 'A testing framework', isCorrect: false }
        ],
        difficulty: 'easy',
        topic: 'Development Tools',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'Which state management solution is built by the Flutter team?',
        choices: [
          { label: 'A', text: 'Redux', isCorrect: false },
          { label: 'B', text: 'MobX', isCorrect: false },
          { label: 'C', text: 'Provider', isCorrect: true },
          { label: 'D', text: 'GetX', isCorrect: false }
        ],
        difficulty: 'medium',
        topic: 'State Management',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'What does the async keyword do in Dart?',
        choices: [
          { label: 'A', text: 'Makes a function return a Future', isCorrect: true },
          { label: 'B', text: 'Makes a function run faster', isCorrect: false },
          { label: 'C', text: 'Prevents errors in code', isCorrect: false },
          { label: 'D', text: 'Creates a new thread', isCorrect: false }
        ],
        difficulty: 'hard',
        topic: 'Asynchronous Programming',
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        questionText: 'Which Flutter layout widget allows children to be positioned absolutely?',
        choices: [
          { label: 'A', text: 'Column', isCorrect: false },
          { label: 'B', text: 'Row', isCorrect: false },
          { label: 'C', text: 'Stack', isCorrect: true },
          { label: 'D', text: 'Wrap', isCorrect: false }
        ],
        difficulty: 'medium',
        topic: 'Layouts',
        authorId: ids.instructor,
        createdBy: ids.instructor
      }
    ]);

    ids.questions = questions.map(q => q._id);
    console.log(`✓ Created ${questions.length} questions`);

    // ============================================
    // 9. SEED QUIZZES
    // ============================================
    console.log('\nSeeding quizzes...');

    const quizzes = await Quiz.insertMany([
      {
        courseId: ids.courses[0],
        title: 'Quiz 1: Flutter Fundamentals',
        description: 'Test your knowledge of Flutter basics and core concepts',
        questions: ids.questions,
        duration: 30,
        openDate: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
        closeDate: new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000),
        maxScore: 10,
        authorId: ids.instructor,
        createdBy: ids.instructor
      }
    ]);

    ids.quizzes = quizzes.map(q => q._id);
    console.log(`✓ Created ${quizzes.length} quizzes`);

    // ============================================
    // 10. SEED MATERIALS
    // ============================================
    console.log('\nSeeding materials...');

    const materials = await Material.insertMany([
      {
        courseId: ids.courses[0],
        title: 'Lecture 01: Introduction to Flutter',
        description: 'Slides and resources for the first lecture covering Flutter basics',
        files: [
          {
            filename: 'lecture01_slides.pdf',
            url: 'https://example.com/materials/lecture01.pdf',
            size: 5242880,
            mimeType: 'application/pdf'
          }
        ],
        authorId: ids.instructor,
        createdBy: ids.instructor
      },
      {
        courseId: ids.courses[0],
        title: 'Lecture 02: Widgets and Layouts',
        description: 'Understanding Flutter widgets and layout system',
        files: [
          {
            filename: 'lecture02_slides.pdf',
            url: 'https://example.com/materials/lecture02.pdf',
            size: 6291456,
            mimeType: 'application/pdf'
          }
        ],
        authorId: ids.instructor,
        createdBy: ids.instructor
      }
    ]);

    ids.materials = materials.map(m => m._id);
    console.log(`✓ Created ${materials.length} materials`);

    // ============================================
    // SUMMARY
    // ============================================
    console.log('\n========================================');
    console.log('✅ DATABASE SEEDING COMPLETED!');
    console.log('========================================\n');
    
    console.log('Summary:');
    console.log(`✓ 1 instructor`);
    console.log(`✓ ${students.length} students`);
    console.log(`✓ 2 semesters (1 active, 1 past)`);
    console.log(`✓ ${courses.length} courses`);
    console.log(`✓ ${groups.length} study groups`);
    console.log(`✓ ${announcements.length} announcements`);
    console.log(`✓ ${assignments.length} assignments`);
    console.log(`✓ ${submissions.length} submissions`);
    console.log(`✓ ${questions.length} questions`);
    console.log(`✓ ${quizzes.length} quizzes`);
    console.log(`✓ ${materials.length} materials\n`);

    console.log('Login Credentials:');
    console.log('==================');
    console.log('Instructor:');
    console.log('  Username: maivmanh');
    console.log('  Password: admin\n');
    console.log('Students:');
    console.log('  Username: nguyenvanan (or tranthbinh, lehoangcuong, etc.)');
    console.log('  Password: student123\n');

    console.log('Sample Usernames:');
    console.log('  - nguyenvanan (Nguyen Van An)');
    console.log('  - tranthbinh (Tran Thi Binh)');
    console.log('  - lehoangcuong (Le Hoang Cuong)');
    console.log('  - phamthidung (Pham Thi Dung)');
    console.log('  - hoangvanem (Hoang Van Em)');
    console.log('  ... and 15 more students\n');

  } catch (error) {
    console.error('❌ Error seeding database:', error);
    process.exit(1);
  } finally {
    await mongoose.connection.close();
    console.log('Database connection closed');
    process.exit(0);
  }
}

// Run the seed function
seedDatabase();