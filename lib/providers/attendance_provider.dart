import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/attendance_session.dart';
import '../services/student_service.dart';
import '../services/attendance_record_service.dart';
import '../services/attendance_session_service.dart';

class AttendanceProvider extends ChangeNotifier {
  // Instantiate your teammate's services
  final StudentService _studentService = StudentService();
  final AttendanceRecordService _recordService = AttendanceRecordService();
  final AttendanceSessionService _sessionService = AttendanceSessionService();

  List<Student> _students = [];
  List<Student> get students => _students;

  // Track checkbox states on dashboard: { studentId: status }
  Map<String, bool> _uiChecklist = {};
  Map<String, bool> get uiChecklist => _uiChecklist;

  Map<String, List<AttendanceRecord>> _historyLogs = {};
  Map<String, List<AttendanceRecord>> get historyLogs => _historyLogs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Loads the student from the database service
  Future<void> fetchStudents() async {
    _isLoading = true;
    notifyListeners();
    try {
      _students = await _studentService.getAllStudents();
      // initialize checklist to false by defalt
      for (var student in _students) {
        _uiChecklist[student.studentId.toString()] = false;
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Toggles the UI checkbox state
  void toggleAttendance(String studentId) {
    if (_uiChecklist.containsKey(studentId)) {
      _uiChecklist[studentId] = !_uiChecklist[studentId]!;
      notifyListeners();
    }
  }

  // Commits today's interactive checklist into an Attendance Session
  Future<void> saveCurrentSession({
    required String subjectId,
    required String teacherId,
  }) async {
    final now = DateTime.now();
    String todayStr = DateTime.now().toString().split(' ')[0];
    String timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // creates an attendance sessionn
    AttendanceSession newSession = AttendanceSession(
      sessionDate: todayStr,
      sessionTime: timeStr,
      subjectId: int.parse(subjectId),
      teacherId: int.parse(teacherId),
      createdAt: now.toIso8601String(),
    );
    int generatedSessionId = await _sessionService.createSession(newSession);
    // maps checklist states using ID
    List<AttendanceRecord> recordsToSave = _uiChecklist.entries.map((entry) {
      return AttendanceRecord(
        sessionId: generatedSessionId,
        studentId: int.parse(entry.key),
        status: entry.value
            ? AttendanceStatus.present
            : AttendanceStatus.absent,
      );
    }).toList();

    // Pushes batch records to the database 
    await _recordService.saveAttendanceRecords(recordsToSave);
    await loadHistory(); // Refresh history logs
  }

  // Reads session logs grouped by date
  Future<void> loadHistory() async {
    try {
      Map<String, List<AttendanceRecord>> tempMap = {};
      List<AttendanceSession> sessions = await _sessionService
          .getSessionsByTeacher(1);

      for (var session in sessions) {
        String dateKey = session.sessionDate;
        List<AttendanceRecord> records = await _recordService
            .getRecordsBySession(session.sessionId!);
        // Fetch session info to group by date string
        
        if (!tempMap.containsKey(dateKey)) {
          tempMap[dateKey] = [];
        }
        tempMap[dateKey]!.addAll(records);
      }
      _historyLogs = tempMap;
      notifyListeners();
    } catch (e) {
      debugPrint("Error structuralizing log history: $e");
    }
  }
}
