import '../database/database_helper.dart';
import '../models/attendance_session.dart';

class AttendanceSessionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ----------------- CREATE -----------------
  // Creates a new session and returns its auto-generated session_id
  // We need this returned ID immediately, because attendance records
  // need to know WHICH session they belong to.
  Future<int> createSession(AttendanceSession session) async {
    final db = await _dbHelper.database;
    return await db.insert('attendance_sessions', session.toMap());
  }

  // ----------------- READ -----------------

  // Gets all sessions taken by one teacher (most recent first)
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

  // Gets one session by its ID
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

  // Checks if a teacher already took attendance on a specific date
  // Useful to warn "You already submitted attendance today" on the UI side
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

  // ----------------- DELETE -----------------
  // Deletes a session (rare - only if a teacher submitted by mistake)
  Future<int> deleteSession(int sessionId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'attendance_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
