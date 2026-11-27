import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mock_teachers.csv validation', () {
    const expectedHeaders = [
      'teacher_id',
      'name',
      'department',
      'email',
      'gender',
      'birthdate',
      'contact_number',
      'address',
      'specialization',
      'employment_status',
      'hiring_date',
      'assigned_section',
    ];

    const validDepartments = [
      'Mathematics Department',
      'Science Department',
      'English Department',
      'Filipino Department',
      'Araling Panlipunan (Social Studies)',
      'MAPEH Department',
      'TLE Department',
      'EsP Department',
      'SHS Core Subjects',
      'SHS Applied/Specialized',
    ];

    const validGenders = ['Male', 'Female', 'Other'];

    const validSpecializations = [
      'Mathematics',
      'Science',
      'English',
      'Filipino',
      'Araling Panlipunan (Social Studies)',
      'MAPEH',
      'TLE / TVL',
      'EsP (Values Education)',
      'ABM (Accountancy, Business, & Management)',
      'STEM (Science, Tech, Eng, & Math)',
      'HUMSS (Humanities & Social Sciences)',
      'GAS (General Academic Strand)',
      'Research / Capstone',
    ];

    const validEmploymentStatuses = ['Full-Time', 'Part-Time', 'Contract'];
    const validSections = ['Section A', 'Section B', 'Section C'];

    test('contains 10 valid teacher records matching AddTeacherScreen fields', () async {
      final file = File('mock_teachers.csv');
      expect(file.existsSync(), isTrue);

      final csvText = await file.readAsString(encoding: utf8);
      final rows = await Stream<String>.value(csvText).transform(csv.decoder).toList();

      expect(rows.length, 11);
      expect(rows.first.map((e) => e.toString()).toList(), expectedHeaders);

      final seenIds = <String>{};
      final seenEmails = <String>{};
      final seenDepartments = <String>{};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i].map((e) => e.toString()).toList();
        expect(row.length, 12, reason: 'Row $i must have 12 columns');

        final teacherId = row[0].trim();
        final name = row[1].trim();
        final department = row[2].trim();
        final email = row[3].trim();
        final gender = row[4].trim();
        final birthdate = row[5].trim();
        final contactNumber = row[6].trim();
        final address = row[7].trim();
        final specialization = row[8].trim();
        final employmentStatus = row[9].trim();
        final hiringDate = row[10].trim();
        final assignedSection = row[11].trim();

        expect(RegExp(r'^TCH-\d{6}$').hasMatch(teacherId), isTrue, reason: 'Invalid teacher_id on row $i');
        expect(seenIds.add(teacherId), isTrue, reason: 'Duplicate teacher_id on row $i');

        expect(name.isNotEmpty, isTrue, reason: 'Empty name on row $i');
        expect(validDepartments.contains(department), isTrue, reason: 'Invalid department on row $i');
        expect(seenDepartments.add(department), isTrue, reason: 'Duplicate department on row $i');

        expect(email, email.toLowerCase(), reason: 'Email must be lowercase on row $i');
        expect(
          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email),
          isTrue,
          reason: 'Invalid email format on row $i',
        );
        expect(email.endsWith('.com') || email.endsWith('.ph'), isTrue, reason: 'Email must end with .com or .ph on row $i');
        expect(seenEmails.add(email), isTrue, reason: 'Duplicate email on row $i');

        expect(validGenders.contains(gender), isTrue, reason: 'Invalid gender on row $i');
        expect(_isValidMonthDayYear(birthdate), isTrue, reason: 'Invalid birthdate on row $i');
        expect(contactNumber.isNotEmpty, isTrue, reason: 'Empty contact_number on row $i');
        expect(address.isNotEmpty, isTrue, reason: 'Empty address on row $i');
        expect(validSpecializations.contains(specialization), isTrue, reason: 'Invalid specialization on row $i');
        expect(validEmploymentStatuses.contains(employmentStatus), isTrue, reason: 'Invalid employment_status on row $i');
        expect(_isValidMonthDayYear(hiringDate), isTrue, reason: 'Invalid hiring_date on row $i');

        if (assignedSection.isNotEmpty) {
          expect(validSections.contains(assignedSection), isTrue, reason: 'Invalid assigned_section on row $i');
        }
      }

      expect(seenDepartments.length, validDepartments.length);
    });
  });
}

bool _isValidMonthDayYear(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return false;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (month == null || day == null || year == null) return false;
  if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) return false;
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}
