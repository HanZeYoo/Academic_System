import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'academic_system.db');
    return await openDatabase(
      path, 
      version: 4, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS teachers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          teacher_id TEXT,
          name TEXT,
          department TEXT,
          email TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT,
          name TEXT,
          grade_level TEXT,
          section TEXT,
          email TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subjects_classes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_code TEXT,
          subject_name TEXT,
          department TEXT,
          grade_level TEXT,
          semester TEXT,
          units TEXT,
          description TEXT,
          section_name TEXT,
          assigned_teacher TEXT,
          schedule TEXT,
          room TEXT,
          capacity TEXT,
          class_type TEXT,
          status TEXT
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        role TEXT
      )
    ''');

    // Create teachers table
    await db.execute('''
      CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id TEXT,
        name TEXT,
        department TEXT,
        email TEXT
      )
    ''');

    // Create students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        name TEXT,
        grade_level TEXT,
        section TEXT,
        email TEXT
      )
    ''');

    // Create subjects_classes table
    await db.execute('''
      CREATE TABLE subjects_classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_code TEXT,
        subject_name TEXT,
        department TEXT,
        grade_level TEXT,
        semester TEXT,
        units TEXT,
        description TEXT,
        section_name TEXT,
        assigned_teacher TEXT,
        schedule TEXT,
        room TEXT,
        capacity TEXT,
        class_type TEXT,
        status TEXT
      )
    ''');

    // Insert a default admin account
    await db.insert('users', {
      'username': 'admin',
      'password': 'password123',
      'role': 'admin',
    });
  }

  // Add a student
  Future<void> addStudent({
    required String studentId,
    required String name,
    required String gradeLevel,
    required String section,
    required String email,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('students', {
        'student_id': studentId,
        'name': name,
        'grade_level': gradeLevel,
        'section': section,
        'email': email,
      });
      // Auto-create user account for student
      if (email.isNotEmpty) {
        await txn.insert('users', {
          'username': email,
          'password': 'student123',
          'role': 'student',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // Get all students
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;
    return await db.query('students', orderBy: 'id DESC');
  }

  // Add Subject / Class
  Future<void> addSubjectClass(Map<String, dynamic> subjectClassData) async {
    final db = await database;
    await db.insert('subjects_classes', subjectClassData);
  }

  // Get all Subjects / Classes
  Future<List<Map<String, dynamic>>> getSubjectClasses() async {
    final db = await database;
    return await db.query('subjects_classes', orderBy: 'id DESC');
  }

  // Add a teacher
  Future<void> addTeacher({
    required String teacherId,
    required String name,
    required String department,
    required String email,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('teachers', {
        'teacher_id': teacherId,
        'name': name,
        'department': department,
        'email': email,
      });
      // Automatically create a user account for the teacher
      await txn.insert('users', {
        'username': email,
        'password': 'teacher123',
        'role': 'teacher',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  // Get all teachers
  Future<List<Map<String, dynamic>>> getTeachers() async {
    final db = await database;
    return await db.query('teachers', orderBy: 'id DESC');
  }

  // Authentication method
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Method to update password
  Future<int> updatePassword(String username, String newPassword) async {
    final db = await database;
    return await db.update(
      'users',
      {'password': newPassword},
      where: 'username = ?',
      whereArgs: [username],
    );
  }
}
