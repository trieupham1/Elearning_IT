// utils/notifications.js
const Notification = require('../models/Notification');

/**
 * Generic function to create a notification
 * @param {Object} notificationData - Notification data
 * @param {String} notificationData.userId - User ID to notify
 * @param {String} notificationData.type - Notification type (assignment, quiz, announcement, etc.)
 * @param {String} notificationData.title - Notification title
 * @param {String} notificationData.message - Notification message
 * @param {Object} notificationData.data - Additional data
 * @returns {Promise<Object>} Created notification
 */
async function createNotification({ userId, type, title, message, data = {} }) {
  try {
    return await Notification.createNotification({
      userId,
      type,
      title,
      message,
      data
    });
  } catch (error) {
    console.error('Error creating notification:', error);
    throw error;
  }
}

/**
 * Create multiple notifications at once
 * @param {Array<Object>} notifications - Array of notification objects
 * @returns {Promise<Array>} Created notifications
 */
async function createBulkNotifications(notifications) {
  try {
    return await Notification.createBulkNotifications(notifications);
  } catch (error) {
    console.error('Error creating bulk notifications:', error);
    throw error;
  }
}

module.exports = {
  createNotification,
  createBulkNotifications
};
