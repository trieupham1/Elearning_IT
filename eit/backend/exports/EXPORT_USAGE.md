# Dashboard Export System - Usage Guide

## 📥 How to Use the Export Feature

### API Endpoints

The export system provides three endpoints for different file formats:

#### 1. **Export as CSV**
```bash
GET /api/export/dashboard/csv
Headers: Authorization: Bearer <token>
```

**Response**: Downloads a CSV file
- Filename: `dashboard_{studentId}_{timestamp}.csv`
- Opens in: Excel, Google Sheets, any text editor
- Best for: Simple data analysis, quick viewing

**Example using curl:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/export/dashboard/csv \
  --output dashboard.csv
```

---

#### 2. **Export as Excel (.xlsx)**
```bash
GET /api/export/dashboard/excel
Headers: Authorization: Bearer <token>
```

**Response**: Downloads an Excel workbook
- Filename: `dashboard_{studentId}_{timestamp}.xlsx`
- Multiple sheets:
  - **Summary**: Overall statistics
  - **Quiz Scores**: Detailed quiz performance
  - **Upcoming Deadlines**: All pending tasks
  - **Recent Activities**: Activity log
- Best for: Professional reports, data analysis

**Example using curl:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/export/dashboard/excel \
  --output dashboard.xlsx
```

---

#### 3. **Export as PDF**
```bash
GET /api/export/dashboard/pdf
Headers: Authorization: Bearer <token>
```

**Response**: Downloads a PDF document
- Filename: `dashboard_{studentId}_{timestamp}.pdf`
- Formatted for printing
- Contains all sections
- Best for: Archiving, sharing, printing

**Example using curl:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/export/dashboard/pdf \
  --output dashboard.pdf
```

---

### Cleanup Endpoint (Admin Only)

```bash
GET /api/export/cleanup?days=7
Headers: Authorization: Bearer <admin_token>
```

**Response**: JSON with cleanup results
```json
{
  "message": "Cleanup completed",
  "deletedFiles": 15,
  "olderThan": "7 days"
}
```

---

## 🔧 Integration Examples

### JavaScript/Fetch API

```javascript
async function exportDashboard(format) {
  const token = localStorage.getItem('token');
  
  try {
    const response = await fetch(`http://localhost:5000/api/export/dashboard/${format}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (response.ok) {
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `dashboard.${format === 'excel' ? 'xlsx' : format}`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } else {
      console.error('Export failed:', response.statusText);
    }
  } catch (error) {
    console.error('Export error:', error);
  }
}

// Usage
exportDashboard('csv');    // Export as CSV
exportDashboard('excel');  // Export as Excel
exportDashboard('pdf');    // Export as PDF
```

### Flutter/Dart

```dart
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> exportDashboard(String format) async {
  final token = await storage.read(key: 'token');
  final url = 'http://localhost:5000/api/export/dashboard/$format';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final extension = format == 'excel' ? 'xlsx' : format;
      final file = File('${dir.path}/dashboard.$extension');
      await file.writeAsBytes(response.bodyBytes);
      
      print('✅ File saved: ${file.path}');
      // Open file or show success message
    } else {
      print('❌ Export failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Export error: $e');
  }
}

// Usage
exportDashboard('csv');
exportDashboard('excel');
exportDashboard('pdf');
```

### React Example

```javascript
import axios from 'axios';

const exportDashboard = async (format) => {
  const token = localStorage.getItem('token');
  
  try {
    const response = await axios.get(
      `http://localhost:5000/api/export/dashboard/${format}`,
      {
        headers: {
          'Authorization': `Bearer ${token}`
        },
        responseType: 'blob'
      }
    );

    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    const extension = format === 'excel' ? 'xlsx' : format;
    link.setAttribute('download', `dashboard.${extension}`);
    document.body.appendChild(link);
    link.click();
    link.remove();
  } catch (error) {
    console.error('Export failed:', error);
  }
};

// Usage in component
<button onClick={() => exportDashboard('csv')}>Export CSV</button>
<button onClick={() => exportDashboard('excel')}>Export Excel</button>
<button onClick={() => exportDashboard('pdf')}>Export PDF</button>
```

---

## 📊 What Data is Exported?

### Included in All Formats:

1. **Student Information**
   - Student ID
   - Name
   - Export timestamp

2. **Overall Summary**
   - Total courses enrolled
   - Overall progress percentage

3. **Assignment Statistics**
   - Total assignments
   - Submitted count
   - Pending count
   - Late submissions
   - Average grade

4. **Quiz Statistics**
   - Total quizzes
   - Completed count
   - Pending count
   - Average score

5. **Recent Quiz Scores** (up to 10)
   - Quiz title
   - Course name
   - Score/Max score
   - Percentage
   - Completion date

6. **Upcoming Deadlines** (up to 20)
   - Type (assignment/quiz)
   - Title
   - Course
   - Deadline date
   - Days remaining

7. **Recent Activities** (up to 20)
   - Activity type
   - Title
   - Course
   - Message
   - Score (if applicable)
   - Timestamp

---

## 🔒 Security

- ✅ **Authentication Required**: All endpoints require valid JWT token
- ✅ **Student-Specific**: Students can only export their own data
- ✅ **Secure Storage**: Files stored in non-public directory
- ✅ **Automatic Cleanup**: Old files auto-deleted after 7 days
- ✅ **No Direct Access**: Files served only through authenticated download

---

## 🎯 Best Practices

### When to Use Each Format:

**CSV:**
- Quick data viewing
- Import into spreadsheets
- Simple analysis
- Lightweight

**Excel:**
- Professional reports
- Multi-sheet analysis
- Data visualization
- Styled presentation

**PDF:**
- Archiving records
- Sharing with others
- Printing
- Read-only distribution

---

## 🚀 Testing

### Test with Postman:

1. Login to get token:
```
POST http://localhost:5000/api/auth/login
Body: { "username": "student1", "password": "password" }
```

2. Copy the token from response

3. Export dashboard:
```
GET http://localhost:5000/api/export/dashboard/csv
Headers: Authorization: Bearer <paste_token_here>
```

4. Click "Send and Download" to save the file

---

## 📁 File Storage

Exported files are stored in:
```
backend/exported_data/
```

**Structure:**
```
exported_data/
├── dashboard_673123abc456_2025-10-17T09-30-00-000Z.csv
├── dashboard_673123abc456_2025-10-17T10-15-30-123Z.xlsx
├── dashboard_673123abc456_2025-10-17T11-00-45-456Z.pdf
└── .gitkeep
```

**Auto-Cleanup:**
- Files older than 7 days are automatically deleted
- Prevents disk space issues
- Can be customized via cleanup endpoint

---

## ❓ Troubleshooting

### Issue: "Export failed: 401 Unauthorized"
**Solution**: Token expired or invalid. Login again to get new token.

### Issue: "Export failed: 500 Server Error"
**Solution**: Check backend logs. Ensure exceljs and pdfkit are installed:
```bash
npm install exceljs pdfkit
```

### Issue: File downloads but is corrupted
**Solution**: Ensure `responseType: 'blob'` is set in the HTTP request.

### Issue: "Cannot find module 'exceljs'"
**Solution**: Install dependencies:
```bash
cd backend
npm install exceljs pdfkit
```

---

## 🔄 Future Enhancements

Planned features:
- [ ] Custom date range filtering
- [ ] Email delivery of reports
- [ ] Scheduled exports
- [ ] Instructor course reports
- [ ] Semester summaries
- [ ] Grade analytics with charts

