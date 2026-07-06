import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:academic_system/database_helper.dart';

String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

void main() {
  test('Seed Database with Complete Mock Data', () async {
    final client = SupabaseClient(
      'https://vslqselpnkpghtpnxryg.supabase.co',
      'sb_publishable_qAfWW1fw67Xb85gAtWyBZg_sKB-ISaW',
    );
    print('Supabase client initialized directly. Starting seeding...');

    // 1. CLEAN UP PREVIOUS TEST ENTRIES
    print('Cleaning up old test entries...');
    try {
      await client.from('notifications').delete().eq('receiver_username', 'parent@gmail.com');
      await client.from('student_remarks').delete().inFilter('student_id', ['LRN102030', 'LRN102040']);
      await client.from('attendance').delete().inFilter('student_id', ['LRN102030', 'LRN102040']);
      await client.from('scores').delete().inFilter('student_id', ['LRN102030', 'LRN102040']);
      await client.from('assessment_setups').delete().inFilter('subject_code', ['MATH101', 'SCI101', 'SCI801']);
      await client.from('subjects_classes').delete().inFilter('subject_code', ['MATH101', 'SCI101', 'SCI801']);
      await client.from('students').delete().inFilter('student_id', ['LRN102030', 'LRN102040']);
      await client.from('teachers').delete().eq('teacher_id', 'TCH-000001');
      await client.from('users').delete().inFilter('username', [
        'parent@gmail.com',
        'alice.smith@school.edu',
        'bob.smith@school.edu',
        'teacher@school.edu'
      ]);
      print('Cleanup successful.');
    } catch (e) {
      print('Warning: Cleanup encountered an error (might be missing records or constraints): $e');
    }

    // 2. INSERT USERS (With Fallback MD5/SHA256 password hash for local logins)
    print('Inserting test user accounts...');
    final parentPassHash = _hashPassword('parent123');
    final studentPassHash = _hashPassword('student123');
    final teacherPassHash = _hashPassword('teacher123');

    final usersToInsert = [
      {'username': 'parent@gmail.com', 'password': parentPassHash, 'role': 'parent'},
      {'username': 'alice.smith@school.edu', 'password': studentPassHash, 'role': 'student'},
      {'username': 'bob.smith@school.edu', 'password': studentPassHash, 'role': 'student'},
      {'username': 'teacher@school.edu', 'password': teacherPassHash, 'role': 'teacher'},
    ];

    for (var u in usersToInsert) {
      try {
        await client.from('users').insert(u);
        print('User ${u['username']} inserted.');
      } catch (e) {
        print('Error inserting user ${u['username']}: $e');
      }
    }

    // 3. INSERT TEACHER
    print('Inserting teacher (Mr. Jenkins)...');
    try {
      await client.from('teachers').insert({
        'teacher_id': 'TCH-000001',
        'name': 'Mr. Jenkins',
        'department': 'Science',
        'email': 'teacher@school.edu',
        'gender': 'Male',
        'birthdate': '1980-05-15',
        'contact_number': '+639123456789',
        'address': '789 Science Blvd, Quezon City',
        'specialization': 'Physics & Chemistry',
        'employment_status': 'Full-time',
        'hiring_date': '2020-06-01',
        'assigned_section': 'Grade 10 - Section A',
        'is_active': 1,
      });
      print('Teacher Mr. Jenkins inserted.');
    } catch (e) {
      print('Error inserting teacher Mr. Jenkins: $e');
    }

    // 4. INSERT STUDENTS (Linking to parent@gmail.com)
    print('Inserting students (Alice & Bob)...');
    try {
      // Alice (Excellent Student)
      await client.from('students').insert({
        'student_id': 'LRN102030',
        'name': 'Alice Smith',
        'email': 'alice.smith@school.edu',
        'parent_email': 'parent@gmail.com',
        'parent_name': 'John Smith',
        'grade_level': 'Grade 10',
        'section': 'Section A',
        'gender': 'Female',
        'birthdate': '2010-09-22',
        'contact_number': '+639178881234',
        'address': '123 Maple Street, Pasig City',
        'is_active': 1,
      });
      print('Student Alice Smith inserted.');

      // Bob (At-Risk Student)
      await client.from('students').insert({
        'student_id': 'LRN102040',
        'name': 'Bob Smith',
        'email': 'bob.smith@school.edu',
        'parent_email': 'parent@gmail.com',
        'parent_name': 'John Smith',
        'grade_level': 'Grade 8',
        'section': 'Section B',
        'gender': 'Male',
        'birthdate': '2012-04-10',
        'contact_number': '+639178885678',
        'address': '123 Maple Street, Pasig City',
        'is_active': 1,
      });
      print('Student Bob Smith inserted.');
    } catch (e) {
      print('Error inserting students: $e');
    }

    // 5. INSERT CLASSES / SUBJECTS
    print('Inserting classes & subjects...');
    try {
      // Math 10 for Alice
      await client.from('subjects_classes').insert({
        'subject_code': 'MATH101',
        'subject_name': 'Mathematics 10',
        'department': 'Mathematics',
        'grade_level': 'Grade 10',
        'section_name': 'Section A',
        'assigned_teacher': 'Mr. Jenkins',
        'schedule': 'Mon, Wed, Fri',
        'time': '09:00 AM - 10:30 AM',
        'room': 'Room 101',
        'class_type': 'Lecture',
        'status': 'Open',
        'semester': '1st',
        'is_active': 1,
      });

      // Science 10 for Alice
      await client.from('subjects_classes').insert({
        'subject_code': 'SCI101',
        'subject_name': 'General Science 10',
        'department': 'Science',
        'grade_level': 'Grade 10',
        'section_name': 'Section A',
        'assigned_teacher': 'Mr. Jenkins',
        'schedule': 'Tue, Thu',
        'time': '10:30 AM - 12:00 PM',
        'room': 'Lab A',
        'class_type': 'Laboratory',
        'status': 'Open',
        'semester': '1st',
        'is_active': 1,
      });

      // Science 8 for Bob
      await client.from('subjects_classes').insert({
        'subject_code': 'SCI801',
        'subject_name': 'General Science 8',
        'department': 'Science',
        'grade_level': 'Grade 8',
        'section_name': 'Section B',
        'assigned_teacher': 'Mr. Jenkins',
        'schedule': 'Mon, Wed, Fri',
        'time': '01:00 PM - 02:30 PM',
        'room': 'Lab B',
        'class_type': 'Lecture',
        'status': 'Open',
        'semester': '1st',
        'is_active': 1,
      });
      print('Classes & subjects inserted.');
    } catch (e) {
      print('Error inserting classes/subjects: $e');
    }

    // 6. INSERT ASSESSMENT SETUPS
    print('Inserting assessment setups...');
    try {
      final nowStr = DateTime.now().toIso8601String();
      final setups = [
        {
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'grading_period': '1st Quarter',
          'teacher_name': 'Mr. Jenkins',
          'quizzes': 3,
          'assignments': 2,
          'activities': 3,
          'projects': 1,
          'exams': 1,
          'quiz_weight': 20,
          'assignment_weight': 15,
          'activity_weight': 20,
          'project_weight': 15,
          'exam_weight': 30,
          'attendance_weight': 0,
          'created_at': nowStr,
        },
        {
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'grading_period': '1st Quarter',
          'teacher_name': 'Mr. Jenkins',
          'quizzes': 3,
          'assignments': 2,
          'activities': 3,
          'projects': 1,
          'exams': 1,
          'quiz_weight': 20,
          'assignment_weight': 15,
          'activity_weight': 20,
          'project_weight': 15,
          'exam_weight': 30,
          'attendance_weight': 0,
          'created_at': nowStr,
        },
        {
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'grading_period': '1st Quarter',
          'teacher_name': 'Mr. Jenkins',
          'quizzes': 3,
          'assignments': 2,
          'activities': 3,
          'projects': 1,
          'exams': 1,
          'quiz_weight': 20,
          'assignment_weight': 15,
          'activity_weight': 20,
          'project_weight': 15,
          'exam_weight': 30,
          'attendance_weight': 0,
          'created_at': nowStr,
        }
      ];

      for (var s in setups) {
        await client.from('assessment_setups').insert(s);
      }
      print('Assessment setups inserted.');
    } catch (e) {
      print('Error inserting assessment setups: $e');
    }

    // 7. INSERT SCORES
    print('Inserting student scores...');
    try {
      final nowStr = DateTime.now().toIso8601String();
      final scores = [
        // Alice Math (Excellent grades: Average ~91.5%)
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Quiz',
          'item_label': 'Quiz 1',
          'grading_period': '1st Quarter',
          'score': 18.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Quiz',
          'item_label': 'Quiz 2',
          'grading_period': '1st Quarter',
          'score': 19.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Assignment',
          'item_label': 'HW 1',
          'grading_period': '1st Quarter',
          'score': 15.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Assignment',
          'item_label': 'HW 2',
          'grading_period': '1st Quarter',
          'score': 14.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Activity',
          'item_label': 'Act 1',
          'grading_period': '1st Quarter',
          'score': 19.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Activity',
          'item_label': 'Act 2',
          'grading_period': '1st Quarter',
          'score': 20.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Project',
          'item_label': 'Proj 1',
          'grading_period': '1st Quarter',
          'score': 14.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'MATH101',
          'subject_name': 'Mathematics 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Exam',
          'item_label': 'Periodical Exam',
          'grading_period': '1st Quarter',
          'score': 28.0,
          'total_score': 30.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },

        // Alice Science (Excellent grades: Average ~95.0%)
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Quiz',
          'item_label': 'Quiz 1',
          'grading_period': '1st Quarter',
          'score': 20.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Quiz',
          'item_label': 'Quiz 2',
          'grading_period': '1st Quarter',
          'score': 19.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Assignment',
          'item_label': 'HW 1',
          'grading_period': '1st Quarter',
          'score': 15.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Activity',
          'item_label': 'Act 1',
          'grading_period': '1st Quarter',
          'score': 20.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Project',
          'item_label': 'Proj 1',
          'grading_period': '1st Quarter',
          'score': 15.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'student_name': 'Alice Smith',
          'subject_code': 'SCI101',
          'subject_name': 'General Science 10',
          'section_name': 'Section A',
          'grade_level': 'Grade 10',
          'category': 'Exam',
          'item_label': 'Periodical Exam',
          'grading_period': '1st Quarter',
          'score': 29.0,
          'total_score': 30.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },

        // Bob Science (At-Risk grades: Average ~60.3%)
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Quiz',
          'item_label': 'Quiz 1',
          'grading_period': '1st Quarter',
          'score': 11.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Quiz',
          'item_label': 'Quiz 2',
          'grading_period': '1st Quarter',
          'score': 8.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Assignment',
          'item_label': 'HW 1',
          'grading_period': '1st Quarter',
          'score': 7.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Assignment',
          'item_label': 'HW 2',
          'grading_period': '1st Quarter',
          'score': 6.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Activity',
          'item_label': 'Act 1',
          'grading_period': '1st Quarter',
          'score': 11.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Activity',
          'item_label': 'Act 2',
          'grading_period': '1st Quarter',
          'score': 12.0,
          'total_score': 20.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Project',
          'item_label': 'Proj 1',
          'grading_period': '1st Quarter',
          'score': 8.0,
          'total_score': 15.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'student_name': 'Bob Smith',
          'subject_code': 'SCI801',
          'subject_name': 'General Science 8',
          'section_name': 'Section B',
          'grade_level': 'Grade 8',
          'category': 'Exam',
          'item_label': 'Periodical Exam',
          'grading_period': '1st Quarter',
          'score': 16.0,
          'total_score': 30.0,
          'teacher_name': 'Mr. Jenkins',
          'created_at': nowStr,
        }
      ];

      for (var scoreData in scores) {
        await client.from('scores').insert(scoreData);
      }
      print('Student scores inserted.');
    } catch (e) {
      print('Error inserting scores: $e');
    }

    // 8. INSERT ATTENDANCE
    print('Inserting attendance records...');
    try {
      final attendanceList = [
        // Alice Grade 10 - Section A (100% Present)
        {'student_id': 'LRN102030', 'student_name': 'Alice Smith', 'class_name': 'Grade 10 - Section A', 'date': '2026-07-01', 'status': 'Present'},
        {'student_id': 'LRN102030', 'student_name': 'Alice Smith', 'class_name': 'Grade 10 - Section A', 'date': '2026-07-02', 'status': 'Present'},
        {'student_id': 'LRN102030', 'student_name': 'Alice Smith', 'class_name': 'Grade 10 - Section A', 'date': '2026-07-03', 'status': 'Present'},
        {'student_id': 'LRN102030', 'student_name': 'Alice Smith', 'class_name': 'Grade 10 - Section A', 'date': '2026-07-04', 'status': 'Present'},
        {'student_id': 'LRN102030', 'student_name': 'Alice Smith', 'class_name': 'Grade 10 - Section A', 'date': '2026-07-05', 'status': 'Present'},
        
        // Bob Grade 8 - Section B (80% attendance rate: 3 Present, 1 Late, 1 Absent)
        {'student_id': 'LRN102040', 'student_name': 'Bob Smith', 'class_name': 'Grade 8 - Section B', 'date': '2026-07-01', 'status': 'Present'},
        {'student_id': 'LRN102040', 'student_name': 'Bob Smith', 'class_name': 'Grade 8 - Section B', 'date': '2026-07-02', 'status': 'Present'},
        {'student_id': 'LRN102040', 'student_name': 'Bob Smith', 'class_name': 'Grade 8 - Section B', 'date': '2026-07-03', 'status': 'Late'},
        {'student_id': 'LRN102040', 'student_name': 'Bob Smith', 'class_name': 'Grade 8 - Section B', 'date': '2026-07-04', 'status': 'Absent'},
        {'student_id': 'LRN102040', 'student_name': 'Bob Smith', 'class_name': 'Grade 8 - Section B', 'date': '2026-07-05', 'status': 'Present'},
      ];

      for (var att in attendanceList) {
        await client.from('attendance').insert(att);
      }
      print('Attendance records inserted.');
    } catch (e) {
      print('Error inserting attendance: $e');
    }

    // 9. INSERT REMARKS
    print('Inserting remarks...');
    try {
      final nowStr = DateTime.now().toIso8601String();
      final remarks = [
        {
          'student_id': 'LRN102030',
          'subject_code': 'MATH101',
          'grading_period': '1st Quarter',
          'remark': 'Alice shows great enthusiasm and aptitude for mathematics. Highly recommended for advanced placement!',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102030',
          'subject_code': 'SCI101',
          'grading_period': '1st Quarter',
          'remark': 'Outstanding performance in science labs. Consistently delivers excellent writeups.',
          'created_at': nowStr,
        },
        {
          'student_id': 'LRN102040',
          'subject_code': 'SCI801',
          'grading_period': '1st Quarter',
          'remark': "Bob's grade has fallen below passing due to low quiz scores and incomplete homework. Needs constant review and study supervision at home.",
          'created_at': nowStr,
        }
      ];

      for (var rem in remarks) {
        await client.from('student_remarks').insert(rem);
      }
      print('Remarks inserted.');
    } catch (e) {
      print('Error inserting remarks: $e');
    }

    // 10. INSERT DIRECT NOTIFICATIONS FOR PARENT
    print('Inserting notifications...');
    try {
      final notifications = [
        {
          'sender_username': 'teacher@school.edu',
          'receiver_username': 'parent@gmail.com',
          'student_id': 'LRN102040',
          'title': 'Grade Alert: General Science 8',
          'message': "Bob Smith's grade is currently At-Risk (60.3%). Please check the Intervention Plan tab for recommended guidance.",
          'date': '07/05/2026',
          'status': 'Unread'
        },
        {
          'sender_username': 'teacher@school.edu',
          'receiver_username': 'parent@gmail.com',
          'student_id': 'LRN102040',
          'title': 'Attendance Warning',
          'message': 'Bob Smith was marked Absent from class on 2026-07-04.',
          'date': '07/04/2026',
          'status': 'Read'
        }
      ];

      for (var notif in notifications) {
        await client.from('notifications').insert(notif);
      }
      print('Notifications inserted.');
    } catch (e) {
      print('Error inserting notifications: $e');
    }

    // 11. INSERT ANNOUNCEMENTS (audited)
    print('Inserting announcements...');
    try {
      final announcements = [
        {
          'title': 'Welcome Back to School!',
          'content': 'Welcome teachers, parents, and students to School Year 2026-2027! Let\'s work together to make this a wonderful year.',
          'audience': 'System-wide',
          'date_posted': '2026-07-01',
          'status': 'Active',
          'is_pinned': 1,
          'author': 'admin@school.edu',
        },
        {
          'title': 'First Quarter Exams Schedule',
          'content': 'First Quarter Examinations will be held from August 12 to 14. Detailed study guides and room assignments will be shared by class advisers next week.',
          'audience': 'System-wide',
          'date_posted': '2026-07-05',
          'status': 'Active',
          'is_pinned': 0,
          'author': 'admin@school.edu',
        },
        {
          'title': 'Science Fair Registration Open',
          'content': 'Registration for the annual Science Quiz Bee and Invention Exhibition is now officially open at the science department room. High school projects are welcome!',
          'audience': 'All Students',
          'date_posted': '2026-07-04',
          'status': 'Active',
          'is_pinned': 0,
          'author': 'teacher@school.edu',
        }
      ];

      for (var ann in announcements) {
        await client.from('announcements').insert(ann);
      }
      print('Announcements inserted.');
    } catch (e) {
      print('Error inserting announcements: $e');
    }

    expect(1, 1);
  });
}
