import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        print('✅ Desktop FFI initialized');
      } catch (e) {
        print('❌ FFI init error: $e');
        databaseFactory = databaseFactoryFfi;
      }
    }

    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, 'attendance_manager.db');
    print('📂 Database is located at: $path');

    return await openDatabase(
      path,
      version: 3, // bumped from 1 -> 2 for the duplicate-session fix
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subjects (
        subject_id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_name TEXT NOT NULL UNIQUE
      )
    ''');

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

    await db.execute('''
      CREATE TABLE students (
        student_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        roll_number TEXT NOT NULL UNIQUE,
        course TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '',
        contact TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_sessions (
        session_id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        session_time TEXT NOT NULL,
        topic TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES teachers (teacher_id),
        FOREIGN KEY (subject_id) REFERENCES subjects (subject_id)
      )
    ''');

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

    await db.execute(
      'CREATE INDEX idx_sessions_teacher ON attendance_sessions (teacher_id)',
    );
    await db.execute(
      'CREATE INDEX idx_records_session ON attendance_records (session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_records_student ON attendance_records (student_id)',
    );

    // Prevents more than ONE session per teacher+subject+date, ever.
    await db.execute('''
      CREATE UNIQUE INDEX idx_unique_teacher_subject_date
      ON attendance_sessions (teacher_id, subject_id, session_date)
    ''');

    await db.insert('subjects', {'subject_name': 'Mathematics'});
    await db.insert('subjects', {'subject_name': 'Physics'});
    await db.insert('subjects', {'subject_name': 'Chemistry'});
  }

  // Runs automatically once for anyone upgrading from version 1.
  // Cleans up duplicate sessions already in your database, then locks
  // in the uniqueness rule so it can't happen again.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE students ADD COLUMN course TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE students ADD COLUMN academic_year TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE students ADD COLUMN contact TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE attendance_sessions ADD COLUMN topic TEXT NOT NULL DEFAULT ''");
    }

    if (oldVersion < 2) {
      print('🔧 Running migration: removing duplicate attendance sessions...');

      await db.execute('''
        DELETE FROM attendance_records
        WHERE session_id IN (
          SELECT session_id FROM attendance_sessions
          WHERE session_id NOT IN (
            SELECT MAX(session_id)
            FROM attendance_sessions
            GROUP BY teacher_id, subject_id, session_date
          )
        )
      ''');

      await db.execute('''
        DELETE FROM attendance_sessions
        WHERE session_id NOT IN (
          SELECT MAX(session_id)
          FROM attendance_sessions
          GROUP BY teacher_id, subject_id, session_date
        )
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_teacher_subject_date
        ON attendance_sessions (teacher_id, subject_id, session_date)
      ''');

      print('✅ Migration complete: duplicate sessions removed.');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
