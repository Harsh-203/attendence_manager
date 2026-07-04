import '../database/database_helper.dart';
import '../models/attendance_record.dart';

class AttendanceRecordService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ----------------- CREATE (BATCH) -----------------
  // This is the most important method in this file.
  // When a teacher submits attendance for 40 students, we don't want to
  // insert them one by one (slow, and risky if the app crashes halfway).
  // Instead we use a "batch" - all 40 inserts happen together, as ONE
  // safe operation. If anything fails, NONE of them get saved (no half-saved data).
  Future<void> saveAttendanceRecords(List<AttendanceRecord> records) async {
    final db = await _dbHelper.database;

    // "batch" groups multiple database operations together
    final batch = db.batch();

    for (final record in records) {
      batch.insert('attendance_records', record.toMap());
    }

    // commit() runs everything inside a transaction - all or nothing
    await batch.commit(noResult: true);
  }

  // ----------------- READ -----------------

  // Gets every student's attendance record for one session
  // (used to display/review a past attendance sheet)
  Future<List<AttendanceRecord>> getRecordsBySession(int sessionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // Gets one student's full attendance history (across all sessions)
  // Useful later for an "attendance percentage" feature if you ever add one
  Future<List<AttendanceRecord>> getRecordsByStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  // ----------------- DELETE -----------------
  // Deletes all records tied to a session (used only if we delete the session itself)
  Future<int> deleteRecordsBySession(int sessionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
