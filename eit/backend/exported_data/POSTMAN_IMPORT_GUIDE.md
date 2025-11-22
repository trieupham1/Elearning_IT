# 📮 Postman Import Guide

## 🚀 Quick Start

### Step 1: Import Collection

1. **Open Postman**
2. Click **Import** button (top left)
3. **Drag & drop** this file: `E-Learning_Export_API.postman_collection.json`
4. Click **Import**
5. ✅ Done! You'll see "E-Learning Export API" collection in the left sidebar

---

### Step 2: Set Up Environment (Optional but Recommended)

1. Click **Environments** (left sidebar)
2. Click **+** to create new environment
3. Name it: `E-Learning Local`
4. Add variables:

| Variable | Initial Value | Current Value |
|----------|--------------|---------------|
| `baseUrl` | `http://localhost:5000` | `http://localhost:5000` |
| `token` | _(leave empty)_ | _(will be auto-filled)_ |

5. Click **Save**
6. Select `E-Learning Local` from dropdown (top right)

---

### Step 3: Login & Get Token

#### Option A: Auto-Login (Recommended)

1. Open collection → **Auth** → **Login (Instructor)**
2. Update credentials in Body if needed:
   ```json
   {
       "username": "your_instructor_username",
       "password": "your_password"
   }
   ```
3. Click **Send**
4. ✅ Token is **automatically saved** to environment!

#### Option B: Manual Token

1. Login via your Flutter app or another method
2. Copy the token
3. In Postman:
   - Go to **Environments**
   - Find `token` variable
   - Paste token in **Current Value**
   - Click **Save**

---

### Step 4: Test Export!    

1. Open any export request (e.g., **Export Users** → **Export All Users (Excel)**)
2. Click **Send and Download** (dropdown next to Send button)
3. ✅ File downloads to your Downloads folder!

---

## 📋 Collection Structure

```
E-Learning Export API/
├── Auth/
│   └── Login (Instructor)          ← Start here!
├── Export Users/
│   ├── Export All Users (JSON)
│   ├── Export All Users (CSV)
│   ├── Export All Users (Excel)
│   └── Export Students Only        ← Filtered example
├── Export Courses/
│   ├── Export All Courses (JSON)
│   └── Export All Courses (Excel)
├── Export Assignments/
│   ├── Export All Assignments (JSON)
│   ├── Export All Assignments (Excel)
│   └── Export Assignments by Course  ← Filtered
├── Export Submissions/
│   ├── Export All Submissions (JSON)
│   ├── Export All Submissions (Excel)
│   ├── Export Submissions by Course
│   └── Export Submissions by Assignment
├── Export Quizzes/
│   ├── Export All Quizzes (JSON)
│   └── Export All Quizzes (Excel)
├── Export Quiz Attempts/
│   ├── Export All Quiz Attempts (JSON)
│   ├── Export All Quiz Attempts (Excel)
│   └── Export Attempts by Quiz
├── Export Announcements/
│   ├── Export All Announcements (JSON)
│   └── Export All Announcements (Excel)
├── Export Full Database/           ⭐ FULL BACKUP
│   ├── Export Complete Database (Excel - Multiple Sheets)
│   └── Export Complete Database (JSON)
└── Utilities/
    ├── Cleanup Old Exports
    └── Health Check
```

---

## 🎯 Common Use Cases

### Use Case 1: Get Student Roster (CSV)
1. **Export Users** → **Export Students Only**
2. Change format in URL: `.../users/csv?role=student`
3. **Send and Download**
4. Open CSV in Excel

---

### Use Case 2: Export Grades for One Course
1. Get your course ID (from your database or app)
2. **Export Submissions** → **Export Submissions by Course**
3. Replace `YOUR_COURSE_ID` in URL with actual ID
4. **Send and Download**
5. Open Excel file with all grades!

---

### Use Case 3: Full Database Backup
1. **Export Full Database** → **Export Complete Database (Excel)**
2. **Send and Download**
3. One Excel file with 8 sheets containing everything!

---

### Use Case 4: Quiz Performance Analysis
1. Get quiz ID
2. **Export Quiz Attempts** → **Export Attempts by Quiz**
3. Replace `YOUR_QUIZ_ID` in URL
4. **Send and Download**
5. Analyze student performance in Excel!

---

## 🔧 Customizing Requests

### Change Export Format

In the URL, change the last part:
- `.../users/json` → JSON format
- `.../users/csv` → CSV format
- `.../users/excel` → Excel format

### Add Filters

Add query parameters:
```
.../users/excel?role=student
.../submissions/excel?courseId=673123abc456
.../quiz-attempts/excel?quizId=673123def789
```

### Multiple Filters

Combine with `&`:
```
.../users/excel?role=student&limit=100
```

---

## ⚙️ Variables Used

| Variable | Description | How It's Set |
|----------|-------------|--------------|
| `{{baseUrl}}` | Server URL | Set in collection or environment |
| `{{token}}` | Auth token | Auto-set by login script or manual |

---

## 🎓 Tips & Tricks

### Tip 1: Auto-Save Responses
After sending a request:
- Click **Save Response** → **Save as Example**
- Helps you remember what data looks like!

### Tip 2: Organize Your Exports
Create folders in Postman:
- Right-click collection → **Add Folder**
- Name it "My Exports" or "Weekly Backups"
- Drag useful requests there

### Tip 3: Use Pre-Request Scripts
Collection already has auto-login script!
- Login once
- Token saved automatically
- No need to manually copy/paste

### Tip 4: Batch Downloads
1. Select multiple requests
2. Right-click → **Run**
3. Postman Runner runs them all
4. Downloads all files!

---

## 🐛 Troubleshooting

### Problem: "Could not send request"
**Solution:** 
- Check if backend server is running
- Verify `baseUrl` is correct: `http://localhost:5000`

---

### Problem: "401 Unauthorized"
**Solution:**
1. Run **Auth** → **Login (Instructor)** first
2. Or check if `{{token}}` variable is set correctly
3. Token might be expired - login again

---

### Problem: "403 Forbidden"
**Solution:**
- You must be an **instructor** or **admin**
- Students cannot export data
- Check your user role in database

---

### Problem: "Send and Download" doesn't work
**Solution:**
1. Make sure you click the **dropdown** next to Send button
2. Select **Send and Download**
3. Check your Downloads folder
4. Also check `backend/exported_data/` folder

---

### Problem: File downloads but won't open
**Solution:**
- Excel files: Needs Microsoft Excel or Google Sheets
- JSON files: Open in text editor or VS Code
- CSV files: Open in Excel or Google Sheets

---

## 📊 What You'll Get

### JSON Files
```json
{
  "collection": "users",
  "exportedAt": "2025-10-17T...",
  "filters": { "role": "student" },
  "totalRecords": 150,
  "data": [ ... ]
}
```

### CSV Files
```csv
"_id","username","email","fullName","role"
"673...","student1","student1@example.com","John Doe","student"
```

### Excel Files
- Styled headers (blue background)
- Auto-filters enabled
- Proper column widths
- Multiple sheets (for database export)

---

## 🎉 You're All Set!

Now you can:
- ✅ Export any data from MongoDB
- ✅ Download in JSON, CSV, or Excel format
- ✅ Filter by course, student, quiz, etc.
- ✅ Backup entire database
- ✅ Analyze data in Excel

**Happy Exporting!** 🚀

