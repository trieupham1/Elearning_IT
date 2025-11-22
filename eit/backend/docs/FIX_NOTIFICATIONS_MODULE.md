# Backend Fix: Missing Notifications Module

## Date: January 2025

## Issue
Backend server failed to start with the following error:
```
Error: Cannot find module '../utils/notifications'
Require stack:
- backend\routes\assignments.js
- backend\server.js
```

## Root Cause
The `assignments.js` route was trying to import `createNotification` from `../utils/notifications`, but this file didn't exist. The backend only had `notificationHelper.js` which exports specific notification functions but not a generic `createNotification` function.

## Solution
Created a new `backend/utils/notifications.js` file that provides:

### 1. Generic Notification Creation
```javascript
async function createNotification({ userId, type, title, message, data = {} })
```

### 2. Bulk Notification Creation
```javascript
async function createBulkNotifications(notifications)
```

## File Created
**File:** `backend/utils/notifications.js`

**Purpose:** Provides a generic interface for creating notifications that can be used across all routes.

**Functions Exported:**
- `createNotification({ userId, type, title, message, data })` - Create a single notification
- `createBulkNotifications(notifications)` - Create multiple notifications at once

**Usage Example:**
```javascript
const { createNotification } = require('../utils/notifications');

await createNotification({
  userId: studentId,
  type: 'assignment',
  title: 'New Assignment',
  message: `Assignment "${title}" has been created`,
  data: {
    assignmentId,
    courseId,
    deadline
  }
});
```

## Distinction from notificationHelper.js

### notifications.js (NEW)
- Generic, low-level notification creation
- Direct wrapper around Notification model
- Used for custom notifications
- Example: `createNotification({ userId, type, title, message, data })`

### notificationHelper.js (EXISTING)
- High-level, specific notification functions
- Pre-formatted notification templates
- Used for common notification scenarios
- Example: `notifyNewAssignment(courseId, courseName, assignmentTitle, dueDate, studentIds)`

Both files can coexist and serve different purposes:
- Use `notifications.js` for custom/generic notifications
- Use `notificationHelper.js` for standardized notifications with consistent formatting

## Testing
✅ Server starts successfully
✅ No module not found errors
✅ Connected to MongoDB
✅ Server running on port 5000

## Impact
- ✅ Backend server now starts without errors
- ✅ Assignment routes can create notifications
- ✅ All notification functionality is available
- ✅ No breaking changes to existing code

## Files Modified
- **Created:** `backend/utils/notifications.js`

## Next Steps
1. Test assignment creation notifications
2. Test assignment submission notifications
3. Test assignment grading notifications
4. Verify notifications appear in student/instructor apps

## Status
**FIXED** ✅ - Backend server running successfully on port 5000
