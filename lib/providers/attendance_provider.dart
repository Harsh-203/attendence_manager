import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/student_service.dart';
import '../services/attendance_session_service.dart';
import '../repositories/attendance_repository.dart';

class AttendanceProvider extends ChangeNotifier {
  final StudentService _studentService = StudentService();
  final AttendanceSessionService _sessionService = AttendanceSessionService();
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  List<Student> _students = [];
  List<Student> get students => _students;

  Map<String, bool> _uiChecklist = {};
  Map<String, bool> get uiChecklist => _uiChecklist;

  final Map<String, List<Map<String, dynamic>>> _historyWithNames = {};
  Map<String, List<Map<String, dynamic>>> get historyWithNames =>
      _historyWithNames;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchStudents() async {
    _isLoading = true;
    notifyListeners();

    try {
      _students = await _studentService.getActiveStudents();
      _uiChecklist = {};
      for (var student in _students) {
        _uiChecklist[student.studentId.toString()] = false;
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
      _students = [];
      _uiChecklist = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStudentManually(String name, String rollNumber) async {
    try {
      final newStudent = Student(
        name: name,
        rollNumber: rollNumber,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _studentService.addStudent(newStudent);
      await fetchStudents();
    } catch (e) {
      debugPrint("Error adding student: $e");
      rethrow;
    }
  }

  Future<void> deleteStudent(int studentId) async {
    try {
      await _studentService.softDeleteStudent(studentId);
      await fetchStudents();
    } catch (e) {
      debugPrint("Error deleting student: $e");
      rethrow;
    }
  }

  void toggleAttendance(String studentId) {
    if (_uiChecklist.containsKey(studentId)) {
      _uiChecklist[studentId] = !_uiChecklist[studentId]!;
      notifyListeners();
    }
  }

  String getStudentName(int studentId) {
    for (var student in _students) {
      if (student.studentId == studentId) {
        return student.name;
      }
    }
    return 'Unknown Student';
  }

  // ----------------- SUBMIT ATTENDANCE -----------------
  // NOW RETURNS the new sessionId, so the UI can immediately trigger
  // Excel export right after a successful submit.
  Future<int> saveCurrentSession({
    required String subjectId,
    required String teacherId,
  }) async {
    try {
      final int parsedTeacherId = int.parse(teacherId);

      final Map<int, bool> attendanceMap = {
        for (var entry in _uiChecklist.entries)
          int.parse(entry.key): entry.value,
      };

      final sessionId = await _attendanceRepository.submitAttendance(
        teacherId: parsedTeacherId,
        attendanceMap: attendanceMap,
      );

      for (var key in _uiChecklist.keys) {
        _uiChecklist[key] = false;
      }

      notifyListeners();
      debugPrint('Attendance saved to database! Session ID: $sessionId');

      return sessionId;
    } catch (e) {
      debugPrint('Error saving attendance: $e');
      rethrow;
    }
  }

  Future<void> loadHistory() async {
    try {
      final sessions = await _sessionService.getAllSessions();
      _historyWithNames.clear();

      for (final session in sessions) {
        final details = await _attendanceRepository.getSessionDetails(
          session.sessionId!,
        );
        final records = details['records'] as List<dynamic>;

        final mappedRecords = records.map((r) {
          return {
            'name': r['studentName'],
            'rollNumber': r['rollNumber'],
            'status': r['status'],
          };
        }).toList();

        _historyWithNames.putIfAbsent(session.sessionDate, () => []);
        _historyWithNames[session.sessionDate]!.addAll(mappedRecords);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }
}
