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
      version: 7, 
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
          time TEXT,
          room TEXT,
          capacity TEXT,
          class_type TEXT,
          status TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE subjects_classes ADD COLUMN time TEXT');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS scores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT,
          student_name TEXT,
          subject_code TEXT,
          subject_name TEXT,
          section_name TEXT,
          grade_level TEXT,
          category TEXT,
          item_label TEXT,
          grading_period TEXT,
          score REAL,
          total_score REAL,
          teacher_name TEXT,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS assessment_setups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_code TEXT,
          subject_name TEXT,
          section_name TEXT,
          grade_level TEXT,
          grading_period TEXT,
          teacher_name TEXT,
          quizzes INTEGER DEFAULT 3,
          assignments INTEGER DEFAULT 2,
          activities INTEGER DEFAULT 3,
          projects INTEGER DEFAULT 1,
          exams INTEGER DEFAULT 1,
          quiz_weight INTEGER DEFAULT 20,
          assignment_weight INTEGER DEFAULT 15,
          activity_weight INTEGER DEFAULT 20,
          project_weight INTEGER DEFAULT 15,
          exam_weight INTEGER DEFAULT 30,
          created_at TEXT,
          UNIQUE(subject_code, section_name, grade_level, grading_period)
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
        time TEXT,
        room TEXT,
        capacity TEXT,
        class_type TEXT,
        status TEXT
      )
    ''');

    // Create scores table
    await db.execute('''
      CREATE TABLE scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        student_name TEXT,
        subject_code TEXT,
        subject_name TEXT,
        section_name TEXT,
        grade_level TEXT,
        category TEXT,
        item_label TEXT,
        grading_period TEXT,
        score REAL,
        total_score REAL,
        teacher_name TEXT,
        created_at TEXT
      )
    ''');

    // Create assessment_setups table
    await db.execute('''
      CREATE TABLE assessment_setups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_code TEXT,
        subject_name TEXT,
        section_name TEXT,
        grade_level TEXT,
        grading_period TEXT,
        teacher_name TEXT,
        quizzes INTEGER DEFAULT 3,
        assignments INTEGER DEFAULT 2,
        activities INTEGER DEFAULT 3,
        projects INTEGER DEFAULT 1,
        exams INTEGER DEFAULT 1,
        quiz_weight INTEGER DEFAULT 20,
        assignment_weight INTEGER DEFAULT 15,
        activity_weight INTEGER DEFAULT 20,
        project_weight INTEGER DEFAULT 15,
        exam_weight INTEGER DEFAULT 30,
        created_at TEXT,
        UNIQUE(subject_code, section_name, grade_level, grading_period)
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

  // Get students by grade level and section
  Future<List<Map<String, dynamic>>> getStudentsBySection(String gradeLevel, String section) async {
    final db = await database;
    return await db.query(
      'students',
      where: 'grade_level = ? AND section = ?',
      whereArgs: [gradeLevel, section],
      orderBy: 'name ASC',
    );
  }

  // Save or update a score
  Future<void> saveScore(Map<String, dynamic> scoreData) async {
    final db = await database;
    // Check if score already exists for this student/subject/category/item/period
    final existing = await db.query(
      'scores',
      where: 'student_id = ? AND subject_code = ? AND category = ? AND item_label = ? AND grading_period = ?',
      whereArgs: [
        scoreData['student_id'],
        scoreData['subject_code'],
        scoreData['category'],
        scoreData['item_label'],
        scoreData['grading_period'],
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'scores',
        scoreData,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('scores', scoreData);
    }
  }

  // Get scores for a specific class/subject/category/item/period
  Future<List<Map<String, dynamic>>> getScores({
    required String subjectCode,
    required String category,
    required String itemLabel,
    required String gradingPeriod,
  }) async {
    final db = await database;
    return await db.query(
      'scores',
      where: 'subject_code = ? AND category = ? AND item_label = ? AND grading_period = ?',
      whereArgs: [subjectCode, category, itemLabel, gradingPeriod],
      orderBy: 'student_name ASC',
    );
  }

  // Save (upsert) assessment setup for a class/period
  Future<void> saveAssessmentSetup(Map<String, dynamic> data) async {
    final db = await database;
    // Delete existing first (upsert via delete+insert to avoid UNIQUE conflicts)
    await db.delete(
      'assessment_setups',
      where: 'subject_code = ? AND section_name = ? AND grade_level = ? AND grading_period = ?',
      whereArgs: [data['subject_code'], data['section_name'], data['grade_level'], data['grading_period']],
    );
    await db.insert('assessment_setups', data);
  }

  // Get assessment setup for a specific class and period
  Future<Map<String, dynamic>?> getAssessmentSetup({
    required String subjectCode,
    required String sectionName,
    required String gradeLevel,
    required String gradingPeriod,
  }) async {
    final db = await database;
    final results = await db.query(
      'assessment_setups',
      where: 'subject_code = ? AND section_name = ? AND grade_level = ? AND grading_period = ?',
      whereArgs: [subjectCode, sectionName, gradeLevel, gradingPeriod],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Add Subject / Class
  Future<void> addSubjectClass(Map<String, dynamic> subjectClassData) async {
    final db = await database;
    await db.insert('subjects_classes', subjectClassData);
  }

  // Update Subject / Class
  Future<void> updateSubjectClass(int id, Map<String, dynamic> subjectClassData) async {
    final db = await database;
    await db.update(
      'subjects_classes',
      subjectClassData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete Subject / Class
  Future<void> deleteSubjectClass(int id) async {
    final db = await database;
    await db.delete(
      'subjects_classes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get all Subjects / Classes
  Future<List<Map<String, dynamic>>> getSubjectClasses() async {
    final db = await database;
    return await db.query('subjects_classes', orderBy: 'id DESC');
  }

  // Get classes assigned to a specific teacher (by name)
  Future<List<Map<String, dynamic>>> getSubjectClassesByTeacher(String teacherName) async {
    final db = await database;
    return await db.query(
      'subjects_classes',
      where: 'assigned_teacher = ?',
      whereArgs: [teacherName],
      orderBy: 'id DESC',
    );
  }

  // Get teacher record by email (used as login username)
  Future<Map<String, dynamic>?> getTeacherByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      'teachers',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
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

  // Update a teacher
  Future<void> updateTeacher(int id, {
    required String teacherId,
    required String name,
    required String department,
    required String email,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {
        'teacher_id': teacherId,
        'name': name,
        'department': department,
        'email': email,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a teacher
  Future<void> deleteTeacher(int id) async {
    final db = await database;
    await db.delete(
      'teachers',
      where: 'id = ?',
      whereArgs: [id],
    );
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
