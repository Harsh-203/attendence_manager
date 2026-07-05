import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/attendance_provider.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AttendanceProvider(),
      child: const AttendanceManagerApp(),
    ),
  );
}

class AttendanceManagerApp extends StatelessWidget {
  const AttendanceManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Manager Engine',
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.teal),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
