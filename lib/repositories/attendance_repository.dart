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

  // THE FIX: checks for an existing session before creating a new one.
  // If today's session already exists for this teacher+subject, it's
  // reused and its records are REPLACED (old ones deleted, new ones
  // inserted). Otherwise a new session is created as before.
  Future<int> submitAttendance({
    required int teacherId,
    required Map<int, bool> attendanceMap,
  }) async {
    final teacher = await _teacherService.getTeacherById(teacherId);
    if (teacher == null) {
      throw Exception('Teacher not found for id: $teacherId');
    }

    final now = DateTime.now();
    final sessionDate = intl.DateFormat('yyyy-MM-dd').format(now);
    final sessionTime = intl.DateFormat('HH:mm:ss').format(now);

    final existingSession = await _sessionService
        .getSessionByTeacherSubjectDate(
          teacher.teacherId!,
          teacher.subjectId,
          sessionDate,
        );

    int sessionId;
    bool isReSubmission;

    if (existingSession != null) {
      sessionId = existingSession.sessionId!;
      await _sessionService.touchSession(
        sessionId,
        sessionTime,
        now.toIso8601String(),
      );
      isReSubmission = true;
    } else {
      final session = AttendanceSession(
        teacherId: teacher.teacherId!,
        subjectId: teacher.subjectId,
        sessionDate: sessionDate,
        sessionTime: sessionTime,
        createdAt: now.toIso8601String(),
      );
      sessionId = await _sessionService.createSession(session);
      isReSubmission = false;
    }

    final records = attendanceMap.entries.map((entry) {
      final studentId = entry.key;
      final isPresent = entry.value;
      return AttendanceRecord(
        sessionId: sessionId,
        studentId: studentId,
        status: isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
      );
    }).toList();

    if (isReSubmission) {
      await _recordService.replaceSessionRecords(sessionId, records);
    } else {
      await _recordService.saveAttendanceRecords(records);
    }

    return sessionId;
  }

  Future<Map<String, dynamic>> getSessionDetails(int sessionId) async {
    final session = await _sessionService.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session not found for id: $sessionId');
    }

    final teacher = await _teacherService.getTeacherById(session.teacherId);
    final subject = await _subjectService.getSubjectById(session.subjectId);
    final records = await _recordService.getRecordsBySession(sessionId);

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
