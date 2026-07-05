import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../services/teacher_service.dart';
import '../services/subject_service.dart';
import '../services/excel_export_service.dart';
import 'calendar_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int teacherId;

  const DashboardScreen({super.key, required this.teacherId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TeacherService _teacherService = TeacherService();
  final SubjectService _subjectService = SubjectService();
  final ExcelExportService _excelExportService = ExcelExportService();

  String _teacherName = '';
  String _subjectName = '';
  bool _isLoadingTeacherInfo = true;

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).fetchStudents();
      _loadTeacherInfo();
    });
  }

  Future<void> _loadTeacherInfo() async {
    try {
      final teacher = await _teacherService.getTeacherById(widget.teacherId);
      if (teacher != null) {
        final subject = await _subjectService.getSubjectById(teacher.subjectId);
        if (mounted) {
          setState(() {
            _teacherName = teacher.name;
            _subjectName = subject?.subjectName ?? 'Unknown Subject';
            _isLoadingTeacherInfo = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _teacherName = 'Unknown Teacher';
            _subjectName = 'Unknown Subject';
            _isLoadingTeacherInfo = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading teacher info: $e');
      if (mounted) {
        setState(() => _isLoadingTeacherInfo = false);
      }
    }
  }

  Future<void> _showAddStudentDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController rollController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.teal),
            SizedBox(width: 8),
            Text('Add New Student'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: rollController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter roll number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final roll = rollController.text.trim();

                await Provider.of<AttendanceProvider>(
                  context,
                  listen: false,
                ).addStudentManually(name, roll);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text('Student added!'),
                    ),
                  );
                }
              }
            },
            child: const Text('Add Student'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteStudent(int studentId, String studentName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text(
          'Are you sure you want to remove $studentName from the active list? '
          'Their past attendance records will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await Provider.of<AttendanceProvider>(
          context,
          listen: false,
        ).deleteStudent(studentId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('$studentName removed'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // Asks the teacher if they want to export the Excel file right now.
  // On desktop this saves straight into Downloads; on mobile it opens
  // the native Share sheet (handled inside ExcelExportService).
  Future<void> _promptExcelExport(int sessionId) async {
    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Attendance?'),
        content: const Text(
          'Attendance was saved. Do you want to generate an Excel file now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Export to Excel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldExport == true) {
      try {
        final String savedPath = await _excelExportService.exportAttendance(
          sessionId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('Excel file saved: $savedPath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Excel export failed: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProv = Provider.of<AttendanceProvider>(context);
    final todayDate = _formatDate(DateTime.now());
    final presentCount = attendanceProv.uiChecklist.values
        .where((v) => v)
        .length;
    final totalStudents = attendanceProv.students.length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.teal.shade700,
        title: const Text(
          'Attendance Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarHistoryScreen()),
            ),
          ),
        ],
      ),
      body: attendanceProv.isLoading || _isLoadingTeacherInfo
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Teacher + Subject info card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.teal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teacherName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _subjectName,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Summary Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                todayDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: Colors.grey.shade400,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Total Students',
                                totalStudents.toString(),
                                Icons.people,
                                Colors.blue,
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey.shade300,
                              ),
                              _buildStatItem(
                                'Present',
                                presentCount.toString(),
                                Icons.check_circle,
                                const Color.fromARGB(255, 25, 218, 32),
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey.shade300,
                              ),
                              _buildStatItem(
                                'Absent',
                                (totalStudents - presentCount).toString(),
                                Icons.cancel,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Student list",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddStudentDialog,
                        icon: const Icon(Icons.add_circle, color: Colors.teal),
                        label: const Text(
                          'Add Student',
                          style: TextStyle(color: Colors.teal),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.teal.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Student List
                  Expanded(
                    child: attendanceProv.students.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "No students found",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: attendanceProv.students.length,
                            itemBuilder: (context, index) {
                              final student = attendanceProv.students[index];
                              final isChecked =
                                  attendanceProv.uiChecklist[student.studentId
                                      .toString()] ??
                                  false;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CheckboxListTile(
                                  activeColor: Colors.teal.shade700,
                                  title: Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Roll: ${student.rollNumber}",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  value: isChecked,
                                  onChanged: (bool? val) {
                                    attendanceProv.toggleAttendance(
                                      student.studentId.toString(),
                                    );
                                  },
                                  secondary: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isChecked
                                            ? Colors.green.shade100
                                            : Colors.grey.shade200,
                                        child: Icon(
                                          isChecked
                                              ? Icons.check
                                              : Icons.person_outline,
                                          color: isChecked
                                              ? Colors.green
                                              : Colors.grey.shade600,
                                          size: 20,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete student',
                                        onPressed: () => _confirmDeleteStudent(
                                          student.studentId!,
                                          student.name,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: presentCount == 0
                          ? null
                          : () async {
                              try {
                                final sessionId = await attendanceProv
                                    .saveCurrentSession(
                                      subjectId: '',
                                      teacherId: widget.teacherId.toString(),
                                    );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.green,
                                      content: Text(
                                        'Attendance saved successfully!',
                                      ),
                                    ),
                                  );
                                  await attendanceProv.fetchStudents();

                                  if (context.mounted) {
                                    await _promptExcelExport(sessionId);
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text('Error: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save),
                          const SizedBox(width: 8),
                          const Text(
                            'Submit Attendance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
