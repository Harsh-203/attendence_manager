import '../database/database_helper.dart';
import '../models/subject.dart';

class SubjectService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ----------------- CREATE -----------------
  Future<int> addSubject(String subjectName) async {
    final db = await _dbHelper.database;
    final subject = Subject(subjectName: subjectName);
    return await db.insert('subjects', subject.toMap());
  }

  // ----------------- READ -----------------
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

  // Finds a subject by its exact name (case-sensitive), or null if none exists
  Future<Subject?> getSubjectByName(String subjectName) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subjects',
      where: 'subject_name = ?',
      whereArgs: [subjectName],
    );
    if (maps.isEmpty) return null;
    return Subject.fromMap(maps.first);
  }

  // Returns the existing subject's ID if the name already exists,
  // otherwise creates a new subject and returns its new ID.
  // This is what the Sign Up screen should use, so two teachers
  // both typing "Mathematics" share the same subject row instead
  // of creating duplicate/near-duplicate subjects.
  Future<int> getOrCreateSubjectId(String subjectName) async {
    final trimmedName = subjectName.trim();
    final existing = await getSubjectByName(trimmedName);
    if (existing != null) {
      return existing.subjectId!;
    }
    return await addSubject(trimmedName);
  }

  // ----------------- UPDATE -----------------
  Future<int> updateSubject(Subject subject) async {
    final db = await _dbHelper.database;
    return await db.update(
      'subjects',
      subject.toMap(),
      where: 'subject_id = ?',
      whereArgs: [subject.subjectId],
    );
  }

  // ----------------- DELETE -----------------
  Future<int> deleteSubject(int subjectId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'subjects',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );
  }
}
