const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');

class DatabaseExporter {
  constructor() {
    this.exportDir = path.join(__dirname, '../exported_data');
    this.ensureExportDir();
  }

  ensureExportDir() {
    if (!fs.existsSync(this.exportDir)) {
      fs.mkdirSync(this.exportDir, { recursive: true });
    }
  }

  /**
   * Export MongoDB collection data to JSON
   */
  async exportToJSON(collectionName, data, filters = {}) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `${collectionName}_${timestamp}.json`;
    const filepath = path.join(this.exportDir, filename);

    const exportData = {
      collection: collectionName,
      exportedAt: new Date().toISOString(),
      filters: filters,
      totalRecords: data.length,
      data: data
    };

    fs.writeFileSync(filepath, JSON.stringify(exportData, null, 2), 'utf-8');
    console.log(`✅ JSON exported: ${filename} (${data.length} records)`);
    return { filename, filepath, recordCount: data.length };
  }

  /**
   * Export MongoDB collection data to CSV
   */
  async exportToCSV(collectionName, data, fields = null) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `${collectionName}_${timestamp}.csv`;
    const filepath = path.join(this.exportDir, filename);

    if (data.length === 0) {
      const csvContent = `No data found in ${collectionName}\nExported At,${new Date().toLocaleString()}\n`;
      fs.writeFileSync(filepath, csvContent, 'utf-8');
      console.log(`⚠️ CSV exported: ${filename} (0 records)`);
      return { filename, filepath, recordCount: 0 };
    }

    // Get fields from first record if not specified
    const headers = fields || Object.keys(data[0]);
    
    // Build CSV
    let csvContent = '';
    
    // Header row
    csvContent += headers.map(h => `"${h}"`).join(',') + '\n';
    
    // Data rows
    data.forEach(record => {
      const row = headers.map(field => {
        let value = record[field];
        
        // Handle nested objects
        if (typeof value === 'object' && value !== null) {
          if (value._id) value = value._id;
          else if (Array.isArray(value)) value = value.join('; ');
          else value = JSON.stringify(value);
        }
        
        // Handle dates
        if (value instanceof Date) {
          value = value.toISOString();
        }
        
        // Escape quotes and wrap in quotes
        return `"${String(value || '').replace(/"/g, '""')}"`;
      });
      csvContent += row.join(',') + '\n';
    });

    fs.writeFileSync(filepath, csvContent, 'utf-8');
    console.log(`✅ CSV exported: ${filename} (${data.length} records)`);
    return { filename, filepath, recordCount: data.length };
  }

  /**
   * Export MongoDB collection data to Excel
   */
  async exportToExcel(collectionName, data, fields = null) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `${collectionName}_${timestamp}.xlsx`;
    const filepath = path.join(this.exportDir, filename);

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'E-Learning Platform';
    workbook.created = new Date();

    if (data.length === 0) {
      const sheet = workbook.addWorksheet(collectionName);
      sheet.addRow(['No data found']);
      await workbook.xlsx.writeFile(filepath);
      console.log(`⚠️ Excel exported: ${filename} (0 records)`);
      return { filename, filepath, recordCount: 0 };
    }

    // Get fields from first record if not specified
    const headers = fields || Object.keys(data[0]);

    // Create worksheet
    const sheet = workbook.addWorksheet(collectionName, {
      properties: { tabColor: { argb: 'FF1976D2' } }
    });

    // Define columns
    sheet.columns = headers.map(header => ({
      header: header,
      key: header,
      width: 20
    }));

    // Add rows
    data.forEach(record => {
      const row = {};
      headers.forEach(field => {
        let value = record[field];
        
        // Handle nested objects
        if (typeof value === 'object' && value !== null) {
          if (value._id) value = value._id.toString();
          else if (Array.isArray(value)) value = value.join(', ');
          else value = JSON.stringify(value);
        }
        
        // Handle dates
        if (value instanceof Date) {
          value = value.toISOString();
        }
        
        row[field] = value;
      });
      sheet.addRow(row);
    });

    // Style header row
    sheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    sheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FF1976D2' }
    };

    // Auto-filter
    sheet.autoFilter = {
      from: 'A1',
      to: `${String.fromCharCode(64 + headers.length)}1`
    };

    await workbook.xlsx.writeFile(filepath);
    console.log(`✅ Excel exported: ${filename} (${data.length} records)`);
    return { filename, filepath, recordCount: data.length };
  }

  /**
   * Export multiple collections to a single Excel workbook
   */
  async exportMultipleToExcel(collections) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `database_export_${timestamp}.xlsx`;
    const filepath = path.join(this.exportDir, filename);

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'E-Learning Platform';
    workbook.created = new Date();

    let totalRecords = 0;

    for (const { name, data, fields } of collections) {
      if (data.length === 0) continue;

      const headers = fields || Object.keys(data[0]);
      const sheet = workbook.addWorksheet(name);

      // Define columns
      sheet.columns = headers.map(header => ({
        header: header,
        key: header,
        width: 20
      }));

      // Add rows
      data.forEach(record => {
        const row = {};
        headers.forEach(field => {
          let value = record[field];
          if (typeof value === 'object' && value !== null) {
            if (value._id) value = value._id.toString();
            else if (Array.isArray(value)) value = value.join(', ');
            else value = JSON.stringify(value);
          }
          if (value instanceof Date) value = value.toISOString();
          row[field] = value;
        });
        sheet.addRow(row);
      });

      // Style header
      sheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
      sheet.getRow(1).fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF1976D2' }
      };

      totalRecords += data.length;
      console.log(`  📄 Added sheet: ${name} (${data.length} records)`);
    }

    await workbook.xlsx.writeFile(filepath);
    console.log(`✅ Multi-sheet Excel exported: ${filename} (${totalRecords} total records)`);
    return { filename, filepath, recordCount: totalRecords };
  }

  /**
   * Clean up old exported files (older than 7 days)
   */
  cleanupOldExports(daysOld = 7) {
    const files = fs.readdirSync(this.exportDir);
    const now = Date.now();
    const maxAge = daysOld * 24 * 60 * 60 * 1000;

    let deletedCount = 0;
    files.forEach(file => {
      if (file === '.gitkeep') return;
      const filepath = path.join(this.exportDir, file);
      const stats = fs.statSync(filepath);
      if (now - stats.mtimeMs > maxAge) {
        fs.unlinkSync(filepath);
        deletedCount++;
        console.log(`🗑️  Deleted old export: ${file}`);
      }
    });

    console.log(`✅ Cleanup complete: ${deletedCount} old files deleted`);
    return deletedCount;
  }
}

module.exports = new DatabaseExporter();

