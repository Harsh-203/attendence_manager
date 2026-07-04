// This file combines multiple services into simple, ready-to-use methods
// for the UI team. They should call THIS file, not the individual services directly,
// whenever they need to do something involving attendance.

import '../models/attendance_session.dart';
import '../models/attendance_record.dart';
import 'package:intl/intl.dart' as intl;
import '../services/attendance_session_service.dart';
import '../services/attendance_record_service.dart';
import '../services/student_service.dart';
import '../services/teacher_service.dart';
import '../services/subject_service.dart';

class AttendanceRepository {
  final AttendanceSessionService _sessionService = AttendanceSessionService();
  final AttendanceRecordService _recordService = AttendanceRecordService();
  final StudentService _studentService = StudentService();
  final TeacherService _teacherService = TeacherService();
  final SubjectService _subjectService = SubjectService();

  // ----------------- DASHBOARD DATA -----------------

  // Everything the Dashboard/Attendance screen needs in ONE call:
  // teacher's name, subject name, and the current active student list.
  // The UI team calls this ONE method instead of 3 separate ones.
  Future<Map<String, dynamic>> getDashboardData(int teacherId) async {
    final teacher = await _teacherService.getTeacherById(teacherId);
    if (teacher == null) {
      throw Exception('Teacher not found for id: $teacherId');
    }

    final subject = await _subjectService.getSubjectById(teacher.subjectId);
    final students = await _studentService.getActiveStudents();

    return {
      'teacherName': teacher.name,
      'subjectName': subject?.subjectName ?? 'Unknown Subject',
      'students': students,
    };
  }

  // ----------------- SUBMIT ATTENDANCE -----------------

  // This is the MAIN method for the "Submit Attendance" button.
  // The UI just needs to pass: which teacher, and a Map of
  // { studentId: true/false } where true = present, false = absent.
  //
  // This method internally:
  // 1. Creates the attendance session
  // 2. Builds one AttendanceRecord per student
  // 3. Saves them all together safely
  // 4. Returns the sessionId (useful for generating the Excel file right after)
  Future<int> submitAttendance({
    required int teacherId,
    required Map<int, bool> attendanceMap, // studentId -> isPresent
  }) async {
    final teacher = await _teacherService.getTeacherById(teacherId);
    if (teacher == null) {
      throw Exception('Teacher not found for id: $teacherId');
    }

    final now = DateTime.now();
    final sessionDate = intl.DateFormat('yyyy-MM-dd').format(now);
    final sessionTime = intl.DateFormat('HH:mm:ss').format(now);

    // Step 1: Create the session
    final session = AttendanceSession(
      teacherId: teacher.teacherId!,
      subjectId: teacher.subjectId,
      sessionDate: sessionDate,
      sessionTime: sessionTime,
      createdAt: now.toIso8601String(),
    );
    final sessionId = await _sessionService.createSession(session);

    // Step 2: Build one record per student based on the checkbox map
    final records = attendanceMap.entries.map((entry) {
      final studentId = entry.key;
      final isPresent = entry.value;
      return AttendanceRecord(
        sessionId: sessionId,
        studentId: studentId,
        status: isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
      );
    }).toList();

    // Step 3: Save all records together (batch insert)
    await _recordService.saveAttendanceRecords(records);

    // Step 4: Return sessionId so the UI can immediately trigger Excel export
    return sessionId;
  }

  // ----------------- VIEW PAST ATTENDANCE -----------------

  // Gets everything needed to display or export one past session:
  // session info + every student's Present/Absent status, with names attached.
  Future<Map<String, dynamic>> getSessionDetails(int sessionId) async {
    final session = await _sessionService.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session not found for id: $sessionId');
    }

    final teacher = await _teacherService.getTeacherById(session.teacherId);
    final subject = await _subjectService.getSubjectById(session.subjectId);
    final records = await _recordService.getRecordsBySession(sessionId);

    // Attach each record to its student's name (records only store studentId)
    final List<Map<String, dynamic>> detailedRecords = [];
    for (final record in records) {
      final student = await _studentService.getStudentById(record.studentId);
      detailedRecords.add({
        'studentName': student?.name ?? 'Unknown Student',
        'rollNumber': student?.rollNumber ?? '-',
        'status': record.status.dbValue,
      });
    }

    return {
      'teacherName': teacher?.name ?? 'Unknown Teacher',
      'subjectName': subject?.subjectName ?? 'Unknown Subject',
      'date': session.sessionDate,
      'time': session.sessionTime,
      'records': detailedRecords,
    };
  }
}
