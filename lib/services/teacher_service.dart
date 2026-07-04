import '../database/database_helper.dart';
import '../models/teacher.dart';

class TeacherService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addTeacher(Teacher teacher) async {
    final db = await _dbHelper.database;
    return await db.insert('teachers', teacher.toMap());
  }

  Future<List<Teacher>> getAllTeachers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('teachers');
    return maps.map((map) => Teacher.fromMap(map)).toList();
  }

  Future<Teacher?> getTeacherById(int teacherId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  Future<Teacher?> getTeacherByCode(String teacherCode) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'teacher_code = ?',
      whereArgs: [teacherCode],
    );
    if (maps.isEmpty) return null;
    return Teacher.fromMap(maps.first);
  }

  Future<int> updateTeacher(Teacher teacher) async {
    final db = await _dbHelper.database;
    return await db.update(
      'teachers',
      teacher.toMap(),
      where: 'teacher_id = ?',
      whereArgs: [teacher.teacherId],
    );
  }

  Future<int> deleteTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'teachers',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
  }
}
