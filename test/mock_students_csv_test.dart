import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mock_students.csv validation', () {
    const expectedHeaders = [
      'student_id',
      'name',
      'grade_level',
      'section',
      'email',
      'parent_email',
      'gender',
      'birthdate',
      'contact_number',
      'parent_name',
      'parent_contact',
      'address',
    ];

    test('contains 10 valid Grade 7 Section A students with NEU ID format', () async {
      final file = File('mock_students.csv');
      expect(file.existsSync(), isTrue);

      final csvText = await file.readAsString(encoding: utf8);
      final rows = await Stream<String>.value(csvText).transform(csv.decoder).toList();

      expect(rows.length, 11);
      expect(rows.first.map((e) => e.toString()).toList(), expectedHeaders);

      final seenIds = <String>{};
      final seenEmails = <String>{};
      final seenParentEmails = <String>{};
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      final neuIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i].map((e) => e.toString()).toList();
        expect(row.length, 12, reason: 'Row $i must have 12 columns');

        final studentId = row[0].trim();
        final name = row[1].trim();
        final gradeLevel = row[2].trim();
        final section = row[3].trim();
        final email = row[4].trim();
        final parentEmail = row[5].trim();
        final gender = row[6].trim();
        final birthdate = row[7].trim();
        final contactNumber = row[8].trim();
        final parentName = row[9].trim();
        final parentContact = row[10].trim();
        final address = row[11].trim();

        expect(neuIdRegex.hasMatch(studentId), isTrue, reason: 'Invalid NEU student_id on row $i');
        expect(seenIds.add(studentId), isTrue, reason: 'Duplicate student_id on row $i');

        expect(name.isNotEmpty, isTrue, reason: 'Empty name on row $i');
        expect(gradeLevel, 'Grade 7', reason: 'Expected Grade 7 on row $i');
        expect(section, 'Section A', reason: 'Expected Section A on row $i');

        expect(email, email.toLowerCase(), reason: 'Email must be lowercase on row $i');
        expect(emailRegex.hasMatch(email), isTrue, reason: 'Invalid email format on row $i');
        expect(email.endsWith('.com') || email.endsWith('.ph'), isTrue, reason: 'Email must end with .com or .ph on row $i');
        expect(seenEmails.add(email), isTrue, reason: 'Duplicate email on row $i');

        expect(parentEmail, parentEmail.toLowerCase(), reason: 'Parent email must be lowercase on row $i');
        expect(emailRegex.hasMatch(parentEmail), isTrue, reason: 'Invalid parent_email format on row $i');
        expect(parentEmail.endsWith('.com') || parentEmail.endsWith('.ph'), isTrue, reason: 'Parent email must end with .com or .ph on row $i');
        expect(seenParentEmails.add(parentEmail), isTrue, reason: 'Duplicate parent_email on row $i');

        expect(['Male', 'Female'].contains(gender), isTrue, reason: 'Invalid gender on row $i');
        expect(_isValidMonthDayYear(birthdate), isTrue, reason: 'Invalid birthdate on row $i');
        expect(contactNumber.isNotEmpty, isTrue, reason: 'Empty contact_number on row $i');
        expect(parentName.isNotEmpty, isTrue, reason: 'Empty parent_name on row $i');
        expect(parentContact.isNotEmpty, isTrue, reason: 'Empty parent_contact on row $i');
        expect(address.isNotEmpty, isTrue, reason: 'Empty address on row $i');
      }
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
