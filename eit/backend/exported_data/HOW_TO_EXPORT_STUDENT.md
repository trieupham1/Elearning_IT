# 🎓 How to Export All Data for a Specific Student

## 🎯 What You Get

When you export a student's complete profile, you get **EVERYTHING** related to that student in one file:

### 📊 **Excel Format (9 Sheets):**

1. **Student Info** - Personal data + statistics summary
2. **Enrolled Courses** - All courses they're taking
3. **Submissions** - All assignments they've submitted with grades
4. **Quiz Attempts** - All quiz results with scores
5. **Available Assignments** - All assignments in their courses
6. **Available Quizzes** - All quizzes in their courses  
7. **Announcements** - All announcements from their courses
8. **Notifications** - All their notifications
9. **Groups** - All groups they're members of

### 📈 **Statistics Included:**
- Total courses enrolled
- Total assignments available
- Assignments submitted
- Average assignment grade
- Total quizzes available
- Quizzes completed
- Average quiz score
- Total announcements
- Unread notifications
- Group memberships

---

## 🚀 Method 1: Using Postman (Easiest)

### Step 1: Get Student ID

First, you need the student's MongoDB ID. You can get this by:

**Option A: Export all students first**
```
GET /api/export/users/excel?role=student
```
Open the Excel file and find the student's `_id`

**Option B: Query directly in MongoDB**
```javascript
// In MongoDB Compass or shell
db.users.findOne({ username: "student1" })
// Copy the _id value
```

**Option C: From your Flutter app**
```dart
// When logged in as that student
final user = await authService.getCurrentUser();
print(user.id); // This is the student ID
```

---

### Step 2: Export in Postman

1. **Import the collection** (if you haven't):
   - Import `E-Learning_Export_API.postman_collection.json`

2. **Login** (if you haven't):
   - Run **Auth** → **Login (Instructor)**
   - Token auto-saves

3. **Run the export**:
   - Go to **Export Student (Complete Profile)** folder
   - Open **Export Student Complete Data (Excel)**
   - Replace `YOUR_STUDENT_ID` in URL with actual student ID
   - Example: `.../student/673123abc456def789/excel`
   - Click **Send and Download**

4. **File downloads!**
   - Filename: `database_export_2025-10-17T10-30-00.xlsx`
   - Contains 9 sheets with all student data

---

## 🔧 Method 2: Direct URL in Browser

If you have a valid token, you can paste this URL directly:

```
http://localhost:5000/api/export/student/YOUR_STUDENT_ID/excel
```

But you'll need to add the Authorization header somehow (browser extension like ModHeader).

---

## 💻 Method 3: Using Code

### JavaScript/Node.js:
```javascript
const axios = require('axios');
const fs = require('fs');

async function exportStudent(studentId, token) {
  const url = `http://localhost:5000/api/export/student/${studentId}/excel`;
  
  const response = await axios.get(url, {
    headers: {
      'Authorization': `Bearer ${token}`
    },
    responseType: 'arraybuffer'
  });

  fs.writeFileSync(`student_${studentId}.xlsx`, response.data);
  console.log('✅ Student data exported!');
}

// Usage
exportStudent('673123abc456def789', 'your_token_here');
```

### Python:
```python
import requests

def export_student(student_id, token):
    url = f'http://localhost:5000/api/export/student/{student_id}/excel'
    headers = {'Authorization': f'Bearer {token}'}
    
    response = requests.get(url, headers=headers)
    
    with open(f'student_{student_id}.xlsx', 'wb') as f:
        f.write(response.content)
    
    print('✅ Student data exported!')

# Usage
export_student('673123abc456def789', 'your_token_here')
```

### Flutter/Dart:
```dart
Future<void> exportStudent(String studentId, String token) async {
  final url = 'http://localhost:5000/api/export/student/$studentId/excel';
  
  final response = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/student_$studentId.xlsx');
    await file.writeAsBytes(response.bodyBytes);
    print('✅ Student data exported to ${file.path}');
  }
}
```

---

## 📋 Use Cases

### Use Case 1: Parent-Teacher Conference
```
1. Get student ID from roster
2. Export student complete data (Excel)
3. Open file before meeting
4. Review all 9 sheets:
   - Student info & stats
   - Course enrollment
   - Assignment submissions & grades
   - Quiz performance
   - Recent activity
```

### Use Case 2: Academic Review
```
1. Export student data
2. Check "Student Info" sheet for statistics:
   - Average assignment grade: 85%
   - Average quiz score: 78%
   - Completion rate: 90%
3. Review "Submissions" sheet for late work
4. Review "Quiz Attempts" sheet for struggles
```

### Use Case 3: Progress Report
```
1. Export student data at end of semester
2. Use statistics in "Student Info" sheet
3. Review "Enrolled Courses" for GPA calculation
4. Archive file for records
```

### Use Case 4: Student Transfer
```
1. Export complete student profile
2. JSON format for data migration
3. Contains all historical records
4. Can be imported to new system
```

---

## 📊 Example Excel Output

### Sheet 1: Student Info
| Field | Value |
|-------|-------|
| _id | 673123abc456 |
| username | student1 |
| fullName | John Doe |
| email | john@example.com |
| role | student |
| studentId | S2024001 |
| exportedAt | 2025-10-17T10:30:00Z |
| totalCourses | 5 |
| totalAssignments | 20 |
| submittedAssignments | 18 |
| averageAssignmentGrade | 85.5 |
| totalQuizzes | 10 |
| completedQuizzes | 9 |
| averageQuizScore | 78.3 |
| totalAnnouncements | 25 |
| unreadNotifications | 3 |
| totalGroups | 2 |

### Sheet 2: Enrolled Courses
| _id | code | name | instructor | semester |
|-----|------|------|-----------|----------|
| 671... | CPM502 | Mobile Dev | Prof. Smith | Fall 2024 |
| 672... | CS101 | Intro CS | Prof. Jones | Fall 2024 |

### Sheet 3: Submissions
| assignmentId | title | courseId | submittedAt | grade | feedback |
|--------------|-------|----------|-------------|-------|----------|
| 681... | Lab 1 | 671... | 2024-10-15 | 90 | Great work! |
| 682... | Lab 2 | 671... | 2024-10-16 | 85 | Good effort |

### Sheet 4: Quiz Attempts
| quizId | quizTitle | courseId | score | totalPoints | percentage | submissionTime |
|--------|-----------|----------|-------|-------------|------------|----------------|
| 691... | Quiz 1 | 671... | 8 | 10 | 80% | 2024-10-15 |
| 692... | Quiz 2 | 671... | 7 | 10 | 70% | 2024-10-16 |

---

## 🔒 Security

- ✅ **Instructor/Admin Only**: Only instructors and admins can export student data
- ✅ **Authentication Required**: Must have valid JWT token
- ✅ **No Password Exposure**: Student passwords are NEVER included
- ✅ **Audit Trail**: All exports are logged in backend console

---

## 🎯 Quick Reference

### Export URL Pattern:
```
GET /api/export/student/{studentId}/{format}
```

### Supported Formats:
- `excel` - Multi-sheet Excel workbook (recommended)
- `json` - Complete JSON with all data

### Required Header:
```
Authorization: Bearer YOUR_TOKEN
```

### Example Request:
```bash
curl -H "Authorization: Bearer eyJhbGc..." \
  http://localhost:5000/api/export/student/673123abc456/excel \
  --output student_report.xlsx
```

---

## ❓ FAQ

**Q: Can students export their own data?**  
A: Currently no - only instructors/admins can export. But you can add a self-export feature if needed.

**Q: How do I get the student ID?**  
A: Export all users first with `/api/export/users/excel?role=student`, or query your database.

**Q: What if the student has no data?**  
A: Empty sheets will still be created. The export will succeed but show "No data found" in those sheets.

**Q: Can I export multiple students at once?**  
A: Not directly, but you can loop through student IDs in code and export each one.

**Q: How long does it take?**  
A: Usually 1-3 seconds per student, depending on how much data they have.

**Q: Where do the files go?**  
A: Downloads to your Downloads folder (Postman) or `backend/exported_data/` folder (server).

---

## 🎓 Best Practices

1. **Regular Exports**: Export student data monthly for records
2. **Secure Storage**: Keep exports in secure, encrypted storage
3. **Privacy**: Only share with authorized personnel
4. **Naming**: Use clear filenames like `student_john_doe_oct2024.xlsx`
5. **Archiving**: Keep end-of-semester exports for at least 5 years

---

**Now you can export complete student profiles with all their academic data in one click!** 🎉

