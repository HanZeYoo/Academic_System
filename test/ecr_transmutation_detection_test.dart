import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/services/ecr_parser_service.dart';
import 'package:academic_system/models/ecr_transmutation_model.dart';
import 'package:academic_system/database_helper.dart';

void main() {
  final parser = EcrParserService();

  group('ECR Transmutation Auto-Detection Tests', () {
    test('Computer 7.xlsx detects Transmutation sheet and Base-70 scale with 41 brackets', () async {
      final file = File('Grade 7/Computer 7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'Computer 7.xlsx');

      expect(result.detectedTransmutation.isDetected, isTrue);
      expect(result.detectedTransmutation.passingRawScore, closeTo(70.0, 1.0));
      expect(result.detectedTransmutation.description, contains('Base-70'));
      expect(result.detectedTransmutation.brackets.length, equals(41));

      // Test key lookup points
      final t = result.detectedTransmutation;
      expect(t.lookup(0.0), equals(60));
      expect(t.lookup(4.67), equals(61));
      expect(t.lookup(69.99), equals(75));
      expect(t.lookup(70.0), equals(75));
      expect(t.lookup(71.17), equals(76));
      expect(t.lookup(99.49), equals(100));
      expect(t.lookup(100.0), equals(100));
    });

    test('Science 7.xlsx detects Transmutation sheet and Base-70 scale', () async {
      final file = File('Grade 7/Science 7.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final result = parser.parseFileSync(bytes, 'Science 7.xlsx');

      expect(result.detectedTransmutation.isDetected, isTrue);
      expect(result.detectedTransmutation.passingRawScore, closeTo(70.0, 1.0));
      expect(result.detectedTransmutation.brackets.length, equals(41));
    });

    test('DatabaseHelper.transmuteGrade integrates detected custom table and falls back seamlessly', () {
      final dbHelper = DatabaseHelper();

      // Standard fallback (no table)
      expect(dbHelper.transmuteGrade(100.0), equals(100.0));
      expect(dbHelper.transmuteGrade(70.0), equals(75.0));
      expect(dbHelper.transmuteGrade(0.0), equals(60.0));

      // Custom table lookup
      final custom = EcrTransmutationTable(
        description: 'Test Custom Base-60',
        passingRawScore: 60.0,
        isDetected: true,
        brackets: {
          0.0: 60,
          50.0: 70,
          60.0: 75,
          80.0: 88,
          100.0: 100,
        },
      );

      expect(dbHelper.transmuteGrade(60.0, customTable: custom), equals(75.0));
      expect(dbHelper.transmuteGrade(55.0, customTable: custom), equals(70.0));
      expect(dbHelper.transmuteGrade(100.0, customTable: custom), equals(100.0));
    });
  });
}
