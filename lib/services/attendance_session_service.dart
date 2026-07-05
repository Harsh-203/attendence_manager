import '../database/database_helper.dart';
import '../models/attendance_session.dart';

class AttendanceSessionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> createSession(AttendanceSession session) async {
    final db = await _dbHelper.database;
    return await db.insert('attendance_sessions', session.toMap());
  }

  Future<List<AttendanceSession>> getSessionsByTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_sessions',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'session_date DESC, session_time DESC',
    );
    return maps.map((map) => AttendanceSession.fromMap(map)).toList();
  }

  Future<List<AttendanceSession>> getAllSessions() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_sessions',
      orderBy: 'session_date DESC, session_time DESC',
    );
    return maps.map((map) => AttendanceSession.fromMap(map)).toList();
  }

  Future<AttendanceSession?> getSessionById(int sessionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (maps.isEmpty) return null;
    return AttendanceSession.fromMap(maps.first);
  }

  Future<List<AttendanceSession>> getSessionsByTeacherAndDate(
    int teacherId,
    String date,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_sessions',
      where: 'teacher_id = ? AND session_date = ?',
      whereArgs: [teacherId, date],
    );
    return maps.map((map) => AttendanceSession.fromMap(map)).toList();
  }

  // NEW: the key lookup for the fix. Finds the ONE session (if any) for
  // this exact teacher+subject+date combination.
  Future<AttendanceSession?> getSessionByTeacherSubjectDate(
    int teacherId,
    int subjectId,
    String date,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_sessions',
      where: 'teacher_id = ? AND subject_id = ? AND session_date = ?',
      whereArgs: [teacherId, subjectId, date],
    );
    if (maps.isEmpty) return null;
    return AttendanceSession.fromMap(maps.first);
  }

  // NEW: updates an existing session's timestamp when it's reused for a
  // re-submission on the same day.
  Future<int> touchSession(
    int sessionId,
    String sessionTime,
    String createdAt,
  ) async {
    final db = await _dbHelper.database;
    return await db.update(
      'attendance_sessions',
      {'session_time': sessionTime, 'created_at': createdAt},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> deleteSession(int sessionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'attendance_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
