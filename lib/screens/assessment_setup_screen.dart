import 'package:flutter/material.dart';
import '../database_helper.dart';

class AssessmentSetupScreen extends StatefulWidget {
  final String username;
  const AssessmentSetupScreen({super.key, required this.username});

  @override
  State<AssessmentSetupScreen> createState() => _AssessmentSetupScreenState();
}

class _AssessmentSetupScreenState extends State<AssessmentSetupScreen> {
  // ─── Loading ───────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isSaving = false;

  // ─── Teacher / Classes ─────────────────────────────────────────────────────
  String? _teacherName;
  List<Map<String, dynamic>> _assignedClasses = [];
  Map<String, dynamic>? _selectedClassRecord;
  String _selectedPeriod = '1st Quarter';

  // ─── Component counts ──────────────────────────────────────────────────────
  int _quizzes = 3;
  int _assignments = 2;
  int _activities = 3;
  int _projects = 1;
  int _exams = 1;

  // ─── Weight controllers (persistent, no rebuild flicker) ──────────────────
  final TextEditingController _quizWeightCtrl =
      TextEditingController(text: '20');
  final TextEditingController _assignWeightCtrl =
      TextEditingController(text: '15');
  final TextEditingController _actWeightCtrl =
      TextEditingController(text: '20');
  final TextEditingController _projWeightCtrl =
      TextEditingController(text: '15');
  final TextEditingController _examWeightCtrl =
      TextEditingController(text: '30');
  final TextEditingController _attendanceWeightCtrl =
      TextEditingController(text: '0');

  int get _quizWeight => int.tryParse(_quizWeightCtrl.text) ?? 0;
  int get _assignWeight => int.tryParse(_assignWeightCtrl.text) ?? 0;
  int get _actWeight => int.tryParse(_actWeightCtrl.text) ?? 0;
  int get _projWeight => int.tryParse(_projWeightCtrl.text) ?? 0;
  int get _examWeight => int.tryParse(_examWeightCtrl.text) ?? 0;
  int get _attendanceWeight => int.tryParse(_attendanceWeightCtrl.text) ?? 0;
  int get _totalWeight =>
      _quizWeight + _assignWeight + _actWeight + _projWeight + _examWeight + _attendanceWeight;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _quizWeightCtrl,
      _assignWeightCtrl,
      _actWeightCtrl,
      _projWeightCtrl,
      _examWeightCtrl,
      _attendanceWeightCtrl
    ]) {
      c.addListener(() => setState(() {}));
    }
    _loadClasses();
  }

  @override
  void dispose() {
    for (final c in [
      _quizWeightCtrl,
      _assignWeightCtrl,
      _actWeightCtrl,
      _projWeightCtrl,
      _examWeightCtrl,
      _attendanceWeightCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Load teacher classes ──────────────────────────────────────────────────
  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    final rec = await DatabaseHelper().getTeacherByEmail(widget.username);
    _teacherName = rec?['name']?.toString();

    List<Map<String, dynamic>> classes = [];
    if (_teacherName != null) {
      classes =
          await DatabaseHelper().getSubjectClassesByTeacher(_teacherName!);
    }

    setState(() {
      _assignedClasses = classes;
      _selectedClassRecord = classes.isNotEmpty ? classes.first : null;
    });

    await _loadSetup();
    setState(() => _isLoading = false);
  }

  // ─── Load saved setup for current selection ────────────────────────────────
  Future<void> _loadSetup() async {
    if (_selectedClassRecord == null) return;

    final saved = await DatabaseHelper().getAssessmentSetup(
      subjectCode: _selectedClassRecord!['subject_code']?.toString() ?? '',
      sectionName: _selectedClassRecord!['section_name']?.toString() ?? '',
      gradeLevel: _selectedClassRecord!['grade_level']?.toString() ?? '',
      gradingPeriod: _selectedPeriod,
    );

    if (saved != null) {
      setState(() {
        _quizzes = (saved['quizzes'] as int?) ?? 3;
        _assignments = (saved['assignments'] as int?) ?? 2;
        _activities = (saved['activities'] as int?) ?? 3;
        _projects = (saved['projects'] as int?) ?? 1;
        _exams = (saved['exams'] as int?) ?? 1;

        _quizWeightCtrl.text = '${(saved['quiz_weight'] as int?) ?? 20}';
        _assignWeightCtrl.text =
            '${(saved['assignment_weight'] as int?) ?? 15}';
        _actWeightCtrl.text = '${(saved['activity_weight'] as int?) ?? 20}';
        _projWeightCtrl.text = '${(saved['project_weight'] as int?) ?? 15}';
        _examWeightCtrl.text = '${(saved['exam_weight'] as int?) ?? 30}';
        _attendanceWeightCtrl.text = '${(saved['attendance_weight'] as int?) ?? 0}';
      });
    } else {
      // Defaults
      setState(() {
        _quizzes = 3;
        _assignments = 2;
        _activities = 3;
        _projects = 1;
        _exams = 1;
        _quizWeightCtrl.text = '20';
        _assignWeightCtrl.text = '15';
        _actWeightCtrl.text = '20';
        _projWeightCtrl.text = '15';
        _examWeightCtrl.text = '30';
        _attendanceWeightCtrl.text = '0';
      });
    }
  }

  // ─── Save ──────────────────────────────────────────────────────────────────
  Future<void> _saveSetup() async {
    if (_totalWeight != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total weight must be exactly 100% before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedClassRecord == null) return;

    setState(() => _isSaving = true);

    await DatabaseHelper().saveAssessmentSetup({
      'subject_code': _selectedClassRecord!['subject_code']?.toString() ?? '',
      'subject_name': _selectedClassRecord!['subject_name']?.toString() ?? '',
      'section_name': _selectedClassRecord!['section_name']?.toString() ?? '',
      'grade_level': _selectedClassRecord!['grade_level']?.toString() ?? '',
      'grading_period': _selectedPeriod,
      'teacher_name': _teacherName ?? '',
      'quizzes': _quizzes,
      'assignments': _assignments,
      'activities': _activities,
      'projects': _projects,
      'exams': _exams,
      'quiz_weight': _quizWeight,
      'assignment_weight': _assignWeight,
      'activity_weight': _actWeight,
      'project_weight': _projWeight,
      'exam_weight': _examWeight,
      'attendance_weight': _attendanceWeight,
      'created_at': DateTime.now().toIso8601String(),
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment setup saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String get _classLabel {
    if (_selectedClassRecord == null) return 'No class';
    return '${_selectedClassRecord!['subject_name']} – '
        '${_selectedClassRecord!['grade_level']} '
        '${_selectedClassRecord!['section_name']}';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final valid = _totalWeight == 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedClasses.isEmpty
              ? _buildNoClassState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ── Dropdowns ─────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownCard(
                              label: 'Class',
                              value: _classLabel,
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
                                setState(
                                    () => _selectedClassRecord = found);
                                await _loadSetup();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdownCard(
                              label: 'Grading Period',
                              value: _selectedPeriod,
                              items: const [
                                '1st Quarter',
                                '2nd Quarter',
                                '3rd Quarter',
                                '4th Quarter'
                              ],
                              onChanged: (val) async {
                                setState(() => _selectedPeriod = val!);
                                await _loadSetup();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Grade Components Card ─────────────────────────────
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              children: [
                                const Expanded(
                                  flex: 4,
                                  child: Text('Grade Components',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('No. of Items',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Weight',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            _buildComponentRow(
                                'Quizzes',
                                Icons.assignment_outlined,
                                const Color(0xFF0D6EFD),
                                _quizzes,
                                _quizWeightCtrl,
                                (v) => setState(() => _quizzes = v)),
                            _divider(),
                            _buildComponentRow(
                                'Assignments',
                                Icons.edit_note,
                                const Color(0xFF198754),
                                _assignments,
                                _assignWeightCtrl,
                                (v) => setState(() => _assignments = v)),
                            _divider(),
                            _buildComponentRow(
                                'Activities',
                                Icons.groups_outlined,
                                const Color(0xFF6F42C1),
                                _activities,
                                _actWeightCtrl,
                                (v) => setState(() => _activities = v)),
                            _divider(),
                            _buildComponentRow(
                                'Projects',
                                Icons.folder_outlined,
                                const Color(0xFFE67E22),
                                _projects,
                                _projWeightCtrl,
                                (v) => setState(() => _projects = v)),
                            _divider(),
                            _buildComponentRow(
                                'Exams',
                                Icons.school_outlined,
                                const Color(0xFFDC3545),
                                _exams,
                                _examWeightCtrl,
                                (v) => setState(() => _exams = v)),
                            _divider(),
                            _buildWeightOnlyRow(
                                'Attendance',
                                Icons.assignment_turned_in,
                                const Color(0xFF0DCAF0), // cyan
                                _attendanceWeightCtrl),

                            const SizedBox(height: 16),
                            const Divider(color: Colors.black12),
                            const SizedBox(height: 8),

                            // Total weight bar
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Weight',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                  '$_totalWeight%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: valid
                                        ? const Color(0xFF198754)
                                        : const Color(0xFFDC3545),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_totalWeight / 100).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    valid
                                        ? const Color(0xFF198754)
                                        : const Color(0xFFDC3545)),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    valid
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    size: 15,
                                    color: valid
                                        ? const Color(0xFF198754)
                                        : const Color(0xFFDC3545),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    valid
                                        ? 'Ready to save'
                                        : 'Must total exactly 100%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: valid
                                          ? const Color(0xFF198754)
                                          : const Color(0xFFDC3545),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Generated Items Preview ────────────────────────────
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Generated Assessment Items',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(height: 14),
                            if (_quizzes > 0)
                              _buildGeneratedRow('Quizzes',
                                  Icons.assignment_outlined,
                                  const Color(0xFF0D6EFD), _quizzes, 'Quiz'),
                            if (_assignments > 0)
                              _buildGeneratedRow('Assignments', Icons.edit_note,
                                  const Color(0xFF198754), _assignments,
                                  'Assignment'),
                            if (_activities > 0)
                              _buildGeneratedRow('Activities',
                                  Icons.groups_outlined,
                                  const Color(0xFF6F42C1), _activities,
                                  'Activity'),
                            if (_projects > 0)
                              _buildGeneratedRow('Projects',
                                  Icons.folder_outlined,
                                  const Color(0xFFE67E22), _projects,
                                  'Project'),
                            if (_exams > 0)
                              _buildGeneratedRow('Exams', Icons.school_outlined,
                                  const Color(0xFFDC3545), _exams, 'Exam'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Info bar ──────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F1FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xFF0D6EFD), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This setup controls item labels in Grade Encoding. Save per grading period.',
                                style: TextStyle(
                                    color: Colors.blue.shade800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Buttons ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _loadSetup(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0D6EFD),
                                side: const BorderSide(
                                    color: Color(0xFF0D6EFD)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Reset',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveSetup,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: Text(
                                  _isSaving ? 'Saving…' : 'Save Setup',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D6EFD),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildNoClassState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No classes assigned yet.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Ask the admin to assign a class to your account.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _divider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: Colors.black12));

  Widget _buildDropdownCard({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeVal = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeVal,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(
    String title,
    IconData icon,
    Color color,
    int count,
    TextEditingController weightCtrl,
    ValueChanged<int> onCountChanged,
  ) {
    return Row(
      children: [
        // Label
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        // Stepper
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    if (count > 0) onCountChanged(count - 1);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Icons.remove, size: 15, color: Colors.blue),
                  ),
                ),
                Text('$count',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                InkWell(
                  onTap: () {
                    if (count < 20) onCountChanged(count + 1);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Icons.add, size: 15, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Weight
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('%',
                      style:
                          TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedRow(
      String title, IconData icon, Color color, int count, String prefix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                count,
                (i) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$prefix ${i + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // ... not needed here, already have dropdowns ...
    return Container();
  }

  Widget _buildWeightOnlyRow(
    String title,
    IconData icon,
    Color color,
    TextEditingController weightCtrl,
  ) {
    return Row(
      children: [
        // Label
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        // Auto badge instead of stepper
        Expanded(
          flex: 3,
          child: Container(
            alignment: Alignment.center,
            child: const Text('Auto',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey)),
          ),
        ),
        // Weight input
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('%',
                      style:
                          TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

