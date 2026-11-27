import 'package:academic_system/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseHelper.defaultStudentPassword', () {
    test('returns 12-digit LRN as default password', () {
      expect(
        DatabaseHelper.defaultStudentPassword('123456789012'),
        '123456789012',
      );
    });

    test('trims whitespace around LRN / Student ID', () {
      expect(
        DatabaseHelper.defaultStudentPassword('  123456789012  '),
        '123456789012',
      );
    });

    test('returns NEU Student ID when provided', () {
      expect(
        DatabaseHelper.defaultStudentPassword('24-1234-567'),
        '24-1234-567',
      );
    });

    test('falls back to student123 when null or blank', () {
      expect(DatabaseHelper.defaultStudentPassword(null), 'student123');
      expect(DatabaseHelper.defaultStudentPassword(''), 'student123');
      expect(DatabaseHelper.defaultStudentPassword('   '), 'student123');
    });
  });
}
