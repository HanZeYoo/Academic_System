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
      version: 2, 
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

    // Insert a default admin account
    await db.insert('users', {
      'username': 'admin',
      'password': 'password123', // In a real app, use password hashing!
      'role': 'admin',
    });
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
