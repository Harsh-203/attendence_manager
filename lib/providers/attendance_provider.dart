// attendance_provider.dart - COMPLETE FIXED
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../services/student_service.dart';
import '../services/attendance_record_service.dart';
import '../services/attendance_session_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final StudentService _studentService = StudentService();
  final AttendanceRecordService _recordService = AttendanceRecordService();
  final AttendanceSessionService _sessionService = AttendanceSessionService();

  List<Student> _students = [];
  List<Student> get students => _students;

  Map<String, bool> _uiChecklist = {};
  Map<String, bool> get uiChecklist => _uiChecklist;

  Map<String, List<Map<String, dynamic>>> _historyWithNames = {};
  Map<String, List<Map<String, dynamic>>> get historyWithNames => _historyWithNames;

  Map<String, List<AttendanceRecord>> _historyLogs = {};
  Map<String, List<AttendanceRecord>> get historyLogs => _historyLogs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _submittedAttendance = [];
  List<Map<String, dynamic>> get submittedAttendance => _submittedAttendance;

  Future<void> fetchStudents() async {
    _isLoading = true;
    notifyListeners();

    try {
      _students = await _studentService.getAllStudents();
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

  void addStudentManually(String name, String rollNumber) {
    final int newId = DateTime.now().millisecondsSinceEpoch % 1000000;
    
    final newStudent = Student(
      studentId: newId,
      name: name,
      rollNumber: rollNumber,
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    _students.add(newStudent);
    _uiChecklist[newStudent.studentId.toString()] = false;
    notifyListeners();
  }

  void toggleAttendance(String studentId) {
    if (_uiChecklist.containsKey(studentId)) {
      _uiChecklist[studentId] = !_uiChecklist[studentId]!;
      notifyListeners();
    }
  }

  String getStudentName(int studentId) {
    // try finding name in students list
    for (var student in _students) {
      if (student.studentId == studentId) {
        return student.name;
      }
    }
    return 'Unknown Student';
  }

  Future<void> saveCurrentSession({
    required String subjectId,
    required String teacherId,
  }) async {
    try {
      final now = DateTime.now();
      String todayStr = now.toString().split(' ')[0];
      String timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final int sessionId = DateTime.now().millisecondsSinceEpoch;

      final List<Map<String, dynamic>> recordsWithNames = [];
      
      for (var entry in _uiChecklist.entries) {
        final studentId = int.parse(entry.key);
        // Find the student
        Student? student;
        for (var s in _students) {
          if (s.studentId == studentId) {
            student = s;
            break;
          }
        }
        
        final String studentName = student?.name ?? 'Unknown Student';
        final String rollNumber = student?.rollNumber ?? 'N/A';
        
        recordsWithNames.add({
          'studentId': entry.key,
          'name': studentName,
          'rollNumber': rollNumber,
          'status': entry.value ? 'Present' : 'Absent',
        });
      }

      // Save to memory
      final attendanceData = {
        'sessionId': sessionId,
        'date': todayStr,
        'time': timeStr,
        'subjectId': subjectId,
        'teacherId': teacherId,
        'records': recordsWithNames,
      };

      _submittedAttendance.add(attendanceData);
       // store history
      if (!_historyWithNames.containsKey(todayStr)) {
        _historyWithNames[todayStr] = [];
      }
      _historyWithNames[todayStr]!.addAll(recordsWithNames);
      
      if (!_historyLogs.containsKey(todayStr)) {
        _historyLogs[todayStr] = [];
      }
      for (var entry in _uiChecklist.entries) {
        final record = AttendanceRecord(
          sessionId: sessionId,
          studentId: int.parse(entry.key),
          status: entry.value ? AttendanceStatus.present : AttendanceStatus.absent,
        );
        _historyLogs[todayStr]!.add(record);
      }

      // Reset checklist
      for (var key in _uiChecklist.keys) {
        _uiChecklist[key] = false;
      }

      notifyListeners();
      
      print('Attendance saved! Records: ${recordsWithNames.length}');
      
    } catch (e) {
      print('Error saving attendance: $e');
      rethrow;
    }
  }

  Future<void> loadHistory() async {
    try {
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }
}