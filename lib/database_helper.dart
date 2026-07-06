import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
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
    // Insert student
    await Supabase.instance.client.from('students').insert({
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
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: 'student123',
        );
      } catch (e) {
        print('Supabase SignUp Error (Student): $e');
      }
      try {
        await Supabase.instance.client.from('users').insert({
          'username': email,
          'password': _hashPassword('student123'),
          'role': 'student',
        });
      } catch (e) {
        // Ignore if already exists
      }
    }
    // Auto-create user account for parent
    if (parentEmail.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.signUp(
          email: parentEmail,
          password: 'parent123',
        );
      } catch (e) {
        print('Supabase SignUp Error (Parent): $e');
      }
      try {
        await Supabase.instance.client.from('users').insert({
          'username': parentEmail,
          'password': _hashPassword('parent123'),
          'role': 'parent',
        });
      } catch (e) {
        // Ignore
      }
    }
  }

  // Get students by parent email
  Future<List<Map<String, dynamic>>> getStudentsByParentEmail(String parentEmail) async {
    final results = await Supabase.instance.client.from('students').select().eq('parent_email', parentEmail);
    return List<Map<String, dynamic>>.from(results);
  }

  // Update a student
  Future<void> updateStudent(
    int id, {
    String? oldEmail,
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
    await Supabase.instance.client.from('students').update({
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
    }).eq('id', id);

    if (oldEmail != null && email != null && oldEmail != email) {
      try {
        await Supabase.instance.client.rpc('update_user_email', params: {
          'old_email': oldEmail,
          'new_email': email,
        });
      } catch (e) {
        print('Error updating user email via RPC (Student): $e');
      }
    }
  }

  // Get all active students
  Future<List<Map<String, dynamic>>> getStudents() async {
    final results = await Supabase.instance.client.from('students').select().eq('is_active', 1).order('id', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get archived students
  Future<List<Map<String, dynamic>>> getArchivedStudents() async {
    final results = await Supabase.instance.client.from('students').select().eq('is_active', 0).order('id', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Soft delete a student
  Future<void> softDeleteStudent(int id) async {
    await Supabase.instance.client.from('students').update({'is_active': 0}).eq('id', id);
  }

  // Restore a student
  Future<void> restoreStudent(int id) async {
    await Supabase.instance.client.from('students').update({'is_active': 1}).eq('id', id);
  }

  // Get a single student by email
  Future<Map<String, dynamic>?> getStudentByEmail(String email) async {
    final results = await Supabase.instance.client.from('students').select().eq('email', email).limit(1);
    if (results.isNotEmpty) return results.first as Map<String, dynamic>;
    return null;
  }

  // Update student profile picture path
  Future<void> updateStudentProfilePicture(String email, String imagePath) async {
    await Supabase.instance.client.from('students').update({'profile_picture': imagePath}).eq('email', email);
  }

  // Get student schedule based on enrolled grade level and section
  Future<List<Map<String, dynamic>>> getStudentSchedule(String email) async {
    final s = await getStudentByEmail(email);
    if (s != null) {
      final results = await Supabase.instance.client.from('subjects_classes')
          .select()
          .eq('grade_level', s['grade_level'])
          .eq('section_name', s['section']);
      return List<Map<String, dynamic>>.from(results);
    }
    return [];
  }

  // Get students by grade level and section
  Future<List<Map<String, dynamic>>> getStudentsBySection(String gradeLevel, String section) async {
    final results = await Supabase.instance.client.from('students')
        .select()
        .eq('grade_level', gradeLevel)
        .eq('section', section)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Save or update a score
  Future<void> saveScore(Map<String, dynamic> scoreData) async {
    final existing = await Supabase.instance.client.from('scores')
        .select()
        .eq('student_id', scoreData['student_id'])
        .eq('subject_code', scoreData['subject_code'])
        .eq('category', scoreData['category'])
        .eq('item_label', scoreData['item_label'])
        .eq('grading_period', scoreData['grading_period'])
        .limit(1);

    if (existing.isNotEmpty) {
      await Supabase.instance.client.from('scores').update(scoreData).eq('id', existing.first['id']);
    } else {
      await Supabase.instance.client.from('scores').insert(scoreData);
    }
  }

  // Get all scores for a student by email
  Future<List<Map<String, dynamic>>> getStudentAllScores(String email) async {
    final s = await getStudentByEmail(email);
    if (s != null) {
      final results = await Supabase.instance.client.from('scores').select().eq('student_id', s['student_id']);
      return List<Map<String, dynamic>>.from(results);
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
    final results = await Supabase.instance.client.from('scores')
        .select()
        .eq('subject_code', subjectCode)
        .eq('category', category)
        .eq('item_label', itemLabel)
        .eq('grading_period', gradingPeriod)
        .order('student_name', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get all scores for a student in a subject/period
  Future<List<Map<String, dynamic>>> getScoresByStudentSubjectPeriod({
    required String studentId,
    required String subjectCode,
    required String gradingPeriod,
  }) async {
    final results = await Supabase.instance.client.from('scores')
        .select()
        .eq('student_id', studentId)
        .eq('subject_code', subjectCode)
        .eq('grading_period', gradingPeriod);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get all scores for a student by ID
  Future<List<Map<String, dynamic>>> getScoresByStudentId(String studentId) async {
    final results = await Supabase.instance.client.from('scores').select().eq('student_id', studentId);
    return List<Map<String, dynamic>>.from(results);
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
    final results = await Supabase.instance.client.from('scores')
        .select()
        .eq('subject_code', subjectCode)
        .eq('section_name', sectionName)
        .eq('grade_level', gradeLevel)
        .eq('grading_period', gradingPeriod)
        .order('student_name', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Save (upsert) assessment setup for a class/period
  Future<void> saveAssessmentSetup(Map<String, dynamic> data) async {
    await Supabase.instance.client.from('assessment_setups')
        .delete()
        .eq('subject_code', data['subject_code'])
        .eq('section_name', data['section_name'])
        .eq('grade_level', data['grade_level'])
        .eq('grading_period', data['grading_period']);
    
    await Supabase.instance.client.from('assessment_setups').insert(data);
  }

  // Get assessment setup for a specific class and period
  Future<Map<String, dynamic>?> getAssessmentSetup({
    required String subjectCode,
    required String sectionName,
    required String gradeLevel,
    required String gradingPeriod,
  }) async {
    final results = await Supabase.instance.client.from('assessment_setups')
        .select()
        .eq('subject_code', subjectCode)
        .eq('section_name', sectionName)
        .eq('grade_level', gradeLevel)
        .eq('grading_period', gradingPeriod)
        .limit(1);
    return results.isNotEmpty ? results.first as Map<String, dynamic> : null;
  }

  // Add Subject / Class
  Future<void> addSubjectClass(Map<String, dynamic> subjectClassData) async {
    await Supabase.instance.client.from('subjects_classes').insert(subjectClassData);
  }

  // Update Subject / Class
  Future<void> updateSubjectClass(int id, Map<String, dynamic> subjectClassData) async {
    await Supabase.instance.client.from('subjects_classes').update(subjectClassData).eq('id', id);
  }

  // Delete Subject / Class
  Future<void> deleteSubjectClass(int id) async {
    await Supabase.instance.client.from('subjects_classes').delete().eq('id', id);
  }

  // Get all active Subjects / Classes
  Future<List<Map<String, dynamic>>> getSubjectClasses() async {
    final results = await Supabase.instance.client.from('subjects_classes').select().eq('is_active', 1).order('id', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get archived Subjects / Classes
  Future<List<Map<String, dynamic>>> getArchivedSubjectClasses() async {
    final results = await Supabase.instance.client.from('subjects_classes').select().eq('is_active', 0).order('id', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  // Soft delete Subject / Class
  Future<void> softDeleteSubjectClass(int id) async {
    await Supabase.instance.client.from('subjects_classes').update({'is_active': 0}).eq('id', id);
  }

  // Restore Subject / Class
  Future<void> restoreSubjectClass(int id) async {
    await Supabase.instance.client.from('subjects_classes').update({'is_active': 1}).eq('id', id);
  }

  // Get classes assigned to a specific teacher (by name)
  Future<List<Map<String, dynamic>>> getSubjectClassesByTeacher(String teacherName) async {
    final results = await Supabase.instance.client.from('subjects_classes')
        .select()
        .eq('assigned_teacher', teacherName)
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get teacher record by email (used as login username)
  Future<Map<String, dynamic>?> getTeacherByEmail(String email) async {
    final results = await Supabase.instance.client.from('teachers').select().eq('email', email).limit(1);
    return results.isNotEmpty ? results.first as Map<String, dynamic> : null;
  }

  // Generate the next teacher ID automatically
  Future<String> generateNextTeacherId() async {
    final results = await Supabase.instance.client.from('teachers').select('teacher_id');
    int maxIdNum = 0;
    final regex = RegExp(r'^TCH-(\d+)$');
    for (var row in results) {
      final tId = row['teacher_id']?.toString() ?? '';
      final match = regex.firstMatch(tId);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final val = int.tryParse(numStr) ?? 0;
          if (val > maxIdNum) maxIdNum = val;
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
    await Supabase.instance.client.from('teachers').insert({
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
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: 'teacher123',
      );
    } catch (e) {
      print('Supabase SignUp Error (Teacher): $e');
    }
    try {
      await Supabase.instance.client.from('users').insert({
        'username': email,
        'password': _hashPassword('teacher123'),
        'role': 'teacher',
      });
    } catch (e) {
      // Ignore if exists
    }
  }

  // Update teacher profile picture path
  Future<void> updateTeacherProfilePicture(String email, String imagePath) async {
    await Supabase.instance.client.from('teachers').update({'profile_picture': imagePath}).eq('email', email);
  }

  // Update a teacher
  Future<void> updateTeacher(
    int id, {
    String? oldEmail,
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
    await Supabase.instance.client.from('teachers').update({
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
    }).eq('id', id);

    if (oldEmail != null && email != null && oldEmail != email) {
      try {
        await Supabase.instance.client.rpc('update_user_email', params: {
          'old_email': oldEmail,
          'new_email': email,
        });
      } catch (e) {
        print('Error updating user email via RPC (Teacher): $e');
      }
    }
  }

  // Delete a teacher
  Future<void> deleteTeacher(int id) async {
    await Supabase.instance.client.from('teachers').delete().eq('id', id);
  }

  // Get all active teachers
  Future<List<Map<String, dynamic>>> getTeachers() async {
    final results = await Supabase.instance.client.from('teachers').select().eq('is_active', 1).order('id', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get archived teachers
  Future<List<Map<String, dynamic>>> getArchivedTeachers() async {
    final results = await Supabase.instance.client.from('teachers').select().eq('is_active', 0).order('id', ascending: true);
    return List<Map<String, dynamic>>.from(results);
  }

  // Soft delete a teacher
  Future<void> softDeleteTeacher(int id) async {
    await Supabase.instance.client.from('teachers').update({'is_active': 0}).eq('id', id);
  }

  // Restore a teacher
  Future<void> restoreTeacher(int id) async {
    await Supabase.instance.client.from('teachers').update({'is_active': 1}).eq('id', id);
  }

  // Old SQLite authentication method (fallback or initial load)
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final hashedPassword = _hashPassword(password);
    final results = await Supabase.instance.client.from('users')
        .select()
        .eq('username', username)
        .eq('password', hashedPassword);
    if (results.isNotEmpty) return results.first as Map<String, dynamic>;
    return null;
  }

  // Fetch user role based on username/email (Used after Firebase/Supabase Auth success)
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final results = await Supabase.instance.client.from('users')
        .select()
        .eq('username', username);
    if (results.isNotEmpty) return results.first as Map<String, dynamic>;
    return null;
  }

  // Method to update password
  Future<int> updatePassword(String username, String newPassword) async {
    final hashedPassword = _hashPassword(newPassword);
    await Supabase.instance.client.from('users')
        .update({'password': hashedPassword})
        .eq('username', username);
    return 1;
  }

  // Save or update attendance
  Future<void> saveAttendance(Map<String, dynamic> data) async {
    final existing = await Supabase.instance.client.from('attendance')
        .select()
        .eq('student_id', data['student_id'])
        .eq('class_name', data['class_name'])
        .eq('date', data['date'])
        .limit(1);

    if (existing.isNotEmpty) {
      await Supabase.instance.client.from('attendance').update(data).eq('id', existing.first['id']);
    } else {
      await Supabase.instance.client.from('attendance').insert(data);
    }
  }

  // Get attendance for a specific class and date
  Future<List<Map<String, dynamic>>> getAttendanceForClassAndDate(String className, String date) async {
    final results = await Supabase.instance.client.from('attendance')
        .select()
        .eq('class_name', className)
        .eq('date', date);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get all unique dates where attendance was taken for a class
  Future<List<String>> getAttendanceDatesForClass(String className) async {
    final results = await Supabase.instance.client.from('attendance')
        .select('date')
        .eq('class_name', className);
    return results.map((row) => row['date'].toString()).toSet().toList();
  }

  // Get all attendance for a specific class (used for grade computation)
  Future<List<Map<String, dynamic>>> getAttendanceForClass(String className) async {
    final results = await Supabase.instance.client.from('attendance')
        .select()
        .eq('class_name', className);
    return List<Map<String, dynamic>>.from(results);
  }

  // Get average attendance for a teacher's classes
  Future<String> getAverageAttendanceForTeacher(String teacherName) async {
    final classes = await getSubjectClassesByTeacher(teacherName);
    if (classes.isEmpty) return '0%';

    int totalRecords = 0;
    int presentRecords = 0;

    for (var c in classes) {
      final className = '${c['grade_level']} - ${c['section_name']}';
      final records = await getAttendanceForClass(className);
      totalRecords += records.length;
      presentRecords += records.where((r) => r['status'] == 'Present' || r['status'] == 'Late').length;
    }

    if (totalRecords == 0) return '0%';
    final pct = (presentRecords / totalRecords) * 100;
    return '${pct.toStringAsFixed(1)}%';
  }

  // Get teacher stats (Total Classes, Total Students)
  Future<Map<String, int>> getTeacherStats(String teacherName) async {
    final classes = await getSubjectClassesByTeacher(teacherName);
    int totalClasses = classes.length;
    
    Set<String> uniqueStudents = {};
    for (var c in classes) {
      final gradeLevel = c['grade_level']?.toString() ?? '';
      final section = c['section_name']?.toString() ?? '';
      if (gradeLevel.isNotEmpty && section.isNotEmpty) {
        final students = await getStudentsBySection(gradeLevel, section);
        for (var s in students) {
          final sId = s['student_id']?.toString() ?? '';
          if (sId.isNotEmpty) {
            uniqueStudents.add(sId);
          }
        }
      }
    }
    
    return {
      'totalClasses': totalClasses,
      'totalStudents': uniqueStudents.length,
    };
  }

  // Add Announcement
  Future<void> addAnnouncement(Map<String, dynamic> announcementData) async {
    await Supabase.instance.client.from('announcements').insert(announcementData);
  }

  // Get student attendance
  Future<List<Map<String, dynamic>>> getStudentAttendance(String email) async {
    final s = await getStudentByEmail(email);
    if (s != null) {
      final results = await Supabase.instance.client.from('attendance')
          .select()
          .eq('student_id', s['student_id'])
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(results);
    }
    return [];
  }

  // Get student attendance percentage by student_id
  Future<String> getStudentAttendancePercentage(String studentId) async {
    final results = await Supabase.instance.client.from('attendance')
        .select()
        .eq('student_id', studentId);
    
    if (results.isEmpty) return 'No Data';

    int presentOrLate = 0;
    for (var r in results) {
      if (r['status'] == 'Present' || r['status'] == 'Late') {
        presentOrLate++;
      }
    }
    double pct = (presentOrLate / results.length) * 100;
    return '${pct.toStringAsFixed(1)}%';
  }

  // Get Announcements
  Future<List<Map<String, dynamic>>> getAnnouncements(String? username, {String? role}) async {
    if (role == 'student' && username != null) {
      final s = await getStudentByEmail(username);
      if (s != null) {
        final sectionPattern = '${s["grade_level"]} - ${s["section"]}%';
        final results = await Supabase.instance.client.from('announcements')
            .select()
            .or('audience.eq.System-wide,audience.eq.All Students,audience.like.$sectionPattern')
            .order('is_pinned', ascending: false)
            .order('id', ascending: false);
        return List<Map<String, dynamic>>.from(results);
      } else {
        final results = await Supabase.instance.client.from('announcements')
            .select()
            .or('audience.eq.System-wide,audience.eq.All Students')
            .order('is_pinned', ascending: false)
            .order('id', ascending: false);
        return List<Map<String, dynamic>>.from(results);
      }
    } else if (username != null && role != 'admin') {
      final results = await Supabase.instance.client.from('announcements')
          .select()
          .or('author.eq.$username,audience.eq.System-wide,audience.eq.All Teachers')
          .order('is_pinned', ascending: false)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(results);
    } else {
      final results = await Supabase.instance.client.from('announcements')
          .select()
          .order('is_pinned', ascending: false)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(results);
    }
  }

  // Delete Announcement
  Future<void> deleteAnnouncement(int id) async {
    await Supabase.instance.client.from('announcements').delete().eq('id', id);
  }

  // Update Announcement
  Future<void> updateAnnouncement(int id, Map<String, dynamic> announcementData) async {
    await Supabase.instance.client.from('announcements').update(announcementData).eq('id', id);
  }

  // --- NOTIFICATIONS --- //
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    await Supabase.instance.client.from('notifications').insert(notification);
    return 1;
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(String username) async {
    final results = await Supabase.instance.client.from('notifications')
        .select()
        .eq('receiver_username', username)
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  Future<List<Map<String, dynamic>>> getNotificationsSentBy(String senderUsername) async {
    final results = await Supabase.instance.client.from('notifications')
        .select()
        .eq('sender_username', senderUsername)
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  Future<void> markNotificationAsRead(int id) async {
    await Supabase.instance.client.from('notifications').update({'status': 'Read'}).eq('id', id);
  }

  // --- Remarks Methods ---
  Future<void> saveStudentRemark(String studentId, String subjectCode, String gradingPeriod, String remark) async {
    final existing = await Supabase.instance.client.from('student_remarks')
        .select()
        .eq('student_id', studentId)
        .eq('subject_code', subjectCode)
        .eq('grading_period', gradingPeriod)
        .limit(1);

    if (existing.isNotEmpty) {
      await Supabase.instance.client.from('student_remarks').update({
        'remark': remark,
        'created_at': DateTime.now().toIso8601String(),
      }).eq('id', existing.first['id']);
    } else {
      await Supabase.instance.client.from('student_remarks').insert({
        'student_id': studentId,
        'subject_code': subjectCode,
        'grading_period': gradingPeriod,
        'remark': remark,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<String?> getStudentRemark(String studentId, String subjectCode, String gradingPeriod) async {
    final results = await Supabase.instance.client.from('student_remarks')
        .select()
        .eq('student_id', studentId)
        .eq('subject_code', subjectCode)
        .eq('grading_period', gradingPeriod)
        .limit(1);
    if (results.isNotEmpty) return results.first['remark']?.toString();
    return null;
  }

  Future<List<Map<String, dynamic>>> getStudentAllRemarksByEmail(String email) async {
    final student = await getStudentByEmail(email);
    if (student == null) return [];
    
    final results = await Supabase.instance.client.from('student_remarks')
        .select()
        .eq('student_id', student['student_id'].toString());
    return List<Map<String, dynamic>>.from(results);
  }

  // Update FCM Token for user
  Future<void> updateUserFCMToken(String username, String token) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('username', username);
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
}
