import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/attendance_repository.dart';

class ExcelExportService {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  // ----------------- BUILD THE EXCEL FILE -----------------
  Future<File> _buildExcelFile(int sessionId) async {
    final sessionDetails = await _attendanceRepository.getSessionDetails(
      sessionId,
    );

    final String teacherName = sessionDetails['teacherName'];
    final String subjectName = sessionDetails['subjectName'];
    final String date = sessionDetails['date'];
    final String time = sessionDetails['time'];
    final List<Map<String, dynamic>> records = sessionDetails['records'];

    final Excel excel = Excel.createExcel();
    final Sheet sheet = excel['Attendance'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Student Name'),
      TextCellValue('Attendance Status'),
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Teacher Name'),
      TextCellValue('Subject'),
    ]);

    for (final record in records) {
      sheet.appendRow([
        TextCellValue(record['studentName'] as String),
        TextCellValue(record['status'] as String),
        TextCellValue(date),
        TextCellValue(time),
        TextCellValue(teacherName),
        TextCellValue(subjectName),
      ]);
    }

    final String safeSubjectName = subjectName.replaceAll(' ', '_');
    final String fileName = 'Attendance_${safeSubjectName}_$date.xlsx';

    final List<int>? fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    final Directory tempDirectory = await getApplicationDocumentsDirectory();
    final String tempPath = '${tempDirectory.path}/$fileName';
    final File tempFile = File(tempPath);
    await tempFile.writeAsBytes(fileBytes);

    return tempFile;
  }

  // Reliably finds the real Downloads folder on Windows.
  // path_provider's getDownloadsDirectory() is known to return an
  // incorrect/garbled path on Windows (a confirmed Flutter bug), so
  // we build the path manually from the Windows user profile instead.
  Directory _getWindowsDownloadsDirectory() {
    final String? userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) {
      throw Exception('Could not determine Windows user profile folder');
    }
    return Directory('$userProfile\\Downloads');
  }

  // ----------------- MAIN EXPORT METHOD -----------------
  Future<String> exportAttendance(int sessionId) async {
    final File builtFile = await _buildExcelFile(sessionId);
    final String fileName = builtFile.path.split(Platform.pathSeparator).last;

    if (Platform.isWindows) {
      final Directory downloadsDirectory = _getWindowsDownloadsDirectory();

      // Make sure the folder actually exists before writing into it
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      final String finalPath = '${downloadsDirectory.path}\\$fileName';
      final File finalFile = await builtFile.copy(finalPath);

      // Open File Explorer with the file highlighted
      await Process.run('explorer.exe', ['/select,', finalFile.path]);

      return finalFile.path;
    } else if (Platform.isMacOS || Platform.isLinux) {
      final Directory? downloadsDirectory = await getDownloadsDirectory();
      final Directory targetDirectory =
          downloadsDirectory ?? await getApplicationDocumentsDirectory();

      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      final String finalPath =
          '${targetDirectory.path}${Platform.pathSeparator}$fileName';
      final File finalFile = await builtFile.copy(finalPath);

      if (Platform.isMacOS) {
        await Process.run('open', ['-R', finalFile.path]);
      } else {
        await Process.run('xdg-open', [targetDirectory.path]);
      }

      return finalFile.path;
    } else {
      // ----- MOBILE: use the native Share sheet -----
      await SharePlus.instance.share(
        ShareParams(files: [XFile(builtFile.path)], text: 'Attendance Report'),
      );
      return builtFile.path;
    }
  }

  // Kept for backward compatibility
  Future<File> exportSessionToExcel(int sessionId) async {
    return await _buildExcelFile(sessionId);
  }

  Future<void> shareExcelFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Attendance Report'),
    );
  }

  Future<void> exportAndShare(int sessionId) async {
    await exportAttendance(sessionId);
  }
}
