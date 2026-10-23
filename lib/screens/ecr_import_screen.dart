import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/ecr_mapping_model.dart';
import '../services/ecr_mapping_engine.dart';
import '../services/ecr_parser_service.dart';
import '../services/ecr_validator.dart';
import '../utils/dialog_utils.dart';

class EcrImportScreen extends StatefulWidget {
  final String username; // Teacher email or username
  final VoidCallback? onBackToDashboard;

  const EcrImportScreen({
    super.key,
    required this.username,
    this.onBackToDashboard,
  });

  @override
  State<EcrImportScreen> createState() => _EcrImportScreenState();
}

class _EcrImportScreenState extends State<EcrImportScreen> {
  int _currentStep = 0; // 0: Upload, 1: Map Columns, 2: Validate & Confirm, 3: Complete

  bool _isLoading = false;
  bool _isSaving = false;
  String? _statusMessage;

  // Teacher & Class Info
  String? _teacherName;
  List<Map<String, dynamic>> _assignedClasses = [];
  Map<String, dynamic>? _selectedClassRecord;
  String _selectedPeriod = '1st Term';

  // Parser & Engine
  final EcrParserService _parserService = EcrParserService();
  final EcrMappingEngine _mappingEngine = EcrMappingEngine();
  final EcrValidator _validator = EcrValidator();

  // Parsed File Data
  Uint8List? _uploadedBytes;
  String? _uploadedFilename;
  String? _selectedSheetName;
  EcrParseResult? _parseResult;
  List<EcrColumnMapping> _columnMappings = [];
  EcrValidationSummary? _validationSummary;
  EcrRosterMatchResult? _rosterMatchResult;

  // Configurable Defaults
  double _defaultWwHps = 100.0;
  double _defaultPtHps = 100.0;
  double _defaultQaHps = 100.0;

  // Filter for Validation Issues Table
  bool _showOnlyErrorsInValidation = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    final teacherRecord = await DatabaseHelper().getTeacherByEmail(widget.username);
    _teacherName = teacherRecord?['name']?.toString() ?? widget.username;

    List<Map<String, dynamic>> classes = [];
    if (_teacherName != null) {
      classes = await DatabaseHelper().getSubjectClassesByTeacher(_teacherName!);
    }

    setState(() {
      _assignedClasses = classes;
      if (_assignedClasses.isNotEmpty) {
        _selectedClassRecord = _assignedClasses.first;
      }
      _isLoading = false;
    });
  }

  // ── STEP 1: PICK AND PARSE FILE ──────────────────────────────────────────

  Future<void> _pickAndParseFile() async {
    if (_selectedClassRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Subject Class before uploading.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file data.')),
        );
        return;
      }

      _uploadedBytes = bytes;
      _uploadedFilename = file.name;

      setState(() {
        _isLoading = true;
        _statusMessage = 'Parsing ECR file and detecting sheets...';
      });

      final parseRes = await _parserService.parseFile(
        bytes,
        file.name,
        gradingPeriod: _selectedPeriod,
      );
      _selectedSheetName = parseRes.sheetName;

      await _applyMappingsForParseResult(parseRes);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parsing Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _switchSheet(String newSheetName) async {
    if (_uploadedBytes == null || _uploadedFilename == null) return;

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Switching to sheet "$newSheetName"...';
      });

      final parseRes = await _parserService.parseFile(
        _uploadedBytes!,
        _uploadedFilename!,
        targetSheetName: newSheetName,
        gradingPeriod: _selectedPeriod,
      );
      _selectedSheetName = parseRes.sheetName;

      await _applyMappingsForParseResult(parseRes);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error switching sheet: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _applyMappingsForParseResult(EcrParseResult parseRes) async {
    // Check if saved template exists for this teacher & subject
    final teacherId = _teacherName ?? widget.username;
    final subjectId = _selectedClassRecord!['subject_code']?.toString() ?? 'DEFAULT';

    final savedTemplateMap = await DatabaseHelper().getMappingTemplate(
      teacherId: teacherId,
      subjectId: subjectId,
    );

    EcrMappingTemplate? template;
    if (savedTemplateMap != null) {
      template = EcrMappingTemplate(
        teacherId: teacherId,
        subjectId: subjectId,
        mappingJson: savedTemplateMap,
      );
    }

    // Generate column mappings via heuristic engine
    _mappingEngine.defaultWwHps = _defaultWwHps;
    _mappingEngine.defaultPtHps = _defaultPtHps;
    _mappingEngine.defaultQaHps = _defaultQaHps;

    final previewRows = parseRes.dataRows.take(10).toList();
    final mappings = _mappingEngine.autoDetectMappings(
      headers: parseRes.headers,
      previewRows: previewRows,
      savedTemplate: template,
    );

    // Propagate detected horizontal row HPS to mappings
    for (final m in mappings) {
      if (parseRes.rowHpsMap.containsKey(m.columnIndex)) {
        m.detectedRowHps = parseRes.rowHpsMap[m.columnIndex];
      }
    }

    setState(() {
      _parseResult = parseRes;
      _columnMappings = mappings;
      _currentStep = 1;
      _isLoading = false;
      _statusMessage = null;
    });
  }

  // ── STEP 2: RE-EVALUATE MAPPINGS ─────────────────────────────────────────

  void _reevaluateMappings() {
    if (_parseResult == null) return;
    _mappingEngine.defaultWwHps = _defaultWwHps;
    _mappingEngine.defaultPtHps = _defaultPtHps;
    _mappingEngine.defaultQaHps = _defaultQaHps;

    final previewRows = _parseResult!.dataRows.take(10).toList();
    final newMappings = _mappingEngine.autoDetectMappings(
      headers: _parseResult!.headers,
      previewRows: previewRows,
    );

    setState(() {
      _columnMappings = newMappings;
    });
  }

  // ── STEP 3: RUN FULL VALIDATION ──────────────────────────────────────────

  // ── STEP 3: RUN FULL VALIDATION ──────────────────────────────────────────

  void _proceedToValidation() async {
    if (_parseResult == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Validating dataset and checking section roster...';
    });

    final summary = _validator.validateFullDataset(
      dataRows: _parseResult!.dataRows,
      mappings: _columnMappings,
    );

    // Reconcile with official section roster from database
    EcrRosterMatchResult? rosterResult;
    if (_selectedClassRecord != null) {
      final grade = _selectedClassRecord!['grade_level']?.toString() ?? '';
      final section = _selectedClassRecord!['section_name']?.toString() ?? '';
      try {
        final enrolled = await DatabaseHelper().getStudentsBySection(grade, section);
        rosterResult = _validator.reconcileWithRoster(
          dataRows: _parseResult!.dataRows,
          mappings: _columnMappings,
          enrolledStudents: enrolled,
        );
      } catch (e) {
        debugPrint('Note: Could not fetch enrolled students for roster check: $e');
      }
    }

    setState(() {
      _validationSummary = summary;
      _rosterMatchResult = rosterResult;
      _isLoading = false;
      _statusMessage = null;
      _currentStep = 2;
    });
  }

  // ── STEP 4: SAVE TO SUPABASE & PERSIST TEMPLATE ─────────────────────────

  Future<void> _executeSave({bool skipErrors = false}) async {
    if (_parseResult == null || _selectedClassRecord == null) return;

    // If low roster match (< 40%), prompt user with explicit confirmation dialog
    if (_rosterMatchResult != null && _rosterMatchResult!.lowMatchWarning) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Low Class Roster Match'),
            ],
          ),
          content: Text(
            'Only ${(_rosterMatchResult!.matchRate * 100).toInt()}% of students in this file match the enrolled roster for ${_selectedClassRecord?['subject_name']} (${_selectedClassRecord?['grade_level']} - ${_selectedClassRecord?['section_name']}).\n\nAre you sure you want to proceed with importing these scores into this section?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              child: const Text('Import Anyway'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = 'Importing scores into Supabase...';
    });

    final subjectCode = _selectedClassRecord!['subject_code']?.toString() ?? '';
    final subjectName = _selectedClassRecord!['subject_name']?.toString() ?? '';
    final section = _selectedClassRecord!['section_name']?.toString() ?? '';
    final grade = _selectedClassRecord!['grade_level']?.toString() ?? '';
    final teacherId = _teacherName ?? widget.username;
    final now = DateTime.now().toIso8601String();

    // 1. Fetch active class assessment setup labels to align with Encode Scores Screen
    final savedSetup = await DatabaseHelper().getAssessmentSetup(
      subjectCode: subjectCode,
      sectionName: section,
      gradeLevel: grade,
      gradingPeriod: _selectedPeriod,
    );

    List<String> parseLabels(dynamic data, int fallbackCount, String prefix) {
      if (data != null && data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is List && decoded.isNotEmpty) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      } else if (data is List && data.isNotEmpty) {
        return data.map((e) => e.toString()).toList();
      }
      return fallbackCount > 0 ? List.generate(fallbackCount, (i) => '$prefix ${i + 1}') : ['$prefix 1'];
    }

    int wwCount = (savedSetup?['ww_items'] as int?) ?? 10;
    int ptCount = (savedSetup?['pt_items'] as int?) ?? 10;
    int teCount = (savedSetup?['te_items'] as int?) ?? 1;

    final wwLabels = parseLabels(savedSetup?['ww_labels'], wwCount, 'Written Works');
    final ptLabels = parseLabels(savedSetup?['pt_labels'], ptCount, 'Performance Tasks');
    final teLabels = parseLabels(savedSetup?['te_labels'], teCount, 'Term Exams');

    // 2. Fetch enrolled section roster to link each row directly to the official enrolled student_id
    List<Map<String, dynamic>> enrolledStudents = [];
    try {
      enrolledStudents = await DatabaseHelper().getStudentsBySection(grade, section);
    } catch (_) {}

    final Map<String, String> enrolledByLrn = {};
    final Map<String, String> enrolledByName = {};
    for (final s in enrolledStudents) {
      final sLrn = s['student_id']?.toString().trim();
      final sName = s['name']?.toString().trim() ?? '';
      if (sLrn != null && sLrn.isNotEmpty) {
        enrolledByLrn[sLrn] = sLrn;
      }
      if (sName.isNotEmpty) {
        final norm = EcrValidator.normalizeFuzzyName(sName);
        enrolledByName[norm] = sLrn ?? sName;
      }
    }

    // Map column index to target category
    final studentNameCol = _columnMappings.where((m) => m.target == EcrTargetCategory.studentName).firstOrNull?.columnIndex;
    final lrnCol = _columnMappings.where((m) => m.target == EcrTargetCategory.lrn).firstOrNull?.columnIndex;
    final lastNameCol = _columnMappings.where((m) => m.target == EcrTargetCategory.lastName).firstOrNull?.columnIndex;
    final firstNameCol = _columnMappings.where((m) => m.target == EcrTargetCategory.firstName).firstOrNull?.columnIndex;
    final middleInitialCol = _columnMappings.where((m) => m.target == EcrTargetCategory.middleInitial).firstOrNull?.columnIndex;

    List<Map<String, dynamic>> scoresToInsert = [];

    // Collect mappings for score components (exclude totals, calculated % and ignored)
    final scoreMappings = _columnMappings.where((m) =>
        m.target.isNumeric &&
        !m.target.isHps &&
        m.target != EcrTargetCategory.totalGrade &&
        m.target != EcrTargetCategory.componentTotal &&
        m.target != EcrTargetCategory.calculatedIgnore &&
        m.target != EcrTargetCategory.ignore).toList();

    // Build HPS lookup map per component
    Map<String, double> hpsLookup = {
      'WW': _defaultWwHps,
      'PT': _defaultPtHps,
      'QA': _defaultQaHps,
    };

    for (final m in _columnMappings) {
      if (m.target == EcrTargetCategory.hpsWw && m.customHps != null) hpsLookup['WW'] = m.customHps!;
      if (m.target == EcrTargetCategory.hpsPt && m.customHps != null) hpsLookup['PT'] = m.customHps!;
      if (m.target == EcrTargetCategory.hpsQa && m.customHps != null) hpsLookup['QA'] = m.customHps!;
    }

    final dataRows = _parseResult!.dataRows;

    for (int r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];

      // Student identifier
      String studentName = '';
      String studentId = '';

      if (studentNameCol != null && studentNameCol < row.length) {
        studentName = row[studentNameCol]?.toString().trim() ?? '';
      } else if (lastNameCol != null && lastNameCol < row.length) {
        studentName = EcrParserService.combineSplitNames(
          row,
          lastNameCol: lastNameCol,
          firstNameCol: firstNameCol,
          middleInitialCol: middleInitialCol,
        );
      }

      if (lrnCol != null && lrnCol < row.length) {
        studentId = row[lrnCol]?.toString().trim() ?? '';
      }

      // Reconcile with official enrolled roster student_id
      String officialStudentId = studentId;
      if (studentId.isNotEmpty && enrolledByLrn.containsKey(studentId)) {
        officialStudentId = enrolledByLrn[studentId]!;
      } else if (studentName.isNotEmpty) {
        final norm = EcrValidator.normalizeFuzzyName(studentName);
        if (enrolledByName.containsKey(norm)) {
          officialStudentId = enrolledByName[norm]!;
        }
      }

      if (officialStudentId.isEmpty) {
        officialStudentId = studentId.isNotEmpty ? studentId : studentName;
      }

      if (studentName.isEmpty && officialStudentId.isEmpty) {
        if (skipErrors) continue;
      }

      for (final m in scoreMappings) {
        if (m.columnIndex >= row.length) continue;
        final rawVal = row[m.columnIndex]?.toString().trim() ?? '';
        if (rawVal.isEmpty) continue;

        // Skip Excel formula strings that couldn't be evaluated
        if (rawVal.startsWith('=') ||
            RegExp(r'^(?:IF|SUM|COUNT|AVERAGE|ROUND|VLOOKUP)\b', caseSensitive: false).hasMatch(rawVal)) {
          continue;
        }

        final scoreNum = double.tryParse(rawVal);
        if (scoreNum == null || scoreNum < 0) {
          if (skipErrors) continue;
        }

        final categoryName = _getCategoryName(m.target);
        final itemLabel = _getItemLabel(m.target, wwLabels, ptLabels, teLabels, originalHeader: m.originalHeader);
        final compKey = m.target.component ?? 'WW';
        final totalHps = m.customHps ?? hpsLookup[compKey] ?? 100.0;

        final record = {
          'student_id': officialStudentId,
          'student_name': studentName,
          'subject_code': subjectCode,
          'subject_name': subjectName,
          'section_name': section,
          'grade_level': grade,
          'category': categoryName,
          'item_label': itemLabel,
          'grading_period': _selectedPeriod,
          'score': scoreNum ?? 0.0,
          'total_score': totalHps,
          'teacher_name': teacherId,
          'created_at': now,
        };
        if (_selectedClassRecord?['school_year'] != null) {
          record['school_year'] = _selectedClassRecord!['school_year'];
        }

        scoresToInsert.add(record);
      }
    }

    // Clear old scores for this subject, section, and period to prevent duplicate scores on re-import
    await DatabaseHelper().clearScoresForClassPeriod(
      subjectCode: subjectCode,
      sectionName: section,
      gradeLevel: grade,
      gradingPeriod: _selectedPeriod,
      schoolYear: _selectedClassRecord?['school_year']?.toString(),
    );

    // Insert scores into Supabase
    final insertedCount = await DatabaseHelper().batchSaveScores(scoresToInsert);

    // Auto-adapt Assessment Setup with detected weights and mapped labels
    final detectedWeights = _parseResult?.detectedWeights;
    final int finalWwWeight = (detectedWeights?.isDetected == true)
        ? detectedWeights!.wwWeight.toInt()
        : ((savedSetup?['ww_weight'] as int?) ?? 30);
    final int finalPtWeight = (detectedWeights?.isDetected == true)
        ? detectedWeights!.ptWeight.toInt()
        : ((savedSetup?['pt_weight'] as int?) ?? 50);
    final int finalTeWeight = (detectedWeights?.isDetected == true)
        ? detectedWeights!.qaWeight.toInt()
        : ((savedSetup?['te_weight'] as int?) ?? 20);

    // Collect distinct item labels that were actually mapped and inserted
    final List<String> activeWwLabels = [];
    final List<String> activePtLabels = [];
    final List<String> activeTeLabels = [];

    for (final score in scoresToInsert) {
      final cat = score['category']?.toString() ?? '';
      final label = score['item_label']?.toString() ?? '';
      if (cat == 'Written Works' && !activeWwLabels.contains(label)) {
        activeWwLabels.add(label);
      } else if (cat == 'Performance Tasks' && !activePtLabels.contains(label)) {
        activePtLabels.add(label);
      } else if (cat == 'Term Exams' && !activeTeLabels.contains(label)) {
        activeTeLabels.add(label);
      }
    }

    try {
      await DatabaseHelper().saveAssessmentSetup({
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'section_name': section,
        'grade_level': grade,
        'grading_period': _selectedPeriod,
        'teacher_name': teacherId,
        'ww_items': activeWwLabels.isNotEmpty ? activeWwLabels.length : wwCount,
        'pt_items': activePtLabels.isNotEmpty ? activePtLabels.length : ptCount,
        'te_items': activeTeLabels.isNotEmpty ? activeTeLabels.length : teCount,
        'ww_labels': jsonEncode(activeWwLabels.isNotEmpty ? activeWwLabels : wwLabels),
        'pt_labels': jsonEncode(activePtLabels.isNotEmpty ? activePtLabels : ptLabels),
        'te_labels': jsonEncode(activeTeLabels.isNotEmpty ? activeTeLabels : teLabels),
        'ww_weight': finalWwWeight,
        'pt_weight': finalPtWeight,
        'te_weight': finalTeWeight,
        'attendance_weight': (savedSetup?['attendance_weight'] as int?) ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Note: Auto-saving assessment setup: $e');
    }

    // Save column mapping template for future pre-filling
    Map<String, String> templateJson = {};
    for (final m in _columnMappings) {
      if (m.target != EcrTargetCategory.ignore) {
        templateJson[m.originalHeader] = m.target.label;
      }
    }

    await DatabaseHelper().saveMappingTemplate(
      teacherId: teacherId,
      subjectId: subjectCode,
      mappingJson: templateJson,
    );

    setState(() {
      _isSaving = false;
      _statusMessage = null;
      _currentStep = 3;
    });

    if (mounted) {
      final weightsInfo = (detectedWeights?.isDetected == true)
          ? '\n\nGrading weights auto-adapted: WW $finalWwWeight% | PT $finalPtWeight% | QA $finalTeWeight%'
          : '';
      AestheticDialogs.showSuccessDialog(
        context,
        title: 'Grades Imported',
        message: 'Successfully imported $insertedCount grade records into the system!$weightsInfo',
      );
    }
  }

  String _getCategoryName(EcrTargetCategory target) {
    if (target.label.startsWith('WW')) return 'Written Works';
    if (target.label.startsWith('PT')) return 'Performance Tasks';
    if (target.label == 'QA') return 'Term Exams';
    return 'Written Works';
  }

  String _getItemLabel(
    EcrTargetCategory target,
    List<String> wwLabels,
    List<String> ptLabels,
    List<String> teLabels, {
    String? originalHeader,
  }) {
    // If spreadsheet column has a descriptive header (e.g., "Quiz 1", "Assignment 1", "Project", "Quarterly Exam")
    String? meaningfulHeader;
    if (originalHeader != null && originalHeader.trim().isNotEmpty) {
      String clean = originalHeader.trim();
      if (clean.contains(' - ')) {
        final parts = clean.split(' - ');
        clean = parts.last.trim();
      }
      final lower = clean.toLowerCase();
      final isGenericNum = RegExp(r'^\d+$').hasMatch(clean);
      final isGenericCode = RegExp(r'^(?:ww|pt|qa|hps|sw|pet)\s*\d*$', caseSensitive: false).hasMatch(clean);
      final isTotalOrSummary = lower.contains('total') ||
          lower.contains('hps') ||
          lower.contains('highest') ||
          lower.contains('initial grade') ||
          lower.contains('weighted');

      if (!isGenericNum && !isGenericCode && !isTotalOrSummary && clean.length > 1 && clean.length <= 40) {
        meaningfulHeader = clean;
      }
    }

    if (target.label.startsWith('WW')) {
      final numStr = target.label.substring(2);
      final idx = (int.tryParse(numStr) ?? 1) - 1;
      // Preserve custom non-generic name previously defined in setup if present
      if (idx >= 0 && idx < wwLabels.length && !wwLabels[idx].startsWith('Written Works')) {
        return wwLabels[idx];
      }
      return meaningfulHeader ?? (idx >= 0 && idx < wwLabels.length ? wwLabels[idx] : 'Written Works ${idx + 1}');
    }
    if (target.label.startsWith('PT')) {
      final numStr = target.label.substring(2);
      final idx = (int.tryParse(numStr) ?? 1) - 1;
      if (idx >= 0 && idx < ptLabels.length && !ptLabels[idx].startsWith('Performance Tasks')) {
        return ptLabels[idx];
      }
      return meaningfulHeader ?? (idx >= 0 && idx < ptLabels.length ? ptLabels[idx] : 'Performance Tasks ${idx + 1}');
    }
    if (target.label == 'QA') {
      if (teLabels.isNotEmpty && !teLabels.first.startsWith('Term Exams')) {
        return teLabels.first;
      }
      return meaningfulHeader ?? (teLabels.isNotEmpty ? teLabels.first : 'Term Exams 1');
    }
    return target.label;
  }

  // ── BACK CONFIRMATION & NAVIGATION HELPERS ──────────────────────────────

  bool get _hasUnsavedWork {
    if (_currentStep == 3) return false; // Already saved to Supabase
    return _uploadedBytes != null || _parseResult != null || _currentStep > 0;
  }

  Future<bool> _onWillPop() async {
    if (_isSaving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for grade import to complete.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (!_hasUnsavedWork) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Discard Import?'),
          ],
        ),
        content: const Text(
          'You have an active ECR file or mapping in progress. Leaving this screen will discard all unimported grade data.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay & Continue', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  Future<void> _handleBackNavigation() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      if (widget.onBackToDashboard != null) {
        widget.onBackToDashboard!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmBackToUpload() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Change ECR File?'),
          ],
        ),
        content: const Text(
          'Going back to upload will clear your current column mappings and loaded file. Do you want to choose a different file?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay Here', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Choose Another File', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() {
        _currentStep = 0;
        _uploadedBytes = null;
        _uploadedFilename = null;
        _parseResult = null;
        _columnMappings.clear();
        _validationSummary = null;
        _rosterMatchResult = null;
      });
    }
  }

  // ── BUILD UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final canPopRoute = Navigator.canPop(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSaving) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for grade import to complete.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          if (widget.onBackToDashboard != null) {
            widget.onBackToDashboard!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: (widget.onBackToDashboard != null || canPopRoute)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                  tooltip: widget.onBackToDashboard != null ? 'Back to Dashboard' : 'Back',
                  onPressed: _handleBackNavigation,
                )
              : null,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF1E293B)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isMobile ? 'ECR Import' : 'ECR Grade Import',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        ),
        body: (_isLoading || _isSaving)
            ? _buildLoadingScreen()
            : SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderContextCard(isMobile),
                    const SizedBox(height: 16),
                    _buildStepIndicator(isMobile),
                    const SizedBox(height: 16),
                    if (_currentStep == 0) _buildUploadStep(isMobile),
                    if (_currentStep == 1) _buildMappingStep(isMobile),
                    if (_currentStep == 2) _buildValidationStep(isMobile),
                    if (_currentStep == 3) _buildSuccessStep(isMobile),
                  ],
                ),
              ),
      ),
    );
  }

  // ── ANIMATED LOADING SCREEN ──────────────────────────────────────────────

  Widget _buildLoadingScreen() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade900.withAlpha(20),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Spinner with Icon
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    backgroundColor: Color(0xFFEFF6FF),
                  ),
                ),
                Icon(
                  _isSaving ? Icons.cloud_upload_rounded : Icons.sync_rounded,
                  size: 32,
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Loading Title
            Text(
              _isSaving ? 'Saving Grades to Supabase' : 'Processing ECR Spreadsheet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Status Message
            Text(
              _statusMessage ?? 'Please wait while NotifyED processes your class record...',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Animated Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 24),

            // Tip Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'NotifyED automatically resolves merged cells and remembers your column mappings for future uploads.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER CONTEXT CARD ──────────────────────────────────────────────────

  Widget _buildHeaderContextCard(bool isMobile) {
    final classDropdown = DropdownButtonFormField<Map<String, dynamic>>(
      initialValue: _selectedClassRecord,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Class / Subject',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _assignedClasses.map((c) {
        final label = '${c['subject_name']} (${c['grade_level']} - ${c['section_name']})';
        return DropdownMenuItem(value: c, child: Text(label, overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedClassRecord = val);
      },
    );

    final periodDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedPeriod,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Grading Period',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: '1st Term', child: Text('1st Term')),
        DropdownMenuItem(value: '2nd Term', child: Text('2nd Term')),
        DropdownMenuItem(value: '3rd Term', child: Text('3rd Term')),
        DropdownMenuItem(value: '1st Quarter', child: Text('1st Quarter')),
        DropdownMenuItem(value: '2nd Quarter', child: Text('2nd Quarter')),
        DropdownMenuItem(value: '3rd Quarter', child: Text('3rd Quarter')),
        DropdownMenuItem(value: '4th Quarter', child: Text('4th Quarter')),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedPeriod = val);
      },
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Target Class & Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            if (isMobile) ...[
              classDropdown,
              const SizedBox(height: 12),
              periodDropdown,
            ] else ...[
              Row(
                children: [
                  Expanded(child: classDropdown),
                  const SizedBox(width: 12),
                  Expanded(child: periodDropdown),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── STEP INDICATOR ───────────────────────────────────────────────────────

  Widget _buildStepIndicator(bool isMobile) {
    final desktopSteps = ['1. Upload File', '2. Confirm Mapping', '3. Validate', '4. Complete'];
    final mobileSteps = ['1. Upload', '2. Map', '3. Validate', '4. Done'];
    final steps = isMobile ? mobileSteps : desktopSteps;

    return Row(
      children: List.generate(steps.length, (idx) {
        final isActive = idx == _currentStep;
        final isDone = idx < _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: idx == steps.length - 1 ? 0 : 4),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: isMobile ? 2 : 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2563EB)
                  : isDone
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              steps[idx],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (isActive || isDone) ? Colors.white : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 10.5 : 12,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── STEP 1: UPLOAD CARD ──────────────────────────────────────────────────

  Widget _buildUploadStep(bool isMobile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 20 : 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, size: 44, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Electronic Class Record (ECR)',
              style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Supports Excel (.xlsx, .xls) and CSV (.csv) files with merged cells or stacked headers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAndParseFile,
              icon: const Icon(Icons.folder_open),
              label: Text(isMobile ? 'Choose ECR File' : 'Choose File from Computer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Universal Adaptability Engine',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'NotifyED automatically adapts to ANY imported ECR—whether you upload an official DepEd Excel sheet or a flat CSV with arbitrary activity columns.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF15803D), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: MAPPING CONFIRMATION STEP ────────────────────────────────────

  Widget _buildMappingStep(bool isMobile) {
    if (_parseResult == null) return const SizedBox();

    int lowConfidenceCount = _columnMappings.where((m) => m.isLowConfidence && m.target != EcrTargetCategory.ignore).length;
    int typeMismatchCount = _columnMappings.where((m) => m.hasTypeMismatch).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Toolbar
        Card(
          elevation: 0,
          color: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.table_chart_outlined, size: 16),
                            label: Text('File: ${_parseResult!.filename}', style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.white,
                          ),
                          Chip(
                            avatar: Icon(
                              lowConfidenceCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              size: 16,
                              color: lowConfidenceCount > 0 ? Colors.amber[800] : Colors.green[700],
                            ),
                            label: Text(
                              lowConfidenceCount > 0 ? '$lowConfidenceCount Review' : 'All Confident',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: lowConfidenceCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                          ),
                          if (typeMismatchCount > 0)
                            Chip(
                              avatar: const Icon(Icons.error_outline, size: 16, color: Colors.red),
                              label: Text('$typeMismatchCount Non-numeric', style: const TextStyle(fontSize: 12)),
                              backgroundColor: const Color(0xFFFEE2E2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _confirmBackToUpload,
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Change File'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _proceedToValidation,
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Validate & Proceed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.table_chart_outlined, size: 16),
                              label: Text('File: ${_parseResult!.filename}'),
                              backgroundColor: Colors.white,
                            ),
                            Chip(
                              avatar: Icon(
                                lowConfidenceCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                size: 16,
                                color: lowConfidenceCount > 0 ? Colors.amber[800] : Colors.green[700],
                              ),
                              label: Text(
                                lowConfidenceCount > 0 ? '$lowConfidenceCount Low-Confidence Mapping(s)' : 'All Mappings Confident',
                              ),
                              backgroundColor: lowConfidenceCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                            ),
                            if (typeMismatchCount > 0)
                              Chip(
                                avatar: const Icon(Icons.error_outline, size: 16, color: Colors.red),
                                label: Text('$typeMismatchCount Non-numeric Preview Alert(s)'),
                                backgroundColor: const Color(0xFFFEE2E2),
                              ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _confirmBackToUpload,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Change File'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _proceedToValidation,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Validate & Proceed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Sheet Tab Selector (if multiple sheets available)
        if (_parseResult != null && _parseResult!.availableSheets.length > 1) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF93C5FD)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tab_rounded, color: Color(0xFF2563EB), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Active Sheet Tab:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const Spacer(),
                            Text(
                              '${_parseResult!.dataRows.length} students',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButton<String>(
                          value: _selectedSheetName,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _parseResult!.availableSheets.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.sheetName,
                              child: Text(
                                s.isCandidate ? '${s.sheetName} (Candidate)' : s.sheetName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newSheet) {
                            if (newSheet != null && newSheet != _selectedSheetName) {
                              _switchSheet(newSheet);
                            }
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.tab_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Active Sheet Tab:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _selectedSheetName,
                          underline: const SizedBox(),
                          items: _parseResult!.availableSheets.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.sheetName,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.sheetName,
                                    style: TextStyle(
                                      fontWeight: s.isCandidate ? FontWeight.bold : FontWeight.normal,
                                      color: s.isCandidate ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (s.isCandidate) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Candidate',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newSheet) {
                            if (newSheet != null && newSheet != _selectedSheetName) {
                              _switchSheet(newSheet);
                            }
                          },
                        ),
                        const Spacer(),
                        Text(
                          '${_parseResult!.dataRows.length} students detected',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
            ),
          ),
        ],

        // Formula-based column informational notice
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Note: Formula-based columns (such as Final Grade or calculated percentages) cannot be read directly from the spreadsheet file and will be recomputed from item scores.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Dry-Run Ingestion Preview Card
        _buildDryRunSummaryCard(isMobile),

        const SizedBox(height: 12),

        // Default HPS Config Bar
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, color: Color(0xFF64748B), size: 18),
                              SizedBox(width: 6),
                              Text('HPS Fallbacks:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _reevaluateMappings,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Re-apply', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildHpsInput('WW HPS', _defaultWwHps, (v) => setState(() => _defaultWwHps = v)),
                          _buildHpsInput('PT HPS', _defaultPtHps, (v) => setState(() => _defaultPtHps = v)),
                          _buildHpsInput('QA HPS', _defaultQaHps, (v) => setState(() => _defaultQaHps = v)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Text('Default Component HPS Fallbacks:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      _buildHpsInput('WW HPS', _defaultWwHps, (v) => setState(() => _defaultWwHps = v)),
                      const SizedBox(width: 12),
                      _buildHpsInput('PT HPS', _defaultPtHps, (v) => setState(() => _defaultPtHps = v)),
                      const SizedBox(width: 12),
                      _buildHpsInput('QA HPS', _defaultQaHps, (v) => setState(() => _defaultQaHps = v)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _reevaluateMappings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-apply Heuristics'),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Preview Table
        const Text(
          'Preview & Header Mapping (First 10 Rows)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 110,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 50,
              columns: List.generate(_columnMappings.length, (colIdx) {
                final mapping = _columnMappings[colIdx];
                return DataColumn(
                  label: _buildColumnHeaderWidget(mapping),
                );
              }),
              rows: List.generate(_parseResult!.dataRows.length.clamp(0, 10), (rowIdx) {
                final row = _parseResult!.dataRows[rowIdx];
                return DataRow(
                  cells: List.generate(_columnMappings.length, (colIdx) {
                    final cellVal = colIdx < row.length ? row[colIdx]?.toString() ?? '' : '';
                    return DataCell(
                      InkWell(
                        onTap: () => _showEditCellDialog(rowIdx, colIdx, cellVal),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cellVal,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 11, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditCellDialog(int rowIdx, int colIdx, String currentVal) {
    final controller = TextEditingController(text: currentVal);
    final headerName = colIdx < _columnMappings.length ? _columnMappings[colIdx].originalHeader : 'Column';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Cell Value ($headerName)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Row ${rowIdx + 1} preview value:',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newVal = controller.text.trim();
              setState(() {
                if (rowIdx < _parseResult!.dataRows.length && colIdx < _parseResult!.dataRows[rowIdx].length) {
                  _parseResult!.dataRows[rowIdx][colIdx] = newVal;
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Save Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildDryRunSummaryCard(bool isMobile) {
    if (_parseResult == null) return const SizedBox();

    final studentCount = _parseResult!.dataRows.length;
    final excludedCount = _parseResult!.excludedRows.length;
    final lowConfidenceCols = _columnMappings.where((m) => m.isLowConfidence && m.target != EcrTargetCategory.ignore).length;
    final activeCols = _columnMappings.where((m) => m.target != EcrTargetCategory.ignore).length;

    final studentTile = _buildMetricTile(
      icon: Icons.people_alt_outlined,
      iconColor: const Color(0xFF2563EB),
      title: '$studentCount Students',
      subtitle: 'Detected for import',
    );

    final excludedTile = InkWell(
      onTap: excludedCount > 0 ? _showExcludedRowsDialog : null,
      borderRadius: BorderRadius.circular(8),
      child: _buildMetricTile(
        icon: Icons.playlist_remove_rounded,
        iconColor: const Color(0xFF64748B),
        title: '$excludedCount Excluded Rows',
        subtitle: excludedCount > 0 ? 'Click to inspect skipped' : 'No rows skipped',
        showClickable: excludedCount > 0,
      ),
    );

    final mappedTile = _buildMetricTile(
      icon: Icons.view_column_outlined,
      iconColor: const Color(0xFF059669),
      title: '$activeCols Mapped Columns',
      subtitle: lowConfidenceCols > 0 ? '$lowConfidenceCols flagged' : 'Auto-assigned',
    );

    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Dry-Run Ingestion Preview',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lowConfidenceCols > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lowConfidenceCols > 0 ? '$lowConfidenceCols review' : 'Confident',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: lowConfidenceCols > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMobile) ...[
              Column(
                children: [
                  studentTile,
                  const SizedBox(height: 8),
                  excludedTile,
                  const SizedBox(height: 8),
                  mappedTile,
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: studentTile),
                  const SizedBox(width: 12),
                  Expanded(child: excludedTile),
                  const SizedBox(width: 12),
                  Expanded(child: mappedTile),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExcludedRowsDialog() {
    if (_parseResult == null || _parseResult!.excludedRows.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.playlist_remove_rounded, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text('Excluded Rows (${_parseResult!.excludedRows.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These rows were recognized as section headers, gender dividers, or summary totals and are safely skipped from student scoring.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _parseResult!.excludedRows.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = _parseResult!.excludedRows[idx];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Row ${item.rowIndex}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                        title: Text(item.rawText, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(item.reason, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool showClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: showClickable ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                Text(subtitle, style: TextStyle(fontSize: 11, color: showClickable ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHpsInput(String label, double currentVal, Function(double) onChanged) {
    return SizedBox(
      width: 110,
      child: TextFormField(
        initialValue: currentVal.toInt().toString(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null && parsed > 0) onChanged(parsed);
        },
      ),
    );
  }

  Widget _buildColumnHeaderWidget(EcrColumnMapping mapping) {
    Color badgeColor = Colors.green;
    String badgeText = 'High Match (${(mapping.confidenceScore * 100).toInt()}%)';

    if (mapping.confidenceScore < 0.60) {
      badgeColor = Colors.red.shade700;
      badgeText = 'Check Mapping';
    } else if (mapping.confidenceScore < 0.85) {
      badgeColor = Colors.amber.shade800;
      badgeText = 'Review (${(mapping.confidenceScore * 100).toInt()}%)';
    }

    if (mapping.detectedRowHps != null) {
      badgeText += ' • HPS: ${mapping.detectedRowHps!.toInt()}';
    } else if (mapping.assumedHps) {
      badgeText += ' • Default HPS';
    }

    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mapping.originalHeader,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (mapping.reasons.isNotEmpty)
                Tooltip(
                  message: mapping.reasons.join('\n'),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                  ),
                ),
              if (mapping.hasTypeMismatch)
                Tooltip(
                  message: 'Non-numeric score string detected in preview data rows!',
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButton<EcrTargetCategory>(
            value: mapping.target,
            isExpanded: true,
            isDense: true,
            underline: Container(
              height: 2,
              color: mapping.confidenceScore < 0.60 ? Colors.red : (mapping.confidenceScore < 0.85 ? Colors.amber : Colors.blue),
            ),
            items: EcrTargetCategory.values.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(
                  cat.label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (newCat) {
              if (newCat != null) {
                setState(() {
                  mapping.target = newCat;
                  mapping.confidenceScore = 1.0;
                  mapping.isLowConfidence = false;
                  mapping.reasons = ['Manually assigned by teacher'];
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ── STEP 3: VALIDATION SUMMARY STEP ──────────────────────────────────────

  Widget _buildValidationStep(bool isMobile) {
    if (_validationSummary == null) return const SizedBox();

    final summary = _validationSummary!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: summary.hasErrors ? Colors.red.shade200 : Colors.green.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          color: summary.hasErrors ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  summary.hasErrors ? Icons.error_outline : Icons.check_circle_outline,
                  size: 36,
                  color: summary.hasErrors ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.hasErrors ? 'Validation Issues Found' : 'Full Dataset Validated Successfully!',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: summary.hasErrors ? Colors.red.shade900 : Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${summary.totalRows}  |  Ready: ${summary.validRows}  |  Errors: ${summary.errorRows}',
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_rosterMatchResult != null) ...[
          const SizedBox(height: 12),
          _buildRosterReconciliationCard(_rosterMatchResult!, isMobile),
        ],

        const SizedBox(height: 12),
        _buildWeightsDetectedCard(),

        const SizedBox(height: 16),

        if (isMobile) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary.hasErrors) ...[
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _executeSave(skipErrors: true),
                  icon: const Icon(Icons.filter_alt_off),
                  label: Text('Skip Errors (${summary.validRows} OK) & Import'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: summary.hasErrors || _isSaving ? null : () => _executeSave(skipErrors: false),
                icon: const Icon(Icons.save_alt),
                label: const Text('Confirm & Save to Supabase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _currentStep = 1),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Mapping'),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Mapping'),
              ),
              Row(
                children: [
                  if (summary.hasErrors) ...[
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _executeSave(skipErrors: true),
                      icon: const Icon(Icons.filter_alt_off),
                      label: Text('Skip Error Rows (${summary.validRows} OK) & Import'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade900),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: summary.hasErrors || _isSaving ? null : () => _executeSave(skipErrors: false),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Confirm & Save All to Supabase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        if (summary.errors.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text('Detailed Issue Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              FilterChip(
                label: const Text('Show Only Fatal Errors'),
                selected: _showOnlyErrorsInValidation,
                onSelected: (val) => setState(() => _showOnlyErrorsInValidation = val),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              itemCount: summary.errors.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final err = summary.errors[idx];
                if (_showOnlyErrorsInValidation && err.isWarning) return const SizedBox();

                return ListTile(
                  dense: true,
                  leading: Icon(
                    err.isWarning ? Icons.warning_amber_rounded : Icons.cancel,
                    color: err.isWarning ? Colors.orange : Colors.red,
                  ),
                  title: Text(err.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Row: ${err.rowIndex} | Column: ${err.columnName}'),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRosterReconciliationCard(EcrRosterMatchResult roster, bool isMobile) {
    final isLow = roster.lowMatchWarning;
    final matchPct = (roster.matchRate * 100).toInt();

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${roster.matchedCount} matched / ${roster.unmatchedCount} unmatched',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: isLow ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
        ),
      ),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isLow ? Colors.orange.shade300 : const Color(0xFF93C5FD)),
        borderRadius: BorderRadius.circular(12),
      ),
      color: isLow ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              Row(
                children: [
                  Icon(
                    isLow ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                    color: isLow ? Colors.orange.shade800 : const Color(0xFF2563EB),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isLow ? 'Roster Match Warning ($matchPct%)' : 'Roster Reconciled ($matchPct%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isLow ? Colors.orange.shade900 : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              badge,
            ] else ...[
              Row(
                children: [
                  Icon(
                    isLow ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                    color: isLow ? Colors.orange.shade800 : const Color(0xFF2563EB),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isLow ? 'Class Roster Match Warning ($matchPct%)' : 'Class Roster Reconciled ($matchPct%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isLow ? Colors.orange.shade900 : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  badge,
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              isLow
                  ? 'Only $matchPct% of students in this file match the enrolled roster for the selected section. If you imported the wrong section, click "Back to Mapping" or switch class above.'
                  : 'Students in this ECR were successfully cross-referenced with active section enrollment by LRN and student name.',
              style: TextStyle(
                fontSize: 12,
                color: isLow ? const Color(0xFF92400E) : const Color(0xFF3B82F6),
              ),
            ),
            if (roster.unmatchedNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Unmatched students: ${roster.unmatchedNames.take(3).join(', ')}${roster.unmatchedNames.length > 3 ? ' and ${roster.unmatchedNames.length - 3} more' : ''}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeightsDetectedCard() {
    final weights = _parseResult?.detectedWeights;
    final isDetected = weights?.isDetected == true;
    final ww = weights?.wwWeight.toInt() ?? 30;
    final pt = weights?.ptWeight.toInt() ?? 50;
    final qa = weights?.qaWeight.toInt() ?? 20;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isDetected ? const Color(0xFF6EE7B7) : const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDetected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isDetected ? Icons.auto_awesome : Icons.tune,
              color: isDetected ? const Color(0xFF059669) : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        isDetected ? 'Grading Weights Auto-Detected' : 'Standard DepEd Weights Applied',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDetected ? const Color(0xFF065F46) : const Color(0xFF334155),
                        ),
                      ),
                      if (isDetected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AUTO-ADAPTED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Written Works: $ww%  •  Performance Tasks: $pt%  •  Quarterly Exam: $qa%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDetected ? const Color(0xFF047857) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDetected
                        ? 'The system will automatically configure class grade computation with these weights upon saving.'
                        : 'No custom weights found in file header. Using standard DepEd 30-50-20 distribution.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDetected ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 4: SUCCESS STEP ─────────────────────────────────────────────────

  Widget _buildSuccessStep(bool isMobile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFF0FDF4),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'ECR Grades Successfully Saved!',
              style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'All mapped scores have been safely written to Supabase, and your column mapping layout has been saved as a reusable template for future uploads.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF047857)),
            ),
            if (_parseResult?.detectedWeights != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _parseResult!.detectedWeights.isDetected ? Icons.auto_awesome : Icons.check_circle_outline,
                      color: const Color(0xFF065F46),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _parseResult!.detectedWeights.isDetected
                            ? 'Grading Weights Auto-Adapted: WW ${_parseResult!.detectedWeights.wwWeight.toInt()}% | PT ${_parseResult!.detectedWeights.ptWeight.toInt()}% | QA ${_parseResult!.detectedWeights.qaWeight.toInt()}%'
                            : 'Standard DepEd Weights Applied: WW 30% | PT 50% | QA 20%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                      _uploadedBytes = null;
                      _uploadedFilename = null;
                      _parseResult = null;
                      _columnMappings = [];
                      _validationSummary = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Import Another ECR File'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onBackToDashboard != null) {
                      widget.onBackToDashboard!();
                    } else if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Dashboard'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
