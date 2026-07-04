import 'package:flutter/material.dart';
import 'models/student.dart';
import 'services/auth_service.dart';
import 'services/subject_service.dart';
import 'services/student_service.dart';
import 'repositories/attendance_repository.dart';
import 'services/excel_export_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Backend Test', home: const BackendTestScreen());
  }
}

class BackendTestScreen extends StatefulWidget {
  const BackendTestScreen({super.key});

  @override
  State<BackendTestScreen> createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends State<BackendTestScreen> {
  // We'll keep adding lines of output here to show on screen
  final List<String> _log = [];

  // Helper to add a line to the screen AND print it to the terminal
  void _addLog(String message) {
    debugPrint(message);
    setState(() {
      _log.add(message);
    });
  }

  Future<void> _runFullBackendTest() async {
    setState(() => _log.clear());

    try {
      _addLog('--- STARTING BACKEND TEST ---');

      // Step 1: Create a subject
      final subjectService = SubjectService();
      final subjectId = await subjectService.addSubject('Mathematics');
      _addLog('✅ Step 1: Subject created with ID $subjectId');

      // Step 2: Register a teacher (password gets hashed automatically)
      final authService = AuthService();
      final teacherId = await authService.registerTeacher(
        teacherCode: 'T101',
        name: 'Mr. Sharma',
        plainPassword: 'password123',
        subjectId: subjectId,
      );
      _addLog('✅ Step 2: Teacher registered with ID $teacherId');

      // Step 3: Test login with correct password
      final loginResult = await authService.login('T101', 'password123');
      if (loginResult != null) {
        _addLog('✅ Step 3: Login successful for ${loginResult.name}');
      } else {
        _addLog('❌ Step 3: Login FAILED - this should not happen');
      }

      // Step 3b: Test login with WRONG password (should fail)
      final wrongLogin = await authService.login('T101', 'wrongpassword');
      if (wrongLogin == null) {
        _addLog('✅ Step 3b: Wrong password correctly rejected');
      } else {
        _addLog('❌ Step 3b: Wrong password was accepted - BUG!');
      }

      // Step 4: Add some students
      final studentService = StudentService();
      final now = DateTime.now().toIso8601String();
      final s1 = await studentService.addStudent(
        Student(name: 'Rahul', rollNumber: 'R001', createdAt: now),
      );
      final s2 = await studentService.addStudent(
        Student(name: 'Amit', rollNumber: 'R002', createdAt: now),
      );
      final s3 = await studentService.addStudent(
        Student(name: 'Priya', rollNumber: 'R003', createdAt: now),
      );
      _addLog('✅ Step 4: Added 3 students (IDs: $s1, $s2, $s3)');

      // Step 5: Get dashboard data (teacher name, subject, student list)
      final attendanceRepository = AttendanceRepository();
      final dashboardData = await attendanceRepository.getDashboardData(
        teacherId,
      );
      _addLog(
        '✅ Step 5: Dashboard loaded -> '
        'Teacher: ${dashboardData['teacherName']}, '
        'Subject: ${dashboardData['subjectName']}, '
        'Students: ${(dashboardData['students'] as List).length}',
      );

      // Step 6: Submit attendance (Rahul & Priya present, Amit absent)
      final sessionId = await attendanceRepository.submitAttendance(
        teacherId: teacherId,
        attendanceMap: {s1: true, s2: false, s3: true},
      );
      _addLog('✅ Step 6: Attendance submitted, session ID $sessionId');

      // Step 7: Fetch back the session details to verify it saved correctly
      final sessionDetails = await attendanceRepository.getSessionDetails(
        sessionId,
      );
      _addLog(
        '✅ Step 7: Session details fetched -> '
        '${sessionDetails['records'].length} records found',
      );
      for (final record in sessionDetails['records']) {
        _addLog('    ${record['studentName']}: ${record['status']}');
      }

      // Step 8: Generate the Excel file (without opening share sheet yet)
      final excelExportService = ExcelExportService();
      final file = await excelExportService.exportSessionToExcel(sessionId);
      _addLog('✅ Step 8: Excel file created at: ${file.path}');

      // Step 9: Soft delete a student and confirm they disappear from active list
      await studentService.softDeleteStudent(s2);
      final activeStudents = await studentService.getActiveStudents();
      _addLog(
        '✅ Step 9: After soft-deleting Amit, active students = '
        '${activeStudents.length} (should be 2)',
      );

      _addLog('--- ALL TESTS COMPLETED ---');
    } catch (e, stackTrace) {
      _addLog('❌ ERROR: $e');
      debugPrint('$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend Test Screen')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _runFullBackendTest,
              child: const Text('Run Full Backend Test'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, index) {
                  return Text(_log[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
