const axios = require('axios');

// Judge0 CE (Community Edition) API configuration
const JUDGE0_API_URL = process.env.JUDGE0_API_URL || 'https://judge0-ce.p.rapidapi.com';
const JUDGE0_API_KEY = process.env.JUDGE0_API_KEY || ''; // Get from RapidAPI
const JUDGE0_API_HOST = process.env.JUDGE0_API_HOST || 'judge0-ce.p.rapidapi.com';

// Language ID mappings for Judge0
const LANGUAGE_IDS = {
  'python': 71,      // Python 3.8.1
  'java': 62,        // Java (OpenJDK 13.0.1)
  'cpp': 54,         // C++ (GCC 9.2.0)
  'javascript': 63,  // JavaScript (Node.js 12.14.0)
  'c': 50            // C (GCC 9.2.0)
};

/**
 * Submit code to Judge0 for execution
 * @param {string} code - Source code to execute
 * @param {string} language - Programming language ('python', 'java', 'cpp', 'javascript', 'c')
 * @param {string} input - Standard input for the program
 * @param {number} timeLimit - Time limit in seconds (default 5)
 * @param {number} memoryLimit - Memory limit in KB (default 128000)
 * @returns {Promise<object>} Submission result
 */
async function executeCode(code, language, input = '', timeLimit = 5, memoryLimit = 128000) {
  try {
    const languageId = LANGUAGE_IDS[language];
    
    if (!languageId) {
      throw new Error(`Unsupported language: ${language}`);
    }

    // Create submission
    const submissionResponse = await axios.post(
      `${JUDGE0_API_URL}/submissions?base64_encoded=false&wait=true`,
      {
        source_code: code,
        language_id: languageId,
        stdin: input,
        cpu_time_limit_secs: timeLimit,
        memory_limit_kb: memoryLimit
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-RapidAPI-Key': JUDGE0_API_KEY,
          'X-RapidAPI-Host': JUDGE0_API_HOST
        }
      }
    );

    const result = submissionResponse.data;

    // Parse the result
    return {
      status: getStatusText(result.status.id),
      statusId: result.status.id,
      output: result.stdout || '',
      error: result.stderr || result.compile_output || '',
      executionTime: result.time ? parseFloat(result.time) * 1000 : 0, // Convert to milliseconds
      memoryUsed: result.memory || 0,
      exitCode: result.exit_code,
      message: result.status.description
    };
  } catch (error) {
    console.error('Judge0 execution error:', error.response?.data || error.message);
    throw new Error(`Code execution failed: ${error.message}`);
  }
}

/**
 * Execute code against multiple test cases
 * @param {string} code - Source code to execute
 * @param {string} language - Programming language
 * @param {Array} testCases - Array of test case objects with input and expectedOutput
 * @param {number} timeLimit - Time limit per test in seconds
 * @param {number} memoryLimit - Memory limit in KB
 * @returns {Promise<Array>} Array of test results
 */
async function executeWithTestCases(code, language, testCases, timeLimit = 5, memoryLimit = 128000) {
  const results = [];

  for (const testCase of testCases) {
    try {
      const result = await executeCode(code, language, testCase.input, timeLimit, memoryLimit);
      
      // Compare output with expected (trim whitespace for comparison)
      const actualOutput = result.output.trim();
      const expectedOutput = testCase.expectedOutput.trim();
      const passed = actualOutput === expectedOutput && result.statusId === 3; // Status 3 = Accepted

      results.push({
        testCaseId: testCase._id,
        input: testCase.input,
        expectedOutput: testCase.expectedOutput,
        actualOutput: result.output,
        status: passed ? 'passed' : (result.statusId === 3 ? 'failed' : getTestStatus(result.statusId)),
        executionTime: result.executionTime,
        memoryUsed: result.memoryUsed,
        errorMessage: result.error || (passed ? null : 'Output mismatch'),
        weight: testCase.weight || 1
      });
    } catch (error) {
      results.push({
        testCaseId: testCase._id,
        input: testCase.input,
        expectedOutput: testCase.expectedOutput,
        actualOutput: '',
        status: 'error',
        executionTime: 0,
        memoryUsed: 0,
        errorMessage: error.message,
        weight: testCase.weight || 1
      });
    }
  }

  return results;
}

/**
 * Batch submit multiple submissions to Judge0
 * @param {Array} submissions - Array of {code, language, input} objects
 * @returns {Promise<Array>} Array of submission tokens
 */
async function batchSubmit(submissions) {
  try {
    const submissionData = submissions.map(sub => ({
      source_code: sub.code,
      language_id: LANGUAGE_IDS[sub.language],
      stdin: sub.input || '',
      cpu_time_limit_secs: sub.timeLimit || 5,
      memory_limit_kb: sub.memoryLimit || 128000
    }));

    const response = await axios.post(
      `${JUDGE0_API_URL}/submissions/batch?base64_encoded=false`,
      {
        submissions: submissionData
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-RapidAPI-Key': JUDGE0_API_KEY,
          'X-RapidAPI-Host': JUDGE0_API_HOST
        }
      }
    );

    return response.data; // Returns array of submission tokens
  } catch (error) {
    console.error('Batch submission error:', error.response?.data || error.message);
    throw new Error(`Batch submission failed: ${error.message}`);
  }
}

/**
 * Get batch submission results
 * @param {Array} tokens - Array of submission tokens
 * @returns {Promise<Array>} Array of submission results
 */
async function getBatchResults(tokens) {
  try {
    const tokenString = tokens.map(t => t.token).join(',');
    
    const response = await axios.get(
      `${JUDGE0_API_URL}/submissions/batch?tokens=${tokenString}&base64_encoded=false`,
      {
        headers: {
          'X-RapidAPI-Key': JUDGE0_API_KEY,
          'X-RapidAPI-Host': JUDGE0_API_HOST
        }
      }
    );

    return response.data.submissions.map(result => ({
      status: getStatusText(result.status.id),
      statusId: result.status.id,
      output: result.stdout || '',
      error: result.stderr || result.compile_output || '',
      executionTime: result.time ? parseFloat(result.time) * 1000 : 0,
      memoryUsed: result.memory || 0,
      exitCode: result.exit_code,
      message: result.status.description
    }));
  } catch (error) {
    console.error('Batch results error:', error.response?.data || error.message);
    throw new Error(`Failed to get batch results: ${error.message}`);
  }
}

/**
 * Get status text from Judge0 status ID
 * Judge0 Status IDs:
 * 1: In Queue, 2: Processing, 3: Accepted, 4: Wrong Answer, 5: Time Limit Exceeded,
 * 6: Compilation Error, 7: Runtime Error (SIGSEGV), 8: Runtime Error (SIGXFSZ),
 * 9: Runtime Error (SIGFPE), 10: Runtime Error (SIGABRT), 11: Runtime Error (NZEC),
 * 12: Runtime Error (Other), 13: Internal Error, 14: Exec Format Error
 */
function getStatusText(statusId) {
  const statusMap = {
    1: 'queued',
    2: 'processing',
    3: 'accepted',
    4: 'wrong_answer',
    5: 'time_limit_exceeded',
    6: 'compilation_error',
    7: 'runtime_error',
    8: 'runtime_error',
    9: 'runtime_error',
    10: 'runtime_error',
    11: 'runtime_error',
    12: 'runtime_error',
    13: 'internal_error',
    14: 'runtime_error'
  };
  
  return statusMap[statusId] || 'unknown';
}

/**
 * Map Judge0 status to test case status
 */
function getTestStatus(statusId) {
  if (statusId === 5) return 'timeout';
  if (statusId === 3) return 'passed';
  if (statusId === 4) return 'failed';
  return 'error';
}

/**
 * Validate Judge0 API configuration
 */
function validateConfig() {
  if (!JUDGE0_API_KEY) {
    console.warn('⚠️  WARNING: JUDGE0_API_KEY not set in environment variables');
    console.warn('   Get your API key from: https://rapidapi.com/judge0-official/api/judge0-ce');
    return false;
  }
  return true;
}

module.exports = {
  executeCode,
  executeWithTestCases,
  batchSubmit,
  getBatchResults,
  LANGUAGE_IDS,
  validateConfig
};
