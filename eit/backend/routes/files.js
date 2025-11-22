const express = require('express');
const mongoose = require('mongoose');
const multer = require('multer');
const { GridFSBucket } = require('mongodb');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// GridFS bucket - will be initialized in server.js
let gfsBucket;

const initializeGridFS = (bucket) => {
  gfsBucket = bucket;
};

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB
  }
});

// Upload file to GridFS
router.post('/upload', authMiddleware, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    
    if (!gfsBucket) {
      return res.status(500).json({ message: 'File storage not initialized' });
    }
    
    const uploadStream = gfsBucket.openUploadStream(req.file.originalname, {
      contentType: req.file.mimetype,
      metadata: {
        uploadedBy: req.user.userId,
        uploadedAt: new Date()
      }
    });
    
    uploadStream.end(req.file.buffer);
    
    uploadStream.on('finish', () => {
      const response = {
        fileId: uploadStream.id,
        fileName: req.file.originalname,
        fileSize: req.file.size,
        mimeType: req.file.mimetype,
        fileUrl: `/files/${uploadStream.id}`
      };
      console.log('File uploaded successfully. Returning:', JSON.stringify(response));
      res.json(response);
    });
    
    uploadStream.on('error', (error) => {
      res.status(500).json({ message: 'Upload failed', error: error.message });
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Download file from GridFS
router.get('/:fileId', async (req, res) => {
  try {
    if (!gfsBucket) {
      return res.status(500).json({ message: 'File storage not initialized' });
    }
    
    const fileId = new mongoose.Types.ObjectId(req.params.fileId);
    
    const files = await gfsBucket.find({ _id: fileId }).toArray();
    if (!files || files.length === 0) {
      return res.status(404).json({ message: 'File not found' });
    }
    
    const file = files[0];
    res.set('Content-Type', file.contentType);
    res.set('Content-Disposition', `attachment; filename="${file.filename}"`);
    
    const downloadStream = gfsBucket.openDownloadStream(fileId);
    downloadStream.pipe(res);
  } catch (error) {
    res.status(500).json({ message: 'Download failed', error: error.message });
  }
});

// Get file metadata
router.get('/:fileId/info', authMiddleware, async (req, res) => {
  try {
    if (!gfsBucket) {
      return res.status(500).json({ message: 'File storage not initialized' });
    }
    
    const fileId = new mongoose.Types.ObjectId(req.params.fileId);
    
    const files = await gfsBucket.find({ _id: fileId }).toArray();
    if (!files || files.length === 0) {
      return res.status(404).json({ message: 'File not found' });
    }
    
    const file = files[0];
    res.json({
      fileId: file._id,
      fileName: file.filename,
      fileSize: file.length,
      mimeType: file.contentType,
      uploadedAt: file.metadata?.uploadedAt,
      uploadedBy: file.metadata?.uploadedBy
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete file
router.delete('/:fileId', authMiddleware, async (req, res) => {
  try {
    if (!gfsBucket) {
      return res.status(500).json({ message: 'File storage not initialized' });
    }
    
    const fileId = new mongoose.Types.ObjectId(req.params.fileId);
    await gfsBucket.delete(fileId);
    res.json({ message: 'File deleted' });
  } catch (error) {
    res.status(500).json({ message: 'Delete failed', error: error.message });
  }
});

module.exports = { router, initializeGridFS };