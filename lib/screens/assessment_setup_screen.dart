import 'dart:convert';
import 'package:flutter/material.dart';
import '../database_helper.dart';

class AssessmentSetupScreen extends StatefulWidget {
  final String username;
  const AssessmentSetupScreen({super.key, required this.username});

  @override
  State<AssessmentSetupScreen> createState() => _AssessmentSetupScreenState();
}

class _AssessmentSetupScreenState extends State<AssessmentSetupScreen> {
  // â”€â”€â”€ Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _isLoading = true;
  bool _isSaving = false;

  // â”€â”€â”€ Teacher / Classes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String? _teacherName;
  List<Map<String, dynamic>> _assignedClasses = [];
  Map<String, dynamic>? _selectedClassRecord;
  String _selectedPeriod = '1st Term';

  // â”€â”€â”€ Component counts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<String> _wwLabels = [];
  List<String> _ptLabels = [];
  List<String> _teLabels = [];

  // â”€â”€â”€ Weight controllers (persistent, no rebuild flicker) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final TextEditingController _wwWeightCtrl = TextEditingController(text: '30');
  final TextEditingController _ptWeightCtrl = TextEditingController(text: '50');
  final TextEditingController _teWeightCtrl = TextEditingController(text: '20');
  final TextEditingController _attendanceWeightCtrl = TextEditingController(text: '0');

  int get _wwWeight => int.tryParse(_wwWeightCtrl.text) ?? 0;
  int get _ptWeight => int.tryParse(_ptWeightCtrl.text) ?? 0;
  int get _teWeight => int.tryParse(_teWeightCtrl.text) ?? 0;
  int get _attendanceWeight => int.tryParse(_attendanceWeightCtrl.text) ?? 0;
  
  int get _totalWeight =>
      _wwWeight + _ptWeight + _teWeight + _attendanceWeight;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _wwWeightCtrl,
      _ptWeightCtrl,
      _teWeightCtrl,
      _attendanceWeightCtrl
    ]) {
      c.addListener(() => setState(() {}));
    }
    _loadClasses();
  }

  @override
  void dispose() {
    for (final c in [
      _wwWeightCtrl,
      _ptWeightCtrl,
      _teWeightCtrl,
      _attendanceWeightCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // â”€â”€â”€ Load teacher classes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Load saved setup for current selection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadSetup() async {
    if (_selectedClassRecord == null) return;

    final saved = await DatabaseHelper().getAssessmentSetup(
      subjectCode: _selectedClassRecord!['subject_code']?.toString() ?? '',
      sectionName: _selectedClassRecord!['section_name']?.toString() ?? '',
      gradeLevel: _selectedClassRecord!['grade_level']?.toString() ?? '',
      gradingPeriod: _selectedPeriod,
    );

    if (saved != null) {
      List<String> parseList(dynamic data) {
        if (data == null) return [];
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is List) return decoded.map((e) => e.toString()).toList();
          } catch (_) {}
        } else if (data is List) {
          return data.map((e) => e.toString()).toList();
        }
        return [];
      }

      setState(() {
        _wwLabels = parseList(saved['ww_labels']);
        _ptLabels = parseList(saved['pt_labels']);
        _teLabels = parseList(saved['te_labels']);

        _wwWeightCtrl.text = '${(saved['ww_weight'] as int?) ?? 30}';
        _ptWeightCtrl.text = '${(saved['pt_weight'] as int?) ?? 50}';
        _teWeightCtrl.text = '${(saved['te_weight'] as int?) ?? 20}';
        _attendanceWeightCtrl.text = '${(saved['attendance_weight'] as int?) ?? 0}';
      });
    } else {
      // Defaults
      setState(() {
        _wwLabels = [];
        _ptLabels = [];
        _teLabels = [];
        _wwWeightCtrl.text = '30';
        _ptWeightCtrl.text = '50';
        _teWeightCtrl.text = '20';
        _attendanceWeightCtrl.text = '0';
      });
    }
  }

  // â”€â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      'ww_items': _wwLabels.length,
      'pt_items': _ptLabels.length,
      'te_items': _teLabels.length,
      'ww_labels': jsonEncode(_wwLabels),
      'pt_labels': jsonEncode(_ptLabels),
      'te_labels': jsonEncode(_teLabels),
      'ww_weight': _wwWeight,
      'pt_weight': _ptWeight,
      'te_weight': _teWeight,
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

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get _classLabel {
    if (_selectedClassRecord == null) return 'No class';
    return '${_selectedClassRecord!['subject_name']} â€“ '
        '${_selectedClassRecord!['grade_level']} '
        '${_selectedClassRecord!['section_name']}';
  }

  // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                      // â”€â”€ Dropdowns â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownCard(
                              label: 'Class',
                              value: _classLabel,
                              items: _assignedClasses
                                  .map((c) =>
                                      '${c['subject_name']} â€“ ${c['grade_level']} ${c['section_name']}')
                                  .toList(),
                              onChanged: (val) async {
                                final found = _assignedClasses.firstWhere(
                                  (c) =>
                                      '${c['subject_name']} â€“ ${c['grade_level']} ${c['section_name']}' ==
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
                                '1st Term',
                                '2nd Term',
                                '3rd Term'
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

                      // â”€â”€ Grade Components Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                                'Written Works',
                                Icons.assignment_outlined,
                                const Color(0xFF0D6EFD),
                                _wwLabels,
                                _wwWeightCtrl),
                            _divider(),
                            _buildComponentRow(
                                'Performance Tasks',
                                Icons.groups_outlined,
                                const Color(0xFF198754),
                                _ptLabels,
                                _ptWeightCtrl),
                            _divider(),
                            _buildComponentRow(
                                'Term Exams',
                                Icons.school_outlined,
                                const Color(0xFFDC3545),
                                _teLabels,
                                _teWeightCtrl),
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

                      // â”€â”€ Generated Items Preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                            if (_wwLabels.isNotEmpty)
                              _buildGeneratedRow('Written Works',
                                  Icons.assignment_outlined,
                                  const Color(0xFF0D6EFD), _wwLabels),
                            if (_ptLabels.isNotEmpty)
                              _buildGeneratedRow('Performance Tasks', Icons.groups_outlined,
                                  const Color(0xFF198754), _ptLabels),
                            if (_teLabels.isNotEmpty)
                              _buildGeneratedRow('Term Exams', Icons.school_outlined,
                                  const Color(0xFFDC3545), _teLabels),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // â”€â”€ Info bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                      // â”€â”€ Buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                                  _isSaving ? 'Savingâ€¦' : 'Save Setup',
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

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  Future<void> _showAddLabelModal(String title, List<String> labels) async {
    final TextEditingController _labelCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add $title Label', style: const TextStyle(fontSize: 16)),
          content: TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. Quiz 1, Long Test',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_labelCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    labels.add(_labelCtrl.text.trim());
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComponentRow(
    String title,
    IconData icon,
    Color color,
    List<String> labels,
    TextEditingController weightCtrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Label
            Expanded(
              flex: 5,
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
            // Add Button
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => _showAddLabelModal(title, labels),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  alignment: Alignment.center,
                  child: const Text('+ Add', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
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
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Text('%',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (labels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10.0, left: 35.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: labels.asMap().entries.map((entry) {
                int idx = entry.key;
                String label = entry.value;
                return InputChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  backgroundColor: color.withOpacity(0.05),
                  deleteIconColor: Colors.black45,
                  onDeleted: () {
                    setState(() {
                      labels.removeAt(idx);
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildGeneratedRow(
      String title, IconData icon, Color color, List<String> labels) {
    if (labels.isEmpty) return const SizedBox.shrink();
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
              children: labels
                  .map((label) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
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



