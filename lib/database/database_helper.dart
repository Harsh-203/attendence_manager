// This is the MOST IMPORTANT backend file.
// It creates the SQLite database, creates all tables,
// and gives the rest of the app a single shared connection to talk to.

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // SINGLETON SETUP
  // "Singleton" = only ONE instance of this class exists in the whole app.

  // Step 1: Create one private instance of this class (only this file can see it)
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  // Step 2: This is a private constructor (notice the underscore _internal)
  // Nobody outside this file can do "DatabaseHelper()" directly
  DatabaseHelper._internal();

  // Step 3: This factory always returns the SAME instance every time
  // So anywhere in your app, DatabaseHelper() always gives back the same object
  factory DatabaseHelper() => _instance;

  // This will hold our actual database connection once opened
  static Database? _database;

  // GETTING THE DATABASE (opens it if not already open)

  // Anywhere in the app, you call: await DatabaseHelper().database
  // This checks: "Is the DB already open? If yes, reuse it. If no, open it."
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  // This actually creates/opens the database file on the device
  Future<Database> _initDatabase() async {
    // Find the correct folder on the phone/emulator to store the database file
    final String databasesPath = await getDatabasesPath();

    // Full path to our database file, e.g. ".../attendance_manager.db"
    final String path = join(databasesPath, 'attendance_manager.db');

    // Open the database (creates the file automatically if it doesn't exist)
    return await openDatabase(
      path,
      version:
          1, // Database version - increase this later if you change table structure
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  // ENABLE FOREIGN KEYS
  // SQLite has foreign keys OFF by default - we must turn them ON manually

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // CREATE ALL TABLES
  // This runs ONLY ONCE - the very first time the app opens the database

  Future<void> _onCreate(Database db, int version) async {
    // TABLE 1: subjects
    await db.execute('''
      CREATE TABLE subjects (
        subject_id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_name TEXT NOT NULL UNIQUE
      )
    ''');

    // TABLE 2: teachers
    await db.execute('''
      CREATE TABLE teachers (
        teacher_id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (subject_id)
      )
    ''');

    // TABLE 3: students
    await db.execute('''
      CREATE TABLE students (
        student_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        roll_number TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // TABLE 4: attendance_sessions
    await db.execute('''
      CREATE TABLE attendance_sessions (
        session_id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        session_time TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES teachers (teacher_id),
        FOREIGN KEY (subject_id) REFERENCES subjects (subject_id)
      )
    ''');

    // TABLE 5: attendance_records
    await db.execute('''
      CREATE TABLE attendance_records (
        record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('Present', 'Absent')),
        FOREIGN KEY (session_id) REFERENCES attendance_sessions (session_id),
        FOREIGN KEY (student_id) REFERENCES students (student_id),
        UNIQUE (session_id, student_id)
      )
    ''');

    // Helpful indexes - these make searching/filtering faster as data grows
    await db.execute(
      'CREATE INDEX idx_sessions_teacher ON attendance_sessions (teacher_id)',
    );
    await db.execute(
      'CREATE INDEX idx_records_session ON attendance_records (session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_records_student ON attendance_records (student_id)',
    );
  }

  // CLOSE DATABASE (rarely needed, but good practice to have)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
