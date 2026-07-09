import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import '../database_helper.dart';

class EncodeScoresScreen extends StatefulWidget {
  final String username;
  const EncodeScoresScreen({super.key, required this.username});

  @override
  State<EncodeScoresScreen> createState() => _EncodeScoresScreenState();
}

class _EncodeScoresScreenState extends State<EncodeScoresScreen> {
  // --- State ---
  bool _isLoading = true;
  bool _isSaving = false;

  String? _teacherName;
  List<Map<String, dynamic>> _assignedClasses = [];
  Map<String, dynamic>? _selectedClassRecord;

  String _selectedPeriod = '1st Quarter';
  String _selectedCategory = 'Quiz';
  String _selectedItem = 'Quiz 1';
  int _totalScore = 50;

  final TextEditingController _totalScoreController =
      TextEditingController(text: '50');

  // student_id -> score value (from text controllers)
  final Map<String, TextEditingController> _scoreControllers = {};
  
  // category_item -> drafted total score
  final Map<String, int> _draftTotalScores = {};
  
  // category_item -> { student_id -> drafted score }
  final Map<String, Map<String, int>> _draftStudentScores = {};

  List<Map<String, dynamic>> _students = [];

  // --- Cached CSV Data ---
  List<List<dynamic>>? _cachedCsvData;
  String? _cachedCsvFilename;

  // --- Item options per category ---
  Map<String, List<String>> _itemsPerCategory = {
    'Quiz': ['Quiz 1', 'Quiz 2', 'Quiz 3'],
    'Assignment': ['Assignment 1', 'Assignment 2'],
    'Activity': ['Activity 1', 'Activity 2', 'Activity 3'],
    'Project': ['Project 1'],
    'Exam': ['Exam 1'],
  };

  List<String> get _currentItems =>
      _itemsPerCategory[_selectedCategory] ?? ['Item 1'];

  @override
  void initState() {
    super.initState();
    _totalScoreController.addListener(_onTotalScoreChanged);
    _loadData();
  }

  void _onTotalScoreChanged() {
    final v = int.tryParse(_totalScoreController.text);
    if (v != null && v > 0) {
      setState(() => _totalScore = v);
      _draftTotalScores['${_selectedCategory}_$_selectedItem'] = v;
    }
  }

  @override
  void dispose() {
    _totalScoreController.dispose();
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final teacherRecord =
        await DatabaseHelper().getTeacherByEmail(widget.username);
    _teacherName = teacherRecord?['name']?.toString();

    List<Map<String, dynamic>> classes = [];
    if (_teacherName != null) {
      classes =
          await DatabaseHelper().getSubjectClassesByTeacher(_teacherName!);
    }

    setState(() {
      _assignedClasses = classes;
      _selectedClassRecord = classes.isNotEmpty ? classes.first : null;
    });

    await _loadStudentsAndScores();
    setState(() => _isLoading = false);
  }

  Future<void> _loadStudentsAndScores() async {
    if (_selectedClassRecord == null) {
      setState(() => _students = []);
      return;
    }

    final grade = _selectedClassRecord!['grade_level']?.toString() ?? '';
    final section = _selectedClassRecord!['section_name']?.toString() ?? '';
    final subjectCode =
        _selectedClassRecord!['subject_code']?.toString() ?? '';

    // Get students in this class's section
    final students =
        await DatabaseHelper().getStudentsBySection(grade, section);

    // Load setup for item counts
    final savedSetup = await DatabaseHelper().getAssessmentSetup(
      subjectCode: subjectCode,
      sectionName: section,
      gradeLevel: grade,
      gradingPeriod: _selectedPeriod,
    );

    int quizzes = 3, assignments = 2, activities = 3, projects = 1, exams = 1;
    if (savedSetup != null) {
      quizzes = (savedSetup['quizzes'] as int?) ?? 3;
      assignments = (savedSetup['assignments'] as int?) ?? 2;
      activities = (savedSetup['activities'] as int?) ?? 3;
      projects = (savedSetup['projects'] as int?) ?? 1;
      exams = (savedSetup['exams'] as int?) ?? 1;
    }

    // Update the map dynamically
    _itemsPerCategory = {
      'Quiz': quizzes > 0 ? List.generate(quizzes, (i) => 'Quiz ${i + 1}') : ['Quiz 1'],
      'Assignment': assignments > 0 ? List.generate(assignments, (i) => 'Assignment ${i + 1}') : ['Assignment 1'],
      'Activity': activities > 0 ? List.generate(activities, (i) => 'Activity ${i + 1}') : ['Activity 1'],
      'Project': projects > 0 ? List.generate(projects, (i) => 'Project ${i + 1}') : ['Project 1'],
      'Exam': exams > 0 ? List.generate(exams, (i) => 'Exam ${i + 1}') : ['Exam 1'],
    };

    // Ensure selected category and item are valid
    if (!_itemsPerCategory.keys.contains(_selectedCategory)) {
      _selectedCategory = _itemsPerCategory.keys.first;
    }
    if (!_currentItems.contains(_selectedItem)) {
      _selectedItem = _currentItems.first;
    }

    // Get existing scores for current filter
    final existingScores = await DatabaseHelper().getScores(
      subjectCode: subjectCode,
      category: _selectedCategory,
      itemLabel: _selectedItem,
      gradingPeriod: _selectedPeriod,
    );

    // Restore Total Score if existing records found
    final draftKey = '${_selectedCategory}_$_selectedItem';
    if (_draftTotalScores.containsKey(draftKey)) {
      _totalScore = _draftTotalScores[draftKey]!;
      _totalScoreController.text = _totalScore.toString();
    } else if (existingScores.isNotEmpty) {
      final dbTotal = (existingScores.first['total_score'] as num?)?.toInt();
      if (dbTotal != null && dbTotal > 0) {
        _totalScore = dbTotal;
        _totalScoreController.text = dbTotal.toString();
        // Also save to draft so it's consistent
        _draftTotalScores[draftKey] = dbTotal;
      }
    } else {
      _totalScore = 50;
      _totalScoreController.text = '50';
    }

    // Map student_id -> score
    final scoreMap = <String, double>{};
    for (final s in existingScores) {
      scoreMap[s['student_id']?.toString() ?? ''] =
          (s['score'] as num?)?.toDouble() ?? 0;
    }

    // Override with any drafted student scores for this item
    if (_draftStudentScores.containsKey(draftKey)) {
      _draftStudentScores[draftKey]!.forEach((sid, draftScore) {
        scoreMap[sid] = draftScore.toDouble();
      });
    }

    // Build / update score controllers
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    _scoreControllers.clear();

    for (final student in students) {
      final sid = student['student_id']?.toString() ?? '';
      final existing = scoreMap[sid] ?? 0;
      final ctrl = TextEditingController(
          text: existing > 0 ? existing.toInt().toString() : '');
      
      // Save changes to draft on typing
      ctrl.addListener(() {
        final val = int.tryParse(ctrl.text);
        if (val != null) {
          _draftStudentScores.putIfAbsent(draftKey, () => {});
          _draftStudentScores[draftKey]![sid] = val;
        }
      });
      
      _scoreControllers[sid] = ctrl;
    }

    setState(() => _students = students);

    // After loading DB data, if we have a cached CSV, apply it over the DB data.
    if (_cachedCsvData != null) {
       _applyCsvToCurrentItem();
    }
  }

  // ── CSV Import Logic ──────────────────────────────────────────────────────

  Future<void> _uploadMasterCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input.transform(utf8.decoder).transform(csv.decoder).toList();

        if (fields.isEmpty || fields.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV file is empty or missing PERFECT_SCORE row.')));
          }
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          _cachedCsvData = fields;
          _cachedCsvFilename = result.files.single.name;
        });

        _applyCsvToCurrentItem();
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Master CSV "$_cachedCsvFilename" uploaded successfully. Auto-filling scores...'), backgroundColor: Colors.green));
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading CSV: $e'), backgroundColor: Colors.red));
      }
      setState(() => _isLoading = false);
    }
  }

  void _applyCsvToCurrentItem() {
    if (_cachedCsvData == null || _cachedCsvData!.isEmpty) return;

    final headers = _cachedCsvData![0].map((e) => e.toString().trim()).toList();

    int targetColIdx = -1;
    for (int i = 0; i < headers.length; i++) {
      if (headers[i].toLowerCase() == _selectedItem.toLowerCase()) {
        targetColIdx = i;
        break;
      }
    }

    if (targetColIdx == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Column "$_selectedItem" not found in uploaded CSV. Text fields will show existing database scores.'), backgroundColor: Colors.orange));
      }
      return;
    }

    int matchedCount = 0;
    for (int i = 1; i < _cachedCsvData!.length; i++) { // Skip header only
      final row = _cachedCsvData![i];
      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
      
      final csvStudentId = row[0].toString().trim();
      
      if (targetColIdx < row.length) {
         final scoreStr = row[targetColIdx].toString().trim();
         final scoreVal = int.tryParse(scoreStr);
         
         if (scoreVal != null && _scoreControllers.containsKey(csvStudentId)) {
            _scoreControllers[csvStudentId]!.text = scoreVal.toString();
            matchedCount++;
         }
      }
    }
    
    // Trigger UI rebuild so StatefulBuilders update the text and percentages
    setState(() {});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _classLabel {
    if (_selectedClassRecord == null) return 'No class selected';
    final subj = _selectedClassRecord!['subject_name']?.toString() ?? '';
    final grade = _selectedClassRecord!['grade_level']?.toString() ?? '';
    final section = _selectedClassRecord!['section_name']?.toString() ?? '';
    return '$subj – $grade $section'.trim();
  }

  int _scoreOf(String studentId) {
    return int.tryParse(_scoreControllers[studentId]?.text ?? '') ?? 0;
  }

  String _percentage(int score) {
    if (_totalScore <= 0) return '0%';
    return '${((score / _totalScore) * 100).round()}%';
  }

  bool _isPassed(int score) {
    if (_totalScore <= 0) return false;
    return (score / _totalScore) * 100 >= 65;
  }

  int get _encodedCount =>
      _students.where((s) => _scoreOf(s['student_id']?.toString() ?? '') > 0).length;

  int get _pendingCount => _students.length - _encodedCount;

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveScores() async {
    if (_selectedClassRecord == null) return;

    // Check if any student score field is empty or invalid
    bool hasEmptyScore = false;
    bool hasInvalidScore = false;
    for (final student in _students) {
      final sid = student['student_id']?.toString() ?? '';
      final valStr = _scoreControllers[sid]?.text.trim() ?? '';
      if (valStr.isEmpty) {
        hasEmptyScore = true;
        break;
      }
      final val = int.tryParse(valStr);
      if (val == null || val < 0 || val > _totalScore) {
        hasInvalidScore = true;
        break;
      }
    }

    if (hasEmptyScore) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All student scores are required. Please enter a score for each student.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (hasInvalidScore) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid score entered. Scores must be numbers between 0 and $_totalScore.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final subjectCode =
        _selectedClassRecord!['subject_code']?.toString() ?? '';
    final subjectName =
        _selectedClassRecord!['subject_name']?.toString() ?? '';
    final grade = _selectedClassRecord!['grade_level']?.toString() ?? '';
    final section = _selectedClassRecord!['section_name']?.toString() ?? '';
    final now = DateTime.now().toIso8601String();

    for (final student in _students) {
      final sid = student['student_id']?.toString() ?? '';
      final score = _scoreOf(sid);
      await DatabaseHelper().saveScore({
        'student_id': sid,
        'student_name': student['name']?.toString() ?? '',
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'section_name': section,
        'grade_level': grade,
        'category': _selectedCategory,
        'item_label': _selectedItem,
        'grading_period': _selectedPeriod,
        'score': score.toDouble(),
        'total_score': _totalScore.toDouble(),
        'teacher_name': _teacherName ?? '',
        'created_at': now,
      });
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scores saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── On filter change: reload students+scores ──────────────────────────────

  void _onFilterChanged() {
    // Reset item if not valid for new category
    if (!_currentItems.contains(_selectedItem)) {
      _selectedItem = _currentItems.first;
    }
    _loadStudentsAndScores();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedClasses.isEmpty
              ? _buildNoClassState()
              : _buildContent(),
    );
  }

  Widget _buildNoClassState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No classes assigned yet.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the admin to assign a class to your account.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Filters Card ─────────────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    if (_cachedCsvData != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Using CSV: $_cachedCsvFilename',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Class selector
                _buildDropdownField(
                  label: 'Class',
                  value: _classLabel,
                  icon: Icons.school_outlined,
                  iconColor: const Color(0xFF0D6EFD),
                  items: _assignedClasses
                      .map((c) =>
                          '${c['subject_name']} – ${c['grade_level']} ${c['section_name']}')
                      .toList(),
                  onChanged: (val) async {
                    final found = _assignedClasses.firstWhere(
                      (c) =>
                          '${c['subject_name']} – ${c['grade_level']} ${c['section_name']}' ==
                          val,
                      orElse: () => _assignedClasses.first,
                    );
                    setState(() => _selectedClassRecord = found);
                    await _loadStudentsAndScores();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Grading Period',
                        value: _selectedPeriod,
                        icon: Icons.calendar_today_outlined,
                        iconColor: const Color(0xFF0D6EFD),
                        items: const [
                          '1st Quarter',
                          '2nd Quarter',
                          '3rd Quarter',
                          '4th Quarter'
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPeriod = val!);
                          _onFilterChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Category',
                        value: _selectedCategory,
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF198754),
                        items: _itemsPerCategory.keys.toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val!;
                            _selectedItem = _currentItems.first;
                          });
                          _onFilterChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Item',
                        value: _selectedItem,
                        icon: Icons.file_present_outlined,
                        iconColor: const Color(0xFF6F42C1),
                        items: _currentItems,
                        onChanged: (val) {
                          setState(() => _selectedItem = val!);
                          _onFilterChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Score',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 4),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: TextField(
                              controller: _totalScoreController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onChanged: (val) {
                                setState(() {
                                  _totalScore = int.tryParse(val) ?? 1;
                                  if (_totalScore <= 0) _totalScore = 1;
                                });
                                // Revalidate student scores against new total
                                for (var ctrl in _scoreControllers.values) {
                                  int? s = int.tryParse(ctrl.text);
                                  if (s != null && s > _totalScore) {
                                    ctrl.text = _totalScore.toString();
                                    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploadMasterCSV,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload CSV (Auto-fill Scores)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Stats ────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total\nStudents',
                  value: '${_students.length}',
                  icon: Icons.people,
                  iconBgColor: const Color(0xFFE7F1FF),
                  iconColor: const Color(0xFF0D6EFD),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: 'Encoded',
                  value: '$_encodedCount',
                  subtitle: _students.isEmpty
                      ? '0%'
                      : '${(_encodedCount / _students.length * 100).round()}%',
                  subtitleColor: const Color(0xFF198754),
                  icon: Icons.check_circle,
                  iconBgColor: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF198754),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: 'Pending',
                  value: '$_pendingCount',
                  subtitle: _students.isEmpty
                      ? '0%'
                      : '${(_pendingCount / _students.length * 100).round()}%',
                  subtitleColor: const Color(0xFFE67E22),
                  icon: Icons.schedule,
                  iconBgColor: const Color(0xFFFEF2E8),
                  iconColor: const Color(0xFFE67E22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Student Score Table ──────────────────────────────────────────
          _buildCard(
            child: _students.isEmpty
                ? _buildEmptyStudents()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note,
                              color: Color(0xFF0D6EFD), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Student Scores — $_selectedItem ($_selectedPeriod)',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Table Header
                      Row(
                        children: [
                          Expanded(
                              flex: 4,
                              child: Text('Student',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 3,
                              child: Text('Score/$_totalScore',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text('%',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text('Status',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Divider(height: 16, color: Colors.black12),
                      ..._students.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final student = entry.value;
                        final sid = student['student_id']?.toString() ?? '';
                        final ctrl = _scoreControllers[sid]!;

                        return StatefulBuilder(builder: (ctx, localSet) {
                          final score = int.tryParse(ctrl.text) ?? 0;
                          final passed = _isPassed(score);
                          return Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    // Name + avatar
                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor: idx % 2 == 0
                                                ? Colors.blue.shade100
                                                : Colors.pink.shade100,
                                            child: Text(
                                              (student['name']
                                                          ?.toString()
                                                          .isNotEmpty ==
                                                      true)
                                                  ? student['name']
                                                      .toString()[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              student['name']?.toString() ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Score input
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            color: Colors.white,
                                          ),
                                          child: TextField(
                                            controller: ctrl,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style:
                                                const TextStyle(fontSize: 13),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              int? parsed = int.tryParse(val);
                                              if (parsed != null) {
                                                if (parsed > _totalScore) {
                                                  ctrl.text = _totalScore.toString();
                                                  ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                                } else if (parsed < 0) {
                                                  ctrl.text = '0';
                                                  ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                                }
                                              }
                                              localSet(() {});
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Percentage
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _percentage(
                                            int.tryParse(ctrl.text) ?? 0),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    // Status badge
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: passed
                                                ? const Color(0xFFE8F5E9)
                                                : const Color(0xFFFEF2E8),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              passed ? 'Passed' : 'At-Risk',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: passed
                                                    ? const Color(0xFF198754)
                                                    : const Color(0xFFE67E22),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (idx < _students.length - 1)
                                const Divider(height: 1, color: Colors.black12),
                            ],
                          );
                        });
                      }).toList(),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // ── Info alert ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F1FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Color(0xFF0D6EFD), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scores are auto-updated if re-saved. Passing mark is 65%.',
                    style: TextStyle(
                        color: Colors.blue.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Buttons ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _loadStudentsAndScores(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D6EFD),
                    side: const BorderSide(color: Color(0xFF0D6EFD)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Refresh',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveScores,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save Scores',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers widgets ───────────────────────────────────────────────────────

  Widget _buildEmptyStudents() {
    return Column(
      children: [
        Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          'No students found in this class section.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Add students with the matching Grade Level and Section in Admin > Student Management.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value is in items list
    final safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: Colors.black54),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Row(
                          children: [
                            Icon(icon, color: iconColor, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(item,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    Color? subtitleColor,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                  radius: 13,
                  backgroundColor: iconBgColor,
                  child: Icon(icon, color: iconColor, size: 15)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor)),
          ],
        ],
      ),
    );
  }
}
