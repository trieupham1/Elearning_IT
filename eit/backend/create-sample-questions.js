// Script to create sample questions for testing
const mongoose = require('mongoose');
const Question = require('./models/Question');
require('dotenv').config();

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/elearning');

const sampleQuestions = [
  {
    courseId: "68ea917d8f7467f25bbfaed1", // You can change this to your actual courseId
    createdBy: "68ea917c8f7467f25bbfaea1", // You can change this to your actual instructor ID
    questionText: "What is the capital of France?",
    choices: [
      { text: "London", isCorrect: false },
      { text: "Berlin", isCorrect: false }, 
      { text: "Paris", isCorrect: true },
      { text: "Madrid", isCorrect: false }
    ],
    difficulty: "easy",
    explanation: "Paris is the capital and largest city of France.",
    category: "geography",
    tags: ["geography", "capitals", "france"]
  },
  {
    courseId: "68ea917d8f7467f25bbfaed1", // You can change this
    createdBy: "68ea917c8f7467f25bbfaea1", // You can change this
    questionText: "Which programming language is used for Android development?",
    choices: [
      { text: "Python", isCorrect: false },
      { text: "Java", isCorrect: true },
      { text: "Ruby", isCorrect: false },
      { text: "PHP", isCorrect: false }
    ],
    difficulty: "medium",
    explanation: "Java is the primary programming language for Android development, along with Kotlin.",
    category: "programming",
    tags: ["android", "java", "programming"]
  },
  {
    courseId: "68ea917d8f7467f25bbfaed1", // You can change this
    createdBy: "68ea917c8f7467f25bbfaea1", // You can change this
    questionText: "What is the time complexity of binary search?",
    choices: [
      { text: "O(n)", isCorrect: false },
      { text: "O(log n)", isCorrect: true },
      { text: "O(n²)", isCorrect: false },
      { text: "O(1)", isCorrect: false }
    ],
    difficulty: "hard",
    explanation: "Binary search has O(log n) time complexity because it eliminates half of the search space in each iteration.",
    category: "algorithms",
    tags: ["algorithms", "complexity", "search"]
  }
];

async function createSampleQuestions() {
  try {
    console.log('🔍 Creating sample questions...');
    
    // Clear existing questions for this course (optional)
    // await Question.deleteMany({ courseId: sampleQuestions[0].courseId });
    
    // Create new sample questions
    for (const questionData of sampleQuestions) {
      const question = new Question(questionData);
      await question.save();
      console.log(`✅ Created question: ${question.questionText.substring(0, 50)}...`);
    }
    
    console.log(`🎉 Successfully created ${sampleQuestions.length} sample questions!`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating sample questions:', error);
    process.exit(1);
  }
}

createSampleQuestions();