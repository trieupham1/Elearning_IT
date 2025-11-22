// Simple authentication test script
const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';

async function testLogin() {
  console.log('=== Authentication Test ===\n');
  
  try {
    console.log('1. Testing with invalid credentials...');
    try {
      await axios.post(`${BASE_URL}/auth/login`, {
        username: 'invalid',
        password: 'invalid'
      });
      console.log('❌ FAIL: Invalid credentials were accepted!');
    } catch (error) {
      if (error.response?.status === 401) {
        console.log('✅ PASS: Invalid credentials correctly rejected');
      } else {
        console.log('❓ UNEXPECTED:', error.response?.data || error.message);
      }
    }
    
    console.log('\n2. Testing with empty credentials...');
    try {
      await axios.post(`${BASE_URL}/auth/login`, {
        username: '',
        password: ''
      });
      console.log('❌ FAIL: Empty credentials were accepted!');
    } catch (error) {
      if (error.response?.status === 400) {
        console.log('✅ PASS: Empty credentials correctly rejected');
      } else {
        console.log('❓ UNEXPECTED:', error.response?.data || error.message);
      }
    }
    
    console.log('\n3. Testing with valid test credentials...');
    try {
      const response = await axios.post(`${BASE_URL}/auth/login`, {
        username: 'test',
        password: 'test123'
      });
      
      if (response.data.token && response.data.user) {
        console.log('✅ PASS: Valid credentials accepted');
        console.log('   Token:', response.data.token.substring(0, 20) + '...');
        console.log('   User:', response.data.user.username, '-', response.data.user.role);
        
        // Test protected endpoint
        console.log('\n4. Testing protected endpoint with token...');
        try {
          const meResponse = await axios.get(`${BASE_URL}/auth/me`, {
            headers: {
              Authorization: `Bearer ${response.data.token}`
            }
          });
          console.log('✅ PASS: Protected endpoint accessible with valid token');
          console.log('   User data:', meResponse.data.username, '-', meResponse.data.role);
        } catch (error) {
          console.log('❌ FAIL: Protected endpoint failed:', error.response?.data || error.message);
        }
        
      } else {
        console.log('❌ FAIL: Valid credentials did not return token/user');
      }
    } catch (error) {
      console.log('❌ FAIL: Valid credentials were rejected:', error.response?.data || error.message);
    }
    
    console.log('\n5. Testing with admin credentials...');
    try {
      const response = await axios.post(`${BASE_URL}/auth/login`, {
        username: 'admin',
        password: 'admin123'
      });
      
      if (response.data.token && response.data.user && response.data.user.role === 'admin') {
        console.log('✅ PASS: Admin credentials work correctly');
        console.log('   Admin user:', response.data.user.username, '-', response.data.user.role);
      } else {
        console.log('❌ FAIL: Admin login failed or incorrect role');
      }
    } catch (error) {
      console.log('❌ FAIL: Admin credentials were rejected:', error.response?.data || error.message);
    }
    
  } catch (error) {
    console.log('❌ ERROR: Test failed to run:', error.message);
    console.log('Make sure the backend server is running on port 5000');
  }
  
  console.log('\n=== Test Complete ===');
}

// Run the test
testLogin();