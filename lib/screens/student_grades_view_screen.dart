import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../utils/role_theme.dart';

class StudentGradesViewScreen extends StatefulWidget {
  final String username;
  const StudentGradesViewScreen({super.key, required this.username});

  @override
  State<StudentGradesViewScreen> createState() => _StudentGradesViewScreenState();
}

class _StudentGradesViewScreenState extends State<StudentGradesViewScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _scores = [];
  List<Map<String, dynamic>> _remarks = [];
  String? _selectedSchoolYear;
  List<String> _schoolYears = [];

  final theme = RoleTheme.studentTheme;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    final db = DatabaseHelper();

    final years = await db.getAllSchoolYears();
    final activeYear = await db.getActiveSchoolYear();
    if (_selectedSchoolYear == null) {
      _selectedSchoolYear = activeYear;
    }

    final scores = await db.getStudentAllScores(widget.username, _selectedSchoolYear);
    final remarks = await db.getStudentAllRemarksByEmail(widget.username);

    if (mounted) {
      setState(() {
        _schoolYears = years.isNotEmpty ? years : [activeYear];
        _scores = scores;
        _remarks = remarks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primary),
      );
    }

    // Group scores by subject_code
    final Map<String, List<Map<String, dynamic>>> groupedScores = {};
    for (var score in _scores) {
      final subjectCode = score['subject_code'] ?? 'Unknown Subject';
      groupedScores.putIfAbsent(subjectCode, () => []).add(score);
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () => _loadScores(isRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Filter Row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: theme.cardGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Academic Grades',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Detailed score breakdown & teacher feedback',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_schoolYears.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSchoolYear,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.primary),
                        style: TextStyle(
                          color: theme.primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedSchoolYear) {
                            setState(() {
                              _selectedSchoolYear = newValue;
                              _loadScores();
                            });
                          }
                        },
                        items: _schoolYears.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(value),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Metric Summary Row
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                if (width < 600) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 175,
                          child: _buildMetricTile(
                            label: 'Enrolled Subjects',
                            value: groupedScores.length.toString(),
                            icon: Icons.auto_stories_rounded,
                            color: theme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 175,
                          child: _buildMetricTile(
                            label: 'Assessment Items',
                            value: _scores.length.toString(),
                            icon: Icons.checklist_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 175,
                          child: _buildMetricTile(
                            label: 'Teacher Notes',
                            value: _remarks.length.toString(),
                            icon: Icons.comment_outlined,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Enrolled Subjects',
                        value: groupedScores.length.toString(),
                        icon: Icons.auto_stories_rounded,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Assessment Items',
                        value: _scores.length.toString(),
                        icon: Icons.checklist_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Teacher Notes',
                        value: _remarks.length.toString(),
                        icon: Icons.comment_outlined,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),

            // Content List
            if (groupedScores.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.assignment_outlined, size: 40, color: theme.primary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No grades recorded yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scores for the selected academic term will appear here once published by your instructors.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...groupedScores.keys.map(
                (subjectCode) => _buildSubjectScores(subjectCode, groupedScores[subjectCode]!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectScores(String subjectCode, List<Map<String, dynamic>> subjectScores) {
    final subjectName = subjectScores.isNotEmpty ? (subjectScores.first['subject_name'] ?? '') : '';
    final subjectRemarks = _remarks.where((r) => r['subject_code'] == subjectCode).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subjectCode,
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            subjectName.isNotEmpty ? subjectName : subjectCode,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            '${subjectScores.length} assessment ${subjectScores.length == 1 ? 'item' : 'items'} • ${subjectRemarks.length} feedback',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ...subjectScores.map((score) {
              final category = score['category'] ?? '';
              final itemLabel = score['item_label'] ?? '';
              final points = score['score']?.toString() ?? '0';
              final total = score['total_score']?.toString() ?? '0';
              final period = score['grading_period'] ?? '';

              final ptsNum = double.tryParse(points) ?? 0;
              final totNum = double.tryParse(total) ?? 0;
              final pct = totNum > 0 ? (ptsNum / totNum) * 100 : 0.0;
              final isPassing = pct >= 75.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        period,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$category: $itemLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Score percentage: ${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: isPassing ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPassing
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPassing
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$points / $total',
                        style: TextStyle(
                          color: isPassing ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            ...subjectRemarks.map((r) {
              return Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote_rounded, color: Color(0xFF16A34A), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teacher Feedback (${r['grading_period'] ?? 'General'})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['remark'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
