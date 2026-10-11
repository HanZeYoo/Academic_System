import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'web_download_helper.dart';

class EcrTemplateConfig {
  final String subjectCode;
  final String subjectName;
  final String gradeLevel;
  final String section;
  final String schoolYear;
  final String gradingPeriod;
  final String teacherName;
  final int writtenWorksCount;
  final double writtenWorkHps;
  final int performanceTasksCount;
  final double performanceTaskHps;
  final double quarterlyAssessmentHps;
  final double wwWeight;
  final double ptWeight;
  final double qaWeight;
  final List<Map<String, dynamic>> students;

  EcrTemplateConfig({
    required this.subjectCode,
    required this.subjectName,
    required this.gradeLevel,
    required this.section,
    required this.schoolYear,
    required this.gradingPeriod,
    required this.teacherName,
    this.writtenWorksCount = 5,
    this.writtenWorkHps = 20.0,
    this.performanceTasksCount = 5,
    this.performanceTaskHps = 50.0,
    this.quarterlyAssessmentHps = 50.0,
    this.wwWeight = 30.0,
    this.ptWeight = 50.0,
    this.qaWeight = 20.0,
    required this.students,
  });
}

class EcrTemplateService {
  /// Generates a standardized, DepEd-compliant Excel (.xlsx) ECR template byte array
  static Uint8List generateExcelTemplate(EcrTemplateConfig config) {
    final excel = Excel.createExcel();
    const sheetName = 'ECR_Grades';
    
    // Rename default sheet or create
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Helper to write cell safely
    void setCell(int col, int row, dynamic value) {
      final cellIndex = CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
      if (value is int) {
        sheet.cell(cellIndex).value = IntCellValue(value);
      } else if (value is double) {
        sheet.cell(cellIndex).value = DoubleCellValue(value);
      } else {
        sheet.cell(cellIndex).value = TextCellValue(value?.toString() ?? '');
      }
    }

    // Row 0-3: Institutional Metadata Header (New Era University Standard)
    setCell(0, 0, 'NEW ERA UNIVERSITY - ELECTRONIC CLASS RECORD (ECR)');
    setCell(0, 1, 'School Year: ${config.schoolYear}');
    setCell(3, 1, 'Grading Period: ${config.gradingPeriod}');
    setCell(0, 2, 'Subject: ${config.subjectName} (${config.subjectCode})');
    setCell(3, 2, 'Grade & Section: ${config.gradeLevel} - ${config.section}');
    setCell(0, 3, 'Teacher: ${config.teacherName}');
    setCell(3, 3, 'Weights: WW ${config.wwWeight.toInt()}% | PT ${config.ptWeight.toInt()}% | QA ${config.qaWeight.toInt()}%');

    // Row 4: Parent Category Header (Stacked)
    int currentCol = 0;
    setCell(currentCol++, 4, 'LEARNER INFORMATION');
    setCell(currentCol++, 4, 'LEARNER INFORMATION');
    setCell(currentCol++, 4, 'LEARNER INFORMATION');

    // WW parent headers
    for (int i = 0; i < config.writtenWorksCount; i++) {
      setCell(currentCol++, 4, 'WRITTEN WORKS (${config.wwWeight.toInt()}%)');
    }
    setCell(currentCol++, 4, 'WRITTEN WORKS (${config.wwWeight.toInt()}%)'); // Total

    // PT parent headers
    for (int i = 0; i < config.performanceTasksCount; i++) {
      setCell(currentCol++, 4, 'PERFORMANCE TASKS (${config.ptWeight.toInt()}%)');
    }
    setCell(currentCol++, 4, 'PERFORMANCE TASKS (${config.ptWeight.toInt()}%)'); // Total

    // QA parent header
    setCell(currentCol++, 4, 'QUARTERLY ASSESSMENT (${config.qaWeight.toInt()}%)');

    // Summary headers
    setCell(currentCol++, 4, 'SUMMARY');
    setCell(currentCol++, 4, 'SUMMARY');

    // Row 5: Column Sub-headers
    currentCol = 0;
    setCell(currentCol++, 5, 'LRN');
    setCell(currentCol++, 5, 'LEARNER\'S NAME');
    setCell(currentCol++, 5, 'GENDER');

    for (int i = 1; i <= config.writtenWorksCount; i++) {
      setCell(currentCol++, 5, 'WW$i');
    }
    setCell(currentCol++, 5, 'WW Total');

    for (int i = 1; i <= config.performanceTasksCount; i++) {
      setCell(currentCol++, 5, 'PT$i');
    }
    setCell(currentCol++, 5, 'PT Total');

    setCell(currentCol++, 5, 'QA');
    setCell(currentCol++, 5, 'Initial Grade');
    setCell(currentCol++, 5, 'Quarterly Grade');

    // Row 6: Highest Possible Score (HPS) Row
    currentCol = 0;
    setCell(currentCol++, 6, 'HPS');
    setCell(currentCol++, 6, 'HIGHEST POSSIBLE SCORE');
    setCell(currentCol++, 6, '-');

    double wwTotalHps = 0;
    for (int i = 0; i < config.writtenWorksCount; i++) {
      setCell(currentCol++, 6, config.writtenWorkHps);
      wwTotalHps += config.writtenWorkHps;
    }
    setCell(currentCol++, 6, wwTotalHps);

    double ptTotalHps = 0;
    for (int i = 0; i < config.performanceTasksCount; i++) {
      setCell(currentCol++, 6, config.performanceTaskHps);
      ptTotalHps += config.performanceTaskHps;
    }
    setCell(currentCol++, 6, ptTotalHps);

    setCell(currentCol++, 6, config.quarterlyAssessmentHps);
    setCell(currentCol++, 6, 100.0);
    setCell(currentCol++, 6, 100.0);

    // Row 7+: Student Roster Rows
    int currentRow = 7;
    if (config.students.isNotEmpty) {
      // Sort: Males first, then Females (or alphabetical)
      final sortedStudents = List<Map<String, dynamic>>.from(config.students);
      sortedStudents.sort((a, b) {
        final gA = (a['gender']?.toString() ?? '').toLowerCase();
        final gB = (b['gender']?.toString() ?? '').toLowerCase();
        if (gA != gB) {
          if (gA == 'male') return -1;
          if (gB == 'male') return 1;
        }
        return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
      });

      for (final student in sortedStudents) {
        currentCol = 0;
        setCell(currentCol++, currentRow, student['student_id']?.toString() ?? '');
        setCell(currentCol++, currentRow, student['name']?.toString() ?? '');
        setCell(currentCol++, currentRow, student['gender']?.toString() ?? 'N/A');

        // Leave score columns empty for the teacher to fill in
        currentRow++;
      }
    } else {
      // Generate 5 sample placeholder rows if no students enrolled yet
      for (int i = 1; i <= 5; i++) {
        currentCol = 0;
        setCell(currentCol++, currentRow, '10000000000$i');
        setCell(currentCol++, currentRow, 'Sample Student $i');
        setCell(currentCol++, currentRow, i % 2 == 1 ? 'Male' : 'Female');
        currentRow++;
      }
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Generates a standardized CSV ECR template string
  static String generateCsvTemplate(EcrTemplateConfig config) {
    List<List<dynamic>> rows = [];

    // Header metadata (New Era University Standard)
    rows.add(['NEW ERA UNIVERSITY - ELECTRONIC CLASS RECORD (ECR)']);
    rows.add(['School Year: ${config.schoolYear}', 'Grading Period: ${config.gradingPeriod}']);
    rows.add(['Subject: ${config.subjectName} (${config.subjectCode})', 'Grade & Section: ${config.gradeLevel} - ${config.section}', 'Teacher: ${config.teacherName}']);
    rows.add(['Weights: WW ${config.wwWeight.toInt()}% | PT ${config.ptWeight.toInt()}% | QA ${config.qaWeight.toInt()}%']);

    // Stacked Parent Row
    List<dynamic> parentRow = ['LEARNER INFORMATION', 'LEARNER INFORMATION', 'LEARNER INFORMATION'];
    for (int i = 0; i < config.writtenWorksCount; i++) {
      parentRow.add('WRITTEN WORKS (${config.wwWeight.toInt()}%)');
    }
    parentRow.add('WRITTEN WORKS (${config.wwWeight.toInt()}%) Total');
    for (int i = 0; i < config.performanceTasksCount; i++) {
      parentRow.add('PERFORMANCE TASKS (${config.ptWeight.toInt()}%)');
    }
    parentRow.add('PERFORMANCE TASKS (${config.ptWeight.toInt()}%) Total');
    parentRow.add('QUARTERLY ASSESSMENT (${config.qaWeight.toInt()}%)');
    parentRow.add('SUMMARY');
    parentRow.add('SUMMARY');
    rows.add(parentRow);

    // Column Sub-headers
    List<dynamic> colRow = ['LRN', 'LEARNER\'S NAME', 'GENDER'];
    for (int i = 1; i <= config.writtenWorksCount; i++) {
      colRow.add('WW$i');
    }
    colRow.add('WW Total');
    for (int i = 1; i <= config.performanceTasksCount; i++) {
      colRow.add('PT$i');
    }
    colRow.add('PT Total');
    colRow.add('QA');
    colRow.add('Initial Grade');
    colRow.add('Quarterly Grade');
    rows.add(colRow);

    // HPS Row
    List<dynamic> hpsRow = ['HPS', 'HIGHEST POSSIBLE SCORE', '-'];
    double wwTotalHps = 0;
    for (int i = 0; i < config.writtenWorksCount; i++) {
      hpsRow.add(config.writtenWorkHps);
      wwTotalHps += config.writtenWorkHps;
    }
    hpsRow.add(wwTotalHps);
    double ptTotalHps = 0;
    for (int i = 0; i < config.performanceTasksCount; i++) {
      hpsRow.add(config.performanceTaskHps);
      ptTotalHps += config.performanceTaskHps;
    }
    hpsRow.add(ptTotalHps);
    hpsRow.add(config.quarterlyAssessmentHps);
    hpsRow.add(100.0);
    hpsRow.add(100.0);
    rows.add(hpsRow);

    // Student rows
    if (config.students.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(config.students);
      sorted.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
      for (final s in sorted) {
        List<dynamic> studentRow = [
          s['student_id']?.toString() ?? '',
          s['name']?.toString() ?? '',
          s['gender']?.toString() ?? 'N/A',
        ];
        // Empty cells for grades
        for (int i = 0; i < config.writtenWorksCount + config.performanceTasksCount + 4; i++) {
          studentRow.add('');
        }
        rows.add(studentRow);
      }
    }

    String escapeCsv(dynamic item) {
      String text = item.toString();
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    return rows.map((r) => r.map(escapeCsv).join(',')).join('\n');
  }

  /// Saves or prompts download of the generated template
  static Future<String?> saveTemplateFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      if (kIsWeb) {
        // Trigger direct browser download via Blob and AnchorElement
        downloadWebFile(bytes, fileName);
        return fileName;
      } else {
        // Try file_picker save dialog first
        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save ECR Template',
          fileName: fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'csv'],
        );

        if (savePath != null) {
          final file = File(savePath);
          await file.writeAsBytes(bytes);
          return savePath;
        }

        // Fallback to Documents directory
        final dir = await getApplicationDocumentsDirectory();
        final fallbackPath = '${dir.path}/$fileName';
        final file = File(fallbackPath);
        await file.writeAsBytes(bytes);
        return fallbackPath;
      }
    } catch (e) {
      debugPrint('Error saving ECR template: $e');
      return null;
    }
  }
}
