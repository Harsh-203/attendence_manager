import '../database/database_helper.dart';
import '../models/attendance_record.dart';

class AttendanceRecordService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Used only for a genuinely NEW session (first submission of the day).
  Future<void> saveAttendanceRecords(List<AttendanceRecord> records) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert('attendance_records', record.toMap());
    }

    await batch.commit(noResult: true);
  }

  // THE FIX: wipes old records for a session, then inserts the fresh set,
  // all in one transaction. Only the latest status per student survives.
  Future<void> replaceSessionRecords(
    int sessionId,
    List<AttendanceRecord> records,
  ) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.delete(
        'attendance_records',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      final batch = txn.batch();
      for (final record in records) {
        final map = record.toMap();
        map['record_id'] = null;
        batch.insert('attendance_records', map);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<AttendanceRecord>> getRecordsBySession(int sessionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<List<AttendanceRecord>> getRecordsByStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return maps.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<int> deleteRecordsBySession(int sessionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
