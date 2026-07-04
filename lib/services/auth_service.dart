// This file handles password security and login checking.
// It does NOT store any data itself - it works together with TeacherService.

import 'dart:convert'; // needed to convert text into bytes for hashing
import 'package:crypto/crypto.dart'; // the hashing package we just installed
import 'teacher_service.dart';
import '../models/teacher.dart';

class AuthService {
  final TeacherService _teacherService = TeacherService();

  // ----------------- PASSWORD HASHING -----------------

  // Converts a plain text password into a secure hash
  // Example: "mypassword123" becomes something like
  // "ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94"
  // This is a ONE-WAY conversion - it cannot be reversed back to the original password.
  String hashPassword(String plainPassword) {
    final bytes = utf8.encode(plainPassword); // turn text into bytes
    final digest = sha256.convert(bytes); // apply SHA-256 hashing
    return digest.toString(); // convert result to a readable string
  }

  // ----------------- LOGIN -----------------

  // This is what your UI teammate will call on the Login screen.
  // Takes the teacher_code and plain password the user typed.
  // Returns the Teacher object if login is successful, or null if it failed.
  Future<Teacher?> login(String teacherCode, String plainPassword) async {
    // Step 1: Find the teacher by their code
    final teacher = await _teacherService.getTeacherByCode(teacherCode);

    // Step 2: If no teacher exists with that code, login fails
    if (teacher == null) {
      return null;
    }

    // Step 3: Hash the password the user just typed
    final enteredPasswordHash = hashPassword(plainPassword);

    // Step 4: Compare the freshly-hashed password to the one stored in the database
    if (enteredPasswordHash == teacher.passwordHash) {
      return teacher; // correct password - login successful
    } else {
      return null; // wrong password - login failed
    }
  }

  // ----------------- REGISTER A NEW TEACHER -----------------

  // Helper method to safely create a new teacher account.
  // This makes sure the password gets hashed BEFORE saving - so nobody
  // ever accidentally saves a plain text password by mistake.
  Future<int> registerTeacher({
    required String teacherCode,
    required String name,
    required String plainPassword,
    required int subjectId,
  }) async {
    final hashedPassword = hashPassword(plainPassword);

    final teacher = Teacher(
      teacherCode: teacherCode,
      name: name,
      passwordHash: hashedPassword,
      subjectId: subjectId,
      createdAt: DateTime.now().toIso8601String(),
    );

    return await _teacherService.addTeacher(teacher);
  }
}
