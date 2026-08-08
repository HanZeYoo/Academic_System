import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/ecr_mapping_model.dart';
import '../services/ecr_mapping_engine.dart';
import '../services/ecr_parser_service.dart';
import '../services/ecr_validator.dart';

class EcrImportScreen extends StatefulWidget {
  final String username; // Teacher email or username

  const EcrImportScreen({super.key, required this.username});

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
  String _selectedPeriod = '1st Quarter';

  // Parser & Engine
  final EcrParserService _parserService = EcrParserService();
  final EcrMappingEngine _mappingEngine = EcrMappingEngine();
  final EcrValidator _validator = EcrValidator();

  // Parsed File Data
  EcrParseResult? _parseResult;
  List<EcrColumnMapping> _columnMappings = [];
  EcrValidationSummary? _validationSummary;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file data.')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _statusMessage = 'Parsing ECR file and resolving merged cells...';
      });

      final parseRes = await _parserService.parseFile(bytes, file.name);

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

      setState(() {
        _parseResult = parseRes;
        _columnMappings = mappings;
        _currentStep = 1;
        _isLoading = false;
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parsing Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  void _proceedToValidation() {
    if (_parseResult == null) return;

    final summary = _validator.validateFullDataset(
      dataRows: _parseResult!.dataRows,
      mappings: _columnMappings,
    );

    setState(() {
      _validationSummary = summary;
      _currentStep = 2;
    });
  }

  // ── STEP 4: SAVE TO SUPABASE & PERSIST TEMPLATE ─────────────────────────

  Future<void> _executeSave({bool skipErrors = false}) async {
    if (_parseResult == null || _selectedClassRecord == null) return;

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

    // Map column index to target category
    final studentNameCol = _columnMappings.where((m) => m.target == EcrTargetCategory.studentName).firstOrNull?.columnIndex;
    final lrnCol = _columnMappings.where((m) => m.target == EcrTargetCategory.lrn).firstOrNull?.columnIndex;

    List<Map<String, dynamic>> scoresToInsert = [];

    // Collect mappings for score components
    final scoreMappings = _columnMappings.where((m) => m.target.isNumeric && !m.target.isHps && m.target != EcrTargetCategory.totalGrade && m.target != EcrTargetCategory.ignore).toList();

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
      }
      if (lrnCol != null && lrnCol < row.length) {
        studentId = row[lrnCol]?.toString().trim() ?? '';
      }
      if (studentId.isEmpty && studentName.isNotEmpty) {
        studentId = studentName;
      }

      if (studentName.isEmpty && studentId.isEmpty) {
        if (skipErrors) continue;
      }

      for (final m in scoreMappings) {
        if (m.columnIndex >= row.length) continue;
        final rawVal = row[m.columnIndex]?.toString().trim() ?? '';
        if (rawVal.isEmpty) continue;

        final scoreNum = double.tryParse(rawVal);
        if (scoreNum == null || scoreNum < 0) {
          if (skipErrors) continue;
        }

        final categoryName = _getCategoryName(m.target);
        final itemLabel = m.target.label;
        final compKey = m.target.component ?? 'WW';
        final totalHps = m.customHps ?? hpsLookup[compKey] ?? 100.0;

        scoresToInsert.add({
          'student_id': studentId,
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
        });
      }
    }

    // Insert scores into Supabase
    final insertedCount = await DatabaseHelper().batchSaveScores(scoresToInsert);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $insertedCount grade records!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getCategoryName(EcrTargetCategory target) {
    if (target.label.startsWith('WW')) return 'Quiz';
    if (target.label.startsWith('PT')) return 'Activity';
    if (target.label == 'QA') return 'Exam';
    return 'Quiz';
  }

  // ── BUILD UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF1E293B)),
            SizedBox(width: 10),
            Text(
              'ECR Grade Import',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderContextCard(),
                  const SizedBox(height: 20),
                  _buildStepIndicator(),
                  const SizedBox(height: 20),
                  if (_currentStep == 0) _buildUploadStep(),
                  if (_currentStep == 1) _buildMappingStep(),
                  if (_currentStep == 2) _buildValidationStep(),
                  if (_currentStep == 3) _buildSuccessStep(),
                ],
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
              _statusMessage ?? 'Please wait while AcadInsight processes your class record...',
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
                      'AcadInsight automatically resolves merged cells and remembers your column mappings for future uploads.',
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

  Widget _buildHeaderContextCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Target Class & Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedClassRecord,
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPeriod,
                          decoration: InputDecoration(
                            labelText: 'Grading Period',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: '1st Quarter', child: Text('1st Quarter')),
                            DropdownMenuItem(value: '2nd Quarter', child: Text('2nd Quarter')),
                            DropdownMenuItem(value: '3rd Quarter', child: Text('3rd Quarter')),
                            DropdownMenuItem(value: '4th Quarter', child: Text('4th Quarter')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPeriod = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP INDICATOR ───────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final steps = ['1. Upload File', '2. Confirm Mapping', '3. Validate', '4. Complete'];
    return Row(
      children: List.generate(steps.length, (idx) {
        final isActive = idx == _currentStep;
        final isDone = idx < _currentStep;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
              style: TextStyle(
                color: (isActive || isDone) ? Colors.white : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── STEP 1: UPLOAD CARD ──────────────────────────────────────────────────

  Widget _buildUploadStep() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, size: 48, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Electronic Class Record (ECR)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supports Excel (.xlsx, .xls) and CSV (.csv) files with merged cells or stacked headers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAndParseFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose File from Computer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: MAPPING CONFIRMATION STEP ────────────────────────────────────

  Widget _buildMappingStep() {
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
            child: Row(
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

        const SizedBox(height: 12),

        // Default HPS Config Bar
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
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
                      Text(
                        cellVal,
                        style: const TextStyle(fontSize: 13),
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
    String badgeText = 'High Match';

    if (mapping.isLowConfidence) {
      badgeColor = Colors.amber.shade700;
      badgeText = 'Check Mapping';
    }
    if (mapping.assumedHps) {
      badgeColor = Colors.orange.shade800;
      badgeText = 'Assumed HPS (${mapping.customHps?.toInt()})';
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
              if (mapping.hasTypeMismatch)
                Tooltip(
                  message: 'Non-numeric score string detected in preview data rows!',
                  child: const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
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
            underline: Container(height: 2, color: mapping.isLowConfidence ? Colors.amber : Colors.blue),
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
                  mapping.isLowConfidence = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ── STEP 3: VALIDATION SUMMARY STEP ──────────────────────────────────────

  Widget _buildValidationStep() {
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
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  summary.hasErrors ? Icons.error_outline : Icons.check_circle_outline,
                  size: 36,
                  color: summary.hasErrors ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.hasErrors ? 'Validation Issues Found' : 'Full Dataset Validated Successfully!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: summary.hasErrors ? Colors.red.shade900 : Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Rows: ${summary.totalRows}  |  Ready: ${summary.validRows}  |  Errors: ${summary.errorRows}',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

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

        const SizedBox(height: 20),

        if (summary.errors.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              separatorBuilder: (_, __) => const Divider(height: 1),
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

  // ── STEP 4: SUCCESS STEP ─────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFF0FDF4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'ECR Grades Successfully Saved!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
            ),
            const SizedBox(height: 8),
            const Text(
              'All mapped scores have been safely written to Supabase, and your column mapping layout has been saved as a reusable template for future uploads.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF047857)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                      _parseResult = null;
                      _columnMappings = [];
                      _validationSummary = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Import Another ECR File'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
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
