import '../database/database_helper.dart';
import '../models/subject.dart';

class SubjectService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSubject(String subjectName) async {
    final db = await _dbHelper.database;
    final subject = Subject(subjectName: subjectName);
    return await db.insert('subjects', subject.toMap());
  }

  Future<List<Subject>> getAllSubjects() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('subjects');
    return maps.map((map) => Subject.fromMap(map)).toList();
  }

  Future<Subject?> getSubjectById(int subjectId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subjects',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );
    if (maps.isEmpty) return null;
    return Subject.fromMap(maps.first);
  }

  Future<int> updateSubject(Subject subject) async {
    final db = await _dbHelper.database;
    return await db.update(
      'subjects',
      subject.toMap(),
      where: 'subject_id = ?',
      whereArgs: [subject.subjectId],
    );
  }

  Future<int> deleteSubject(int subjectId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'subjects',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );
  }
}
