import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'academic_system.db');
    return await openDatabase(
      path, 
      version: 19, 
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
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN parent_email TEXT');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN gender TEXT');
        await db.execute('ALTER TABLE students ADD COLUMN birthdate TEXT');
        await db.execute('ALTER TABLE students ADD COLUMN contact_number TEXT');
        await db.execute('ALTER TABLE students ADD COLUMN parent_name TEXT');
        await db.execute('ALTER TABLE students ADD COLUMN parent_contact TEXT');
        await db.execute('ALTER TABLE students ADD COLUMN address TEXT');
      } catch (e) {
        // Ignore
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE teachers ADD COLUMN gender TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN birthdate TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN contact_number TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN address TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN specialization TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN employment_status TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN hiring_date TEXT');
        await db.execute('ALTER TABLE teachers ADD COLUMN assigned_section TEXT');
      } catch (e) {
        // Ignore
      }
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT,
          student_name TEXT,
          class_name TEXT,
          date TEXT,
          status TEXT
        )
      ''');
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE assessment_setups ADD COLUMN attendance_weight INTEGER DEFAULT 0');
      } catch (e) {
        // Ignore
      }
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS announcements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          content TEXT,
          audience TEXT,
          date_posted TEXT,
          status TEXT,
          is_pinned INTEGER,
          author TEXT
        )
      ''');
    }
    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN profile_picture TEXT');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE teachers ADD COLUMN profile_picture TEXT');
      } catch (e) {
        // Ignore if column already exists
      }
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender_username TEXT,
          receiver_username TEXT,
          student_id TEXT,
          title TEXT,
          message TEXT,
          date TEXT,
          status TEXT
        )
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_remarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT,
          subject_code TEXT,
          grading_period TEXT,
          remark TEXT,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 18) {
      final users = await db.query('users');
      for (var user in users) {
        final pwd = user['password']?.toString() ?? '';
        // SHA-256 hash length is exactly 64 characters
        if (pwd.isNotEmpty && pwd.length != 64) {
          final bytes = utf8.encode(pwd);
          final hashed = sha256.convert(bytes).toString();
          await db.update(
            'users',
            {'password': hashed},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN is_active INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE teachers ADD COLUMN is_active INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE subjects_classes ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (e) {
        // Ignore
      }
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
        email TEXT,
        gender TEXT,
        birthdate TEXT,
        contact_number TEXT,
        address TEXT,
        specialization TEXT,
        employment_status TEXT,
        hiring_date TEXT,
        assigned_section TEXT,
        is_active INTEGER DEFAULT 1
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
        email TEXT,
        parent_email TEXT,
        gender TEXT,
        birthdate TEXT,
        contact_number TEXT,
        parent_name TEXT,
        parent_contact TEXT,
        address TEXT,
        profile_picture TEXT,
        is_active INTEGER DEFAULT 1
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
        status TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Create announcements table
    await db.execute('''
      CREATE TABLE announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        audience TEXT,
        date_posted TEXT,
        status TEXT,
        is_pinned INTEGER,
        author TEXT
      )
    ''');

    // Create notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_username TEXT,
        receiver_username TEXT,
        student_id TEXT,
        title TEXT,
        message TEXT,
        date TEXT,
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
        attendance_weight INTEGER DEFAULT 0,
        created_at TEXT,
        UNIQUE(subject_code, section_name, grade_level, grading_period)
      )
    ''');

    // Create attendance table
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        student_name TEXT,
        class_name TEXT,
        date TEXT,
        status TEXT
      )
    ''');

    // Create student_remarks table
    await db.execute('''
      CREATE TABLE student_remarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        subject_code TEXT,
        grading_period TEXT,
        remark TEXT,
        created_at TEXT
      )
    ''');

    // Insert a default admin account
    await db.insert('users', {
      'username': 'admin',
      'password': _hashPassword('password123'),
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
    required String parentEmail,
    String? gender,
    String? birthdate,
    String? contactNumber,
    String? parentName,
    String? parentContact,
    String? address,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('students', {
        'student_id': studentId,
        'name': name,
        'grade_level': gradeLevel,
        'section': section,
        'email': email,
        'parent_email': parentEmail,
        'gender': gender,
        'birthdate': birthdate,
        'contact_number': contactNumber,
        'parent_name': parentName,
        'parent_contact': parentContact,
        'address': address,
      });
      // Auto-create user account for student
      if (email.isNotEmpty) {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: 'student123',
          );
        } catch (e) {
          // Ignore if already exists or fails
        }
        await txn.insert('users', {
          'username': email,
          'password': _hashPassword('student123'),
          'role': 'student',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // Auto-create user account for parent
      if (parentEmail.isNotEmpty) {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: parentEmail,
            password: 'parent123',
          );
        } catch (e) {
          // Ignore if already exists or fails
        }
        await txn.insert('users', {
          'username': parentEmail,
          'password': _hashPassword('parent123'),
          'role': 'parent',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // Get students by parent email
  Future<List<Map<String, dynamic>>> getStudentsByParentEmail(String parentEmail) async {
    final db = await database;
    return await db.query(
      'students',
      where: 'parent_email = ?',
      whereArgs: [parentEmail],
    );
  }

  // Update a student
  Future<void> updateStudent(
    int id, {
    String? studentId,
    String? name,
    String? gradeLevel,
    String? section,
    String? email,
    String? parentEmail,
    String? gender,
    String? birthdate,
    String? contactNumber,
    String? parentName,
    String? parentContact,
    String? address,
  }) async {
    final db = await database;
    await db.update(
      'students',
      {
        if (studentId != null) 'student_id': studentId,
        if (name != null) 'name': name,
        if (gradeLevel != null) 'grade_level': gradeLevel,
        if (section != null) 'section': section,
        if (email != null) 'email': email,
        if (parentEmail != null) 'parent_email': parentEmail,
        if (gender != null) 'gender': gender,
        if (birthdate != null) 'birthdate': birthdate,
        if (contactNumber != null) 'contact_number': contactNumber,
        if (parentName != null) 'parent_name': parentName,
        if (parentContact != null) 'parent_contact': parentContact,
        if (address != null) 'address': address,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get all active students
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;
    return await db.query('students', where: 'is_active = 1', orderBy: 'id DESC');
  }

  // Get archived students
  Future<List<Map<String, dynamic>>> getArchivedStudents() async {
    final db = await database;
    return await db.query('students', where: 'is_active = 0', orderBy: 'id DESC');
  }

  // Soft delete a student
  Future<void> softDeleteStudent(int id) async {
    final db = await database;
    await db.update('students', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Restore a student
  Future<void> restoreStudent(int id) async {
    final db = await database;
    await db.update('students', {'is_active': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // Get a single student by email
  Future<Map<String, dynamic>?> getStudentByEmail(String email) async {
    final db = await database;
    final result = await db.query('students', where: 'email = ?', whereArgs: [email], limit: 1);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // Update student profile picture path
  Future<void> updateStudentProfilePicture(String email, String imagePath) async {
    final db = await database;
    await db.update(
      'students',
      {'profile_picture': imagePath},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  // Get student schedule based on enrolled grade level and section
  Future<List<Map<String, dynamic>>> getStudentSchedule(String email) async {
    final db = await database;
    final studentQuery = await db.query('students', where: 'email = ?', whereArgs: [email], limit: 1);
    if (studentQuery.isNotEmpty) {
      final s = studentQuery.first;
      return await db.query(
        'subjects_classes',
        where: 'grade_level = ? AND section_name = ?',
        whereArgs: [s['grade_level'], s['section']],
      );
    }
    return [];
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

  // Get all scores for a student by email
  Future<List<Map<String, dynamic>>> getStudentAllScores(String email) async {
    final db = await database;
    final studentQuery = await db.query('students', where: 'email = ?', whereArgs: [email], limit: 1);
    if (studentQuery.isNotEmpty) {
      final s = studentQuery.first;
      return await db.query(
        'scores',
        where: 'student_id = ?',
        whereArgs: [s['student_id']],
      );
    }
    return [];
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


  // Get all scores for a student in a subject/period
  Future<List<Map<String, dynamic>>> getScoresByStudentSubjectPeriod({
    required String studentId,
    required String subjectCode,
    required String gradingPeriod,
  }) async {
    final db = await database;
    return await db.query(
      'scores',
      where: 'student_id = ? AND subject_code = ? AND grading_period = ?',
      whereArgs: [studentId, subjectCode, gradingPeriod],
    );
  }

  // Get all scores for a student by ID
  Future<List<Map<String, dynamic>>> getScoresByStudentId(String studentId) async {
    final db = await database;
    return await db.query(
      'scores',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  // Calculate General Average for a student
  Future<String> getStudentGeneralAverage(String studentId) async {
    final rawScores = await getScoresByStudentId(studentId);
    if (rawScores.isEmpty) return 'N/A';

    Map<String, Map<String, Map<String, double>>> aggregator = {};
    for (var row in rawScores) {
      final subj = row['subject_name']?.toString() ?? '';
      final period = row['grading_period']?.toString() ?? '';
      final score = (row['score'] as num?)?.toDouble() ?? 0.0;
      final total = (row['total_score'] as num?)?.toDouble() ?? 0.0;

      String quarterKey = '';
      if (period.contains('1st')) quarterKey = 'Q1';
      else if (period.contains('2nd')) quarterKey = 'Q2';
      else if (period.contains('3rd')) quarterKey = 'Q3';
      else if (period.contains('4th')) quarterKey = 'Q4';

      if (quarterKey.isEmpty || total == 0) continue;

      aggregator.putIfAbsent(subj, () => {});
      aggregator[subj]!.putIfAbsent(quarterKey, () => {'score': 0.0, 'total': 0.0});
      aggregator[subj]![quarterKey]!['score'] = aggregator[subj]![quarterKey]!['score']! + score;
      aggregator[subj]![quarterKey]!['total'] = aggregator[subj]![quarterKey]!['total']! + total;
    }

    double sumFinals = 0;
    int countFinals = 0;

    for (var subj in aggregator.keys) {
      double sumQ = 0;
      int countQ = 0;
      for (var q in ['Q1', 'Q2', 'Q3', 'Q4']) {
        if (aggregator[subj]!.containsKey(q)) {
          double s = aggregator[subj]![q]!['score']!;
          double t = aggregator[subj]![q]!['total']!;
          sumQ += (s / t) * 100;
          countQ++;
        }
      }
      if (countQ > 0) {
        sumFinals += sumQ / countQ;
        countFinals++;
      }
    }

    if (countFinals == 0) return 'N/A';
    return (sumFinals / countFinals).toStringAsFixed(1);
  }

  // Get all scores for a subject/section/period (for class-wide evaluation)
  Future<List<Map<String, dynamic>>> getScoresForClass({
    required String subjectCode,
    required String sectionName,
    required String gradeLevel,
    required String gradingPeriod,
  }) async {
    final db = await database;
    return await db.query(
      'scores',
      where: 'subject_code = ? AND section_name = ? AND grade_level = ? AND grading_period = ?',
      whereArgs: [subjectCode, sectionName, gradeLevel, gradingPeriod],
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

  // Get all active Subjects / Classes
  Future<List<Map<String, dynamic>>> getSubjectClasses() async {
    final db = await database;
    return await db.query('subjects_classes', where: 'is_active = 1', orderBy: 'id DESC');
  }

  // Get archived Subjects / Classes
  Future<List<Map<String, dynamic>>> getArchivedSubjectClasses() async {
    final db = await database;
    return await db.query('subjects_classes', where: 'is_active = 0', orderBy: 'id DESC');
  }

  // Soft delete Subject / Class
  Future<void> softDeleteSubjectClass(int id) async {
    final db = await database;
    await db.update('subjects_classes', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Restore Subject / Class
  Future<void> restoreSubjectClass(int id) async {
    final db = await database;
    await db.update('subjects_classes', {'is_active': 1}, where: 'id = ?', whereArgs: [id]);
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

  // Generate the next teacher ID automatically
  Future<String> generateNextTeacherId() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'teachers',
      columns: ['teacher_id'],
    );
    int maxIdNum = 0;
    final regex = RegExp(r'^TCH-(\d+)$');
    for (var row in results) {
      final tId = row['teacher_id']?.toString() ?? '';
      final match = regex.firstMatch(tId);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final val = int.tryParse(numStr) ?? 0;
          if (val > maxIdNum) {
            maxIdNum = val;
          }
        }
      }
    }
    final nextIdNum = maxIdNum + 1;
    return 'TCH-${nextIdNum.toString().padLeft(6, '0')}';
  }

  // Add a teacher
  Future<void> addTeacher({
    required String teacherId,
    required String name,
    required String department,
    required String email,
    String? gender,
    String? birthdate,
    String? contactNumber,
    String? address,
    String? specialization,
    String? employmentStatus,
    String? hiringDate,
    String? assignedSection,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('teachers', {
        'teacher_id': teacherId,
        'name': name,
        'department': department,
        'email': email,
        'gender': gender,
        'birthdate': birthdate,
        'contact_number': contactNumber,
        'address': address,
        'specialization': specialization,
        'employment_status': employmentStatus,
        'hiring_date': hiringDate,
        'assigned_section': assignedSection,
      });
      // Automatically create a user account for the teacher
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: 'teacher123',
        );
      } catch (e) {
        // Ignore if already exists
      }
      await txn.insert('users', {
        'username': email,
        'password': _hashPassword('teacher123'),
        'role': 'teacher',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  // Update teacher profile picture path
  Future<void> updateTeacherProfilePicture(String email, String imagePath) async {
    final db = await database;
    await db.update(
      'teachers',
      {'profile_picture': imagePath},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  // Update a teacher
  Future<void> updateTeacher(
    int id, {
    String? teacherId,
    String? name,
    String? department,
    String? email,
    String? gender,
    String? birthdate,
    String? contactNumber,
    String? address,
    String? specialization,
    String? employmentStatus,
    String? hiringDate,
    String? assignedSection,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {
        if (teacherId != null) 'teacher_id': teacherId,
        if (name != null) 'name': name,
        if (department != null) 'department': department,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (birthdate != null) 'birthdate': birthdate,
        if (contactNumber != null) 'contact_number': contactNumber,
        if (address != null) 'address': address,
        if (specialization != null) 'specialization': specialization,
        if (employmentStatus != null) 'employment_status': employmentStatus,
        if (hiringDate != null) 'hiring_date': hiringDate,
        if (assignedSection != null) 'assigned_section': assignedSection,
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

  // Get all active teachers
  Future<List<Map<String, dynamic>>> getTeachers() async {
    final db = await database;
    return await db.query('teachers', where: 'is_active = 1', orderBy: 'id DESC');
  }

  // Get archived teachers
  Future<List<Map<String, dynamic>>> getArchivedTeachers() async {
    final db = await database;
    return await db.query('teachers', where: 'is_active = 0', orderBy: 'id DESC');
  }

  // Soft delete a teacher
  Future<void> softDeleteTeacher(int id) async {
    final db = await database;
    await db.update('teachers', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Restore a teacher
  Future<void> restoreTeacher(int id) async {
    final db = await database;
    await db.update('teachers', {'is_active': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // Old SQLite authentication method (fallback or initial load)
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final hashedPassword = _hashPassword(password);
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashedPassword],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Fetch user role based on username/email (Used after Firebase Auth success)
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Method to update password
  Future<int> updatePassword(String username, String newPassword) async {
    final db = await database;
    final hashedPassword = _hashPassword(newPassword);
    return await db.update(
      'users',
      {'password': hashedPassword},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  // Save or update attendance
  Future<void> saveAttendance(Map<String, dynamic> data) async {
    final db = await database;
    final existing = await db.query(
      'attendance',
      where: 'student_id = ? AND class_name = ? AND date = ?',
      whereArgs: [data['student_id'], data['class_name'], data['date']],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'attendance',
        data,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('attendance', data);
    }
  }

  // Get attendance for a specific class and date
  Future<List<Map<String, dynamic>>> getAttendanceForClassAndDate(String className, String date) async {
    final db = await database;
    return await db.query(
      'attendance',
      where: 'class_name = ? AND date = ?',
      whereArgs: [className, date],
    );
  }

  // Get all attendance for a specific class (used for grade computation)
  Future<List<Map<String, dynamic>>> getAttendanceForClass(String className) async {
    final db = await database;
    return await db.query(
      'attendance',
      where: 'class_name = ?',
      whereArgs: [className],
    );
  }

  // Add Announcement
  Future<void> addAnnouncement(Map<String, dynamic> announcementData) async {
    final db = await database;
    await db.insert('announcements', announcementData);
  }

  // Get student attendance
  Future<List<Map<String, dynamic>>> getStudentAttendance(String email) async {
    final db = await database;
    final studentQuery = await db.query('students', where: 'email = ?', whereArgs: [email], limit: 1);
    if (studentQuery.isNotEmpty) {
      final s = studentQuery.first;
      return await db.query(
        'attendance',
        where: 'student_id = ?',
        whereArgs: [s['student_id']],
        orderBy: 'date DESC',
      );
    }
    return [];
  }

  // Get Announcements
  Future<List<Map<String, dynamic>>> getAnnouncements(String? username, {String? role}) async {
    final db = await database;
    
    if (role == 'student' && username != null) {
      // Find the student's grade and section
      final studentQuery = await db.query('students', where: 'email = ?', whereArgs: [username], limit: 1);
      if (studentQuery.isNotEmpty) {
        final s = studentQuery.first;
        final sectionPattern = '${s["grade_level"]} - ${s["section"]}%';
        return await db.query(
          'announcements',
          where: 'audience = ? OR audience = ? OR audience LIKE ?',
          whereArgs: ['System-wide', 'All Students', sectionPattern],
          orderBy: 'is_pinned DESC, id DESC',
        );
      } else {
        // Fallback if student details not found
        return await db.query(
          'announcements',
          where: 'audience = ? OR audience = ?',
          whereArgs: ['System-wide', 'All Students'],
          orderBy: 'is_pinned DESC, id DESC',
        );
      }
    } else if (username != null) {
      // Teacher: get their own, OR system-wide, OR All Teachers
      return await db.query(
        'announcements',
        where: 'author = ? OR audience = ? OR audience = ?',
        whereArgs: [username, 'System-wide', 'All Teachers'],
        orderBy: 'is_pinned DESC, id DESC',
      );
    } else {
      // Admin: get all
      return await db.query('announcements', orderBy: 'is_pinned DESC, id DESC');
    }
  }

  // Delete Announcement
  Future<void> deleteAnnouncement(int id) async {
    final db = await database;
    await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
  }

  // Update Announcement
  Future<void> updateAnnouncement(int id, Map<String, dynamic> announcementData) async {
    final db = await database;
    await db.update('announcements', announcementData, where: 'id = ?', whereArgs: [id]);
  }

  // --- NOTIFICATIONS --- //
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(String username) async {
    final db = await database;
    return await db.query(
      'notifications',
      where: 'receiver_username = ?',
      whereArgs: [username],
      orderBy: 'id DESC', // Newest first
    );
  }

  Future<List<Map<String, dynamic>>> getNotificationsSentBy(String senderUsername) async {
    final db = await database;
    return await db.query(
      'notifications',
      where: 'sender_username = ?',
      whereArgs: [senderUsername],
      orderBy: 'id DESC',
    );
  }

  Future<void> markNotificationAsRead(int id) async {
    final db = await database;
    await db.update(
      'notifications',
      {'status': 'Read'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Remarks Methods ---
  Future<void> saveStudentRemark(String studentId, String subjectCode, String gradingPeriod, String remark) async {
    final db = await database;
    final existing = await db.query(
      'student_remarks',
      where: 'student_id = ? AND subject_code = ? AND grading_period = ?',
      whereArgs: [studentId, subjectCode, gradingPeriod],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'student_remarks',
        {
          'remark': remark,
          'created_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('student_remarks', {
        'student_id': studentId,
        'subject_code': subjectCode,
        'grading_period': gradingPeriod,
        'remark': remark,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<String?> getStudentRemark(String studentId, String subjectCode, String gradingPeriod) async {
    final db = await database;
    final results = await db.query(
      'student_remarks',
      where: 'student_id = ? AND subject_code = ? AND grading_period = ?',
      whereArgs: [studentId, subjectCode, gradingPeriod],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first['remark']?.toString();
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getStudentAllRemarksByEmail(String email) async {
    final student = await getStudentByEmail(email);
    if (student == null) return [];
    
    final db = await database;
    return await db.query(
      'student_remarks',
      where: 'student_id = ?',
      whereArgs: [student['student_id'].toString()],
    );
  }
}
