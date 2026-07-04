import '../database/database_helper.dart';
import '../models/student.dart';

class StudentService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ----------------- CREATE -----------------
  Future<int> addStudent(Student student) async {
    final db = await _dbHelper.database;
    return await db.insert('students', student.toMap());
  }

  // ----------------- READ -----------------

  // Gets only ACTIVE students - this is what the attendance sheet screen should use
  // (we don't want "deleted" students showing up when taking attendance)
  Future<List<Student>> getActiveStudents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'is_active = ?',
      whereArgs: [1], // 1 means active
      orderBy: 'name ASC', // shows students alphabetically, nicer for teachers
    );
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  // Gets EVERY student, active or not - useful for admin/history screens only
  Future<List<Student>> getAllStudents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  Future<Student?> getStudentById(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  // Search students by name or roll number (for the optional search feature)
  // The % symbols mean "match anything containing this text"
  Future<List<Student>> searchStudents(String keyword) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'is_active = ? AND (name LIKE ? OR roll_number LIKE ?)',
      whereArgs: [1, '%$keyword%', '%$keyword%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  // ----------------- UPDATE -----------------
  Future<int> updateStudent(Student student) async {
    final db = await _dbHelper.database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'student_id = ?',
      whereArgs: [student.studentId],
    );
  }

  // ----------------- DELETE (SOFT DELETE) -----------------
  // This does NOT remove the row. It just sets is_active to 0.
  // This is the ONLY delete method the app should use for students.
  Future<int> softDeleteStudent(int studentId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'students',
      {'is_active': 0}, // only updating this one column
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  // Bonus: undo a soft delete, in case a teacher deletes someone by mistake
  Future<int> reactivateStudent(int studentId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'students',
      {'is_active': 1},
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }
}
