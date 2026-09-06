import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class PortalService {
  final _helper = DatabaseHelper();
  String date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  DateTime monday(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Future<List<Map<String, dynamic>>> students() async {
    final db = await _helper.database;
    return db.query('students', where: 'is_active = 1', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> addStudent(Map<String, String> values) async {
    final db = await _helper.database;
    // Preserve the legacy database column without asking users for roll numbers.
    // Allocate a private compatibility key atomically; attendance uses student_id.
    await db.transaction((txn) async {
      final rows = await txn.rawQuery('SELECT COALESCE(MAX(student_id), 0) + 1 AS next_id FROM students');
      var next = rows.first['next_id'] as int;
      var key = 'internal-student-$next';
      while ((await txn.query('students', columns: ['student_id'], where: 'roll_number = ?', whereArgs: [key])).isNotEmpty) {
        next++;
        key = 'internal-student-$next';
      }
      await txn.insert('students', {
        'name': values['name'] ?? '',
        'course': values['course'] ?? '',
        'academic_year': values['academic_year'] ?? '',
        'contact': values['contact'] ?? '',
        'roll_number': key,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> editStudent(int id, String contact, String year) async {
    final db = await _helper.database;
    await db.update('students', {'contact': contact, 'academic_year': year}, where: 'student_id = ?', whereArgs: [id]);
  }

  Future<void> removeStudent(int id) async {
    final db = await _helper.database;
    await db.update('students', {'is_active': 0}, where: 'student_id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> teacher(int id) async {
    final db = await _helper.database;
    final rows = await db.rawQuery('SELECT t.*, s.subject_name FROM teachers t JOIN subjects s ON s.subject_id = t.subject_id WHERE t.teacher_id = ?', [id]);
    if (rows.isEmpty) throw Exception('Teacher account not found');
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> sessions(int teacherId, DateTime start, DateTime end) async {
    final db = await _helper.database;
    return db.rawQuery('''SELECT s.*, COUNT(r.record_id) AS total,
      COALESCE(SUM(CASE WHEN r.status = 'Present' THEN 1 ELSE 0 END), 0) AS present
      FROM attendance_sessions s LEFT JOIN attendance_records r ON r.session_id = s.session_id
      WHERE s.teacher_id = ? AND s.session_date BETWEEN ? AND ?
      GROUP BY s.session_id ORDER BY s.session_date DESC''', [teacherId, date(start), date(end)]);
  }

  Future<List<Map<String, dynamic>>> records(int teacherId, DateTime day) async {
    final db = await _helper.database;
    return db.rawQuery('''SELECT r.*, st.name, st.roll_number FROM attendance_records r
      JOIN attendance_sessions s ON s.session_id = r.session_id
      JOIN students st ON st.student_id = r.student_id
      WHERE s.teacher_id = ? AND s.session_date = ? ORDER BY st.name COLLATE NOCASE''', [teacherId, date(day)]);
  }

  Future<List<Map<String, dynamic>>> absences(int teacherId, int studentId) async {
    final db = await _helper.database;
    return db.rawQuery('''SELECT s.session_date, s.topic FROM attendance_records r
      JOIN attendance_sessions s ON s.session_id = r.session_id
      WHERE s.teacher_id = ? AND r.student_id = ? AND r.status = 'Absent'
      ORDER BY s.session_date DESC''', [teacherId, studentId]);
  }

  Future<int> submit(int teacherId, String topic, Map<int, bool> marks, DateTime day) async {
    if (topic.trim().isEmpty) throw Exception('Please enter the topic taught.');
    if (marks.isEmpty) throw Exception('Add students before taking attendance.');
    if (date(day) != date(DateTime.now())) throw Exception('The day changed. Reopen Mark Attendance before submitting.');
    final db = await _helper.database;
    return db.transaction((txn) async {
      final teachers = await txn.query('teachers', where: 'teacher_id = ?', whereArgs: [teacherId]);
      if (teachers.isEmpty) throw Exception('Teacher account not found');
      final subjectId = teachers.first['subject_id'];
      final existing = await txn.query('attendance_sessions', where: 'teacher_id = ? AND subject_id = ? AND session_date = ?', whereArgs: [teacherId, subjectId, date(day)]);
      final now = DateTime.now();
      final values = {'topic': topic.trim(), 'session_time': DateFormat('HH:mm:ss').format(now)};
      late int id;
      if (existing.isEmpty) {
        id = await txn.insert('attendance_sessions', {...values, 'teacher_id': teacherId, 'subject_id': subjectId, 'session_date': date(day), 'created_at': now.toIso8601String()});
      } else {
        id = existing.first['session_id'] as int;
        await txn.update('attendance_sessions', values, where: 'session_id = ?', whereArgs: [id]);
      }
      // Keep historical records for students removed since the first submission.
      for (final entry in marks.entries) {
        await txn.rawInsert('''INSERT INTO attendance_records (session_id, student_id, status)
          VALUES (?, ?, ?) ON CONFLICT(session_id, student_id) DO UPDATE SET status = excluded.status''',
          [id, entry.key, entry.value ? 'Present' : 'Absent']);
      }
      return id;
    });
  }
}
