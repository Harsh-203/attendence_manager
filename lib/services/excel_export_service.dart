// This file generates a downloadable Excel (.xlsx) file for one attendance session.

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/attendance_repository.dart';

class ExcelExportService {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  // ----------------- MAIN EXPORT METHOD -----------------

  // Takes a sessionId, builds the Excel file, saves it, and returns the file
  // so the UI can immediately open the Share sheet (WhatsApp/Email/Drive/etc.)
  Future<File> exportSessionToExcel(int sessionId) async {
    // Step 1: Get all the data we need using the repository we already built
    final sessionDetails = await _attendanceRepository.getSessionDetails(
      sessionId,
    );

    final String teacherName = sessionDetails['teacherName'];
    final String subjectName = sessionDetails['subjectName'];
    final String date = sessionDetails['date'];
    final String time = sessionDetails['time'];
    final List<Map<String, dynamic>> records = sessionDetails['records'];

    // Step 2: Create a new Excel workbook
    final Excel excel = Excel.createExcel();

    // Excel.createExcel() automatically creates a default sheet called "Sheet1"
    final Sheet sheet = excel['Attendance'];

    // Remove the default empty "Sheet1" so we're only left with our named sheet
    excel.delete('Sheet1');

    // Step 3: Add the header row (column titles)
    sheet.appendRow([
      TextCellValue('Student Name'),
      TextCellValue('Attendance Status'),
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Teacher Name'),
      TextCellValue('Subject'),
    ]);

    // Step 4: Add one row per student
    for (final record in records) {
      sheet.appendRow([
        TextCellValue(record['studentName'] as String),
        TextCellValue(record['status'] as String), // "Present" or "Absent"
        TextCellValue(date),
        TextCellValue(time),
        TextCellValue(teacherName),
        TextCellValue(subjectName),
      ]);
    }

    // Step 5: Save the file to the app's document folder
    final Directory directory = await getApplicationDocumentsDirectory();

    // Build a unique, readable file name, e.g. "Attendance_Maths_2026-07-04.xlsx"
    final String safeSubjectName = subjectName.replaceAll(' ', '_');
    final String fileName = 'Attendance_${safeSubjectName}_$date.xlsx';
    final String filePath = '${directory.path}/$fileName';

    // Step 6: Encode the Excel data into actual file bytes and write to disk
    final List<int>? fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    final File file = File(filePath);
    await file.writeAsBytes(fileBytes);

    return file;
  }

  // ----------------- SHARE / DOWNLOAD -----------------

  // Opens the native Share sheet so the teacher can save/send the file
  // (WhatsApp, Email, Google Drive, Bluetooth, "Save to Files", etc.)
  Future<void> shareExcelFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Attendance Report'),
    );
  }

  // ----------------- CONVENIENCE METHOD -----------------

  // Does both steps in one call - export AND immediately open the share sheet.
  // This is likely the ONE method your UI teammate will call after
  // AttendanceRepository().submitAttendance() succeeds.
  Future<void> exportAndShare(int sessionId) async {
    final file = await exportSessionToExcel(sessionId);
    await shareExcelFile(file);
  }
}
