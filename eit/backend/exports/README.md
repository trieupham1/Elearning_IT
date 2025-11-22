# MongoDB Data Export System

This folder contains export utilities for exporting MongoDB database data from the E-Learning platform.

## 📁 Structure

```
exports/
├── dashboardExporter.js    # Database export utility (handles JSON/CSV/Excel)
└── README.md               # This file

exported_data/
└── [Generated export files]  # Auto-cleaned after 7 days
```

---

## 🎯 Features

### **What You Can Export:**
1. **Users** - All user accounts (students, instructors, admins)
2. **Courses** - All courses with instructor and semester data
3. **Assignments** - All assignments with course info
4. **Submissions** - All student submissions with grades
5. **Quizzes** - All quizzes with course info
6. **Quiz Attempts** - All quiz attempts with scores
7. **Announcements** - All course announcements
8. **Full Database** - Everything in one file (Excel with multiple sheets or JSON)

### **Export Formats:**
- **JSON** - Raw MongoDB data, perfect for backups and data migration
- **CSV** - Simple format for Excel/Google Sheets
- **Excel** - Professional format with formatted headers and filters

---

## 📡 API Endpoints

### 1. Export Users
```
GET /api/export/users/{format}
Headers: Authorization: Bearer {token}
Query Params: ?role=student (optional - filter by role)
```

**Formats:** `json`, `csv`, `excel`

**Example:**
```
GET /api/export/users/excel?role=student
→ Downloads: users_2025-10-17T10-30-00-000Z.xlsx
```

---

### 2. Export Courses
```
GET /api/export/courses/{format}
Headers: Authorization: Bearer {token}
Query Params: ?semesterId=xxx (optional - filter by semester)
```

**Formats:** `json`, `csv`, `excel`

**Example:**
```
GET /api/export/courses/json
→ Downloads: courses_2025-10-17T10-30-00-000Z.json
```

---

### 3. Export Assignments
```
GET /api/export/assignments/{format}
Headers: Authorization: Bearer {token}
Query Params: ?courseId=xxx (optional - filter by course)
```

**Formats:** `json`, `csv`, `excel`

**Example:**
```
GET /api/export/assignments/csv?courseId=673123abc456
→ Downloads: assignments_2025-10-17T10-30-00-000Z.csv
```

---

### 4. Export Submissions
```
GET /api/export/submissions/{format}
Headers: Authorization: Bearer {token}
Query Params: 
  - ?courseId=xxx (filter by course)
  - ?assignmentId=xxx (filter by assignment)
```

**Formats:** `json`, `csv`, `excel`

**Example:**
```
GET /api/export/submissions/excel?courseId=673123abc456
→ Downloads: submissions_2025-10-17T10-30-00-000Z.xlsx
```

---

### 5. Export Quizzes
```
GET /api/export/quizzes/{format}
Headers: Authorization: Bearer {token}
Query Params: ?courseId=xxx (optional - filter by course)
```

**Formats:** `json`, `csv`, `excel`

---

### 6. Export Quiz Attempts
```
GET /api/export/quiz-attempts/{format}
Headers: Authorization: Bearer {token}
Query Params: ?quizId=xxx (optional - filter by quiz)
```

**Formats:** `json`, `csv`, `excel`

**Example:**
```
GET /api/export/quiz-attempts/excel?quizId=673123def789
→ Downloads all attempts for that quiz
```

---

### 7. Export Announcements
```
GET /api/export/announcements/{format}
Headers: Authorization: Bearer {token}
Query Params: ?courseId=xxx (optional - filter by course)
```

**Formats:** `json`, `csv`, `excel`

---

### 8. Export Full Database (All Collections)
```
GET /api/export/database/{format}
Headers: Authorization: Bearer {token}
```

**Formats:** `excel` (recommended) or `json`

**Excel Format:**
- Creates one workbook with multiple sheets
- Each collection in its own sheet
- Includes: Users, Courses, Assignments, Submissions, Quizzes, Quiz Attempts, Announcements, Semesters

**JSON Format:**
- Single JSON file with all collections
- Includes statistics summary

**Example:**
```
GET /api/export/database/excel
→ Downloads: database_export_2025-10-17T10-30-00-000Z.xlsx
   (8 sheets: Users, Courses, Assignments, etc.)
```

---

### 9. Cleanup Old Files
```
GET /api/export/cleanup?days=7
Headers: Authorization: Bearer {token}
```

Deletes export files older than specified days (default: 7).

---

## 🔒 Security

- ✅ **Authentication Required**: All endpoints require valid JWT token
- ✅ **Instructor/Admin Only**: Only instructors and admins can export data
- ✅ **Password Protection**: User passwords are NEVER included in exports
- ✅ **Secure Storage**: Files stored in non-public directory
- ✅ **Auto-Cleanup**: Old files automatically deleted after 7 days

---

## 🚀 Quick Start

### Step 1: Login
```bash
POST http://localhost:5000/api/auth/login
Body: { "username": "instructor1", "password": "password" }
```

### Step 2: Copy Token from Response

### Step 3: Export Data
```bash
GET http://localhost:5000/api/export/users/excel
Headers: Authorization: Bearer YOUR_TOKEN_HERE
```

### Step 4: File Downloads Automatically

---

## 📊 Use Cases

### **Scenario 1: Backup All Course Data**
```
GET /api/export/database/excel
```
- Downloads complete backup of all data
- Perfect for archiving semester data
- Easy to review in Excel

---

### **Scenario 2: Grade Report for a Course**
```
GET /api/export/submissions/excel?courseId=123
```
- All submissions for one course
- Includes student info, grades, dates
- Ready for analysis

---

### **Scenario 3: Student Roster**
```
GET /api/export/users/csv?role=student
```
- All student accounts
- Can import to other systems
- Email list, etc.

---

### **Scenario 4: Quiz Performance Analysis**
```
GET /api/export/quiz-attempts/excel?quizId=456
```
- All attempts for specific quiz
- Student performance data
- Score statistics

---

## 💡 File Formats Explained

### **JSON Format**
```json
{
  "collection": "users",
  "exportedAt": "2025-10-17T10:30:00.000Z",
  "filters": { "role": "student" },
  "totalRecords": 150,
  "data": [
    {
      "_id": "673123abc456",
      "username": "student1",
      "email": "student1@example.com",
      "fullName": "John Doe",
      "role": "student",
      ...
    },
    ...
  ]
}
```

**Best for:**
- Database backups
- Data migration
- API integration
- Programming use

---

### **CSV Format**
```csv
"_id","username","email","fullName","role","createdAt"
"673123abc456","student1","student1@example.com","John Doe","student","2025-01-15T..."
"673123def789","student2","student2@example.com","Jane Smith","student","2025-01-16T..."
```

**Best for:**
- Quick viewing
- Import to spreadsheets
- Simple analysis
- Email lists

---

### **Excel Format**
- **Multiple Sheets** (for database export)
- **Styled Headers** (blue background, white text)
- **Auto-Filters** enabled
- **Proper Column Widths**
- **Date Formatting**

**Best for:**
- Professional reports
- Data analysis
- Presentations
- Sharing with non-technical users

---

## 🛠️ Testing with Postman

1. **Create New Request**
2. **Method**: GET
3. **URL**: `http://localhost:5000/api/export/users/excel`
4. **Headers**: Add `Authorization: Bearer YOUR_TOKEN`
5. **Click "Send and Download"**
6. **File downloads to your Downloads folder**

---

## 📂 Exported Files Location

Files are saved in:
```
backend/exported_data/
```

**Naming Convention:**
```
{collection}_{timestamp}.{extension}

Examples:
- users_2025-10-17T10-30-00-000Z.xlsx
- courses_2025-10-17T10-30-00-000Z.json
- database_export_2025-10-17T10-30-00-000Z.xlsx
```

---

## 🧹 Automatic Cleanup

- Files older than **7 days** are automatically deleted
- Prevents disk space issues
- Can be customized via cleanup endpoint
- Runs when you call `/api/export/cleanup`

---

## ⚙️ Dependencies

Required npm packages:
```bash
npm install exceljs
```

Already installed if you followed the setup!

---

## 🎓 Best Practices

1. **Regular Backups**: Export database monthly
2. **Course Archives**: Export each course at semester end
3. **Grade Records**: Keep submission exports for records
4. **Data Analysis**: Use Excel exports for insights
5. **Secure Storage**: Keep exports in secure location

---

## ❓ Troubleshooting

**"401 Unauthorized"**
→ Token expired. Login again.

**"403 Forbidden"**
→ Only instructors/admins can export data. Check your role.

**"No data found"**
→ Collection is empty or filters returned no results.

**File won't download**
→ Click "Send and Download" in Postman, not just "Send".

---

## 🔮 Future Enhancements

- [ ] Scheduled automatic backups
- [ ] Email delivery of exports
- [ ] Custom field selection
- [ ] Date range filtering
- [ ] Export templates
- [ ] Data anonymization option
