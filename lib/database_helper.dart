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
      version: 16, 
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
        assigned_section TEXT
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
        profile_picture TEXT
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
        await txn.insert('users', {
          'username': email,
          'password': 'student123',
          'role': 'student',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // Auto-create user account for parent
      if (parentEmail.isNotEmpty) {
        await txn.insert('users', {
          'username': parentEmail,
          'password': 'parent123',
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

  // Get all students
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;
    return await db.query('students', orderBy: 'id DESC');
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
      await txn.insert('users', {
        'username': email,
        'password': 'teacher123',
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
}
