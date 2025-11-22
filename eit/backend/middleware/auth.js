const jwt = require('jsonwebtoken');

const auth = (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ message: 'No authentication token, access denied' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    req.userRole = decoded.role;
    req.user = { userId: decoded.userId, role: decoded.role }; // Add this for consistency
    
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(401).json({ message: 'Token is not valid' });
  }
};

// Add instructor/admin only middleware
const instructorOnly = (req, res, next) => {
  if (req.userRole !== 'instructor' && req.userRole !== 'admin') {
    return res.status(403).json({ message: 'Access denied. Instructors only.' });
  }
  next();
};

// Export as default and named exports for compatibility
module.exports = auth;
module.exports.authMiddleware = auth;
module.exports.instructorOnly = instructorOnly;