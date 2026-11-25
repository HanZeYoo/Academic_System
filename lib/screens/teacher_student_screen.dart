import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';
import '../models/ecr_transmutation_model.dart';
import 'student_detail_screen.dart';
import 'student_grades_screen.dart';
import '../utils/avatar_utils.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/skeleton_loader.dart';

class TeacherStudentScreen extends StatefulWidget {
  final String username;
  final String? initialClass;
  final bool showAppBar;
  const TeacherStudentScreen({super.key, required this.username, this.initialClass, this.showAppBar = false});

  @override
  State<TeacherStudentScreen> createState() => _TeacherStudentScreenState();
}

class _TeacherStudentScreenState extends State<TeacherStudentScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'At-Risk',
    'Passed',
    'Needs Attention',
    'No Data',
  ];

  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _assignedClasses = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _teacherName;
  int _currentPage = 1;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _selectedClass;
  List<String> _classFilterOptions = [];

  Future<void> _loadData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }

    final db = DatabaseHelper();

    // Get teacher name from email
    final teacherRecord = await db.getTeacherByEmail(widget.username);
    _teacherName = teacherRecord != null ? teacherRecord['name']?.toString() : null;

    // Get assigned classes for this teacher
    final classes = _teacherName != null
        ? await db.getSubjectClassesByTeacher(_teacherName!)
        : <Map<String, dynamic>>[];

    // Build a set of (grade_level, section_name) pairs and raw filter lists
    final Set<String> assignedKeys = {};
    final Set<String> uniqueGrades = {};
    final Set<String> uniqueSections = {};
    final Map<String, ({String subjectCode, String grade, String section})> uniqueAttendanceKeys = {};

    for (final cls in classes) {
      final subjectCode = cls['subject_code']?.toString() ?? '';
      final rawGrade = cls['grade_level']?.toString() ?? '';
      final rawSection = cls['section_name']?.toString() ?? '';
      final gradeLower = rawGrade.trim().toLowerCase();
      final sectionLower = rawSection.trim().toLowerCase();
      if (gradeLower.isNotEmpty || sectionLower.isNotEmpty) {
        assignedKeys.add('$gradeLower|$sectionLower');
      }
      if (rawGrade.isNotEmpty) uniqueGrades.add(rawGrade);
      if (rawSection.isNotEmpty) uniqueSections.add(rawSection);
      if (subjectCode.isNotEmpty && rawGrade.isNotEmpty && rawSection.isNotEmpty) {
        uniqueAttendanceKeys.putIfAbsent(
          '$subjectCode - $rawGrade - $rawSection',
          () => (subjectCode: subjectCode, grade: rawGrade, section: rawSection),
        );
      }
    }

    // Build class filter labels for dropdown
    final classLabels = classes
        .map((c) {
          final grade = c['grade_level']?.toString() ?? '';
          final section = c['section_name']?.toString() ?? '';
          return '$grade - $section'.trim();
        })
        .where((s) => s.isNotEmpty && s != '-')
        .toSet()
        .toList();

    if (!mounted) return;
    setState(() {
      _assignedClasses = classes;
      _classFilterOptions = classLabels;
      if (widget.initialClass != null && classLabels.contains(widget.initialClass)) {
        _selectedClass = widget.initialClass;
      }
    });

    if (assignedKeys.isEmpty) {
      if (!mounted) return;
      setState(() {
        _students = [];
        _isLoading = false;
      });
      return;
    }

    const String period = '1st Term';

    // Fetch filtered students, per-class metadata/scores, and per-section attendance concurrently
    final Future<List<Map<String, dynamic>>> studentsFuture = () async {
      if (uniqueGrades.isNotEmpty && uniqueSections.isNotEmpty) {
        try {
          final res = await Supabase.instance.client
              .from('students')
              .select()
              .eq('is_active', 1)
              .inFilter('grade_level', uniqueGrades.toList())
              .inFilter('section', uniqueSections.toList())
              .order('id', ascending: true);
          return List<Map<String, dynamic>>.from(res);
        } catch (_) {}
      }
      return db.getStudents();
    }();

    final classBundleFutures = classes.map((c) async {
      final subjectCode = c['subject_code'].toString();
      final section = c['section_name'].toString();
      final gradeLevel = c['grade_level'].toString();

      final res = await Future.wait([
        db.getAssessmentSetup(
          subjectCode: subjectCode,
          sectionName: section,
          gradeLevel: gradeLevel,
          gradingPeriod: period,
        ),
        db.getTransmutationTable(subjectCode, section),
        db.getScoresForClass(
          subjectCode: subjectCode,
          sectionName: section,
          gradeLevel: gradeLevel,
          gradingPeriod: period,
          filterBySetup: false,
        ),
      ]);

      final classScores = res[2] as List<Map<String, dynamic>>;
      final Map<String, List<Map<String, dynamic>>> scoresByStudent = {};
      for (final row in classScores) {
        final sid = row['student_id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          scoresByStudent.putIfAbsent(sid, () => []).add(row);
        }
      }

      return {
        'subjectCode': subjectCode,
        'gradeLevel': gradeLevel,
        'section': section,
        'setup': res[0] as Map<String, dynamic>?,
        'transTable': res[1] as EcrTransmutationTable?,
        'scoresByStudent': scoresByStudent,
      };
    });

    final attendanceFutures = uniqueAttendanceKeys.keys.map((className) async {
      final records = await db.getAttendanceForClass(className);
      final uniqueDates = records.map((r) => r['date'].toString()).toSet();
      final totalClassDays = uniqueDates.length;
      final Map<String, double> pctByStudent = {};
      if (totalClassDays > 0) {
        final Map<String, double> pointsByStudent = {};
        for (final record in records) {
          final sid = record['student_id']?.toString() ?? '';
          if (sid.isEmpty) continue;
          final status = record['status']?.toString() ?? '';
          double pts = 0.0;
          if (status == 'Present' || status == 'Excused') {
            pts = 1.0;
          } else if (status == 'Late') {
            pts = 0.5;
          }
          if (pts > 0) {
            pointsByStudent[sid] = (pointsByStudent[sid] ?? 0.0) + pts;
          }
        }
        pointsByStudent.forEach((sid, pts) {
          pctByStudent[sid] = (pts / totalClassDays) * 100;
        });
      }
      return MapEntry(className, pctByStudent);
    });

    final parallelResults = await Future.wait([
      studentsFuture,
      Future.wait(classBundleFutures),
      Future.wait(attendanceFutures),
    ]);

    if (!mounted) return;

    final fetchedStudents = parallelResults[0] as List<Map<String, dynamic>>;
    final classBundles = parallelResults[1] as List<Map<String, dynamic>>;
    final attendanceByClass = Map<String, Map<String, double>>.fromEntries(
      parallelResults[2] as List<MapEntry<String, Map<String, double>>>,
    );

    final filtered = fetchedStudents.where((s) {
      final sGrade = s['grade_level']?.toString().trim().toLowerCase() ?? '';
      final sSection = s['section']?.toString().trim().toLowerCase() ?? '';
      return assignedKeys.contains('$sGrade|$sSection');
    }).toList();

    // Index class bundles by exact grade|section to evaluate each student in O(classes_for_section)
    final Map<String, List<Map<String, dynamic>>> bundlesBySection = {};
    for (final bundle in classBundles) {
      final key = '${bundle['gradeLevel']}|${bundle['section']}';
      bundlesBySection.putIfAbsent(key, () => []).add(bundle);
    }

    final List<Map<String, dynamic>> studentsWithStats = [];

    for (final s in filtered) {
      final studentId = s['student_id']?.toString() ?? '';
      final gradeLevel = s['grade_level']?.toString() ?? '';
      final section = s['section']?.toString() ?? '';
      final matchingBundles = bundlesBySection['$gradeLevel|$section'] ?? const [];
      double attSum = 0.0;
      int attCount = 0;
      for (final b in matchingBundles) {
        final sCode = b['subjectCode']?.toString() ?? '';
        final classMap = attendanceByClass['$sCode - $gradeLevel - $section'];
        if (classMap != null && classMap.containsKey(studentId)) {
          attSum += classMap[studentId]!;
          attCount++;
        }
      }
      final attPct = attCount > 0 ? (attSum / attCount) : 0.0;

      double lowestGrade = 100;
      bool hasFailing = false;
      bool hasData = false;

      for (final bundle in matchingBundles) {
        final scoresByStudent =
            bundle['scoresByStudent'] as Map<String, List<Map<String, dynamic>>>;
        final scores = scoresByStudent[studentId] ?? const [];
        if (scores.isNotEmpty) {
          hasData = true;
          final setup = bundle['setup'] as Map<String, dynamic>?;
          final transTable = bundle['transTable'] as EcrTransmutationTable?;
          final grade = _computeGrade(
            studentId,
            scores,
            setup,
            attPct,
            customTable: transTable,
          );
          if (grade > 0) {
            if (grade < lowestGrade) lowestGrade = grade;
            if (grade < 75) hasFailing = true;
          }
        }
      }

      String status = 'Low Risk';
      String statusDesc = 'Good Standing';
      bool isGood = true;

      if (!hasData) {
        status = 'No Data';
        statusDesc = 'No scores recorded';
      } else if (hasFailing) {
        status = 'High Risk';
        statusDesc = 'Failing in one or more subjects';
        isGood = false;
      } else if (lowestGrade < 80) {
        status = 'Medium Risk';
        statusDesc = 'Borderline grades';
        isGood = false;
      }

      studentsWithStats.add({
        ...s,
        'status': status,
        'statusDesc': statusDesc,
        'isGood': isGood,
        'actions': ['View Profile', 'Grades'],
      });
    }

    if (!mounted) return;
    setState(() {
      _students = studentsWithStats;
      _isLoading = false;
    });
  }

  double _computeGrade(
    String studentId,
    List<Map<String, dynamic>> allScores,
    Map<String, dynamic>? setup,
    double attendancePct, {
    EcrTransmutationTable? customTable,
  }) {
    if (setup != null) {
      final wWW = (setup['ww_weight'] as num?)?.toDouble() ?? 30;
      final wPT = (setup['pt_weight'] as num?)?.toDouble() ?? 50;
      final wTE = (setup['te_weight'] as num?)?.toDouble() ?? 20;
      final wAttendance = (setup['attendance_weight'] as num?)?.toDouble() ?? 0;

      final wwAvg = _categoryAvg(studentId, 'Written Works', allScores, setup);
      final ptAvg = _categoryAvg(studentId, 'Performance Tasks', allScores, setup);
      final teAvg = _categoryAvg(studentId, 'Term Exams', allScores, setup);

      if (wwAvg == 0 && ptAvg == 0 && teAvg == 0) {
        if (allScores
            .where((r) => r['student_id'].toString() == studentId)
            .isEmpty)
          return 0.0;
      }

      double totalWeight = 0;
      double earned = 0;
      
      bool hasWW = allScores.any((r) => r['student_id'].toString() == studentId && r['category'].toString().toLowerCase() == 'written works');
      bool hasPT = allScores.any((r) => r['student_id'].toString() == studentId && r['category'].toString().toLowerCase() == 'performance tasks');
      bool hasTE = allScores.any((r) => r['student_id'].toString() == studentId && r['category'].toString().toLowerCase() == 'term exams');

      if (hasWW) { earned += wwAvg * (wWW / 100); totalWeight += (wWW / 100); }
      if (hasPT) { earned += ptAvg * (wPT / 100); totalWeight += (wPT / 100); }
      if (hasTE) { earned += teAvg * (wTE / 100); totalWeight += (wTE / 100); }
      
      if (wAttendance > 0) {
        earned += attendancePct * (wAttendance / 100);
        totalWeight += (wAttendance / 100);
      }

      if (totalWeight == 0) return 0.0;
      final initialGrade = earned / totalWeight;
      return DatabaseHelper().transmuteGrade(initialGrade, customTable: customTable);
    }

    if (allScores.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in allScores) {
      if (r['student_id'].toString() == studentId) {
        total += (r['score'] as num?)?.toDouble() ?? 0;
        max += (r['total_score'] as num?)?.toDouble() ?? 0;
      }
    }
    if (max == 0) return 0.0;
    final initialGrade = (total / max) * 100;
    return DatabaseHelper().transmuteGrade(initialGrade, customTable: customTable);
  }

  double _categoryAvg(
    String studentId,
    String category,
    List<Map<String, dynamic>> allScores,
    Map<String, dynamic>? setup,
  ) {
    int maxItems = 999;
    if (setup != null) {
      if (category.toLowerCase() == 'written works') maxItems = (setup['written_works'] as num?)?.toInt() ?? 999;
      else if (category.toLowerCase() == 'performance tasks') maxItems = (setup['performance_tasks'] as num?)?.toInt() ?? 999;
      else if (category.toLowerCase() == 'term exams') maxItems = (setup['term_exams'] as num?)?.toInt() ?? 999;
    }

    final s = allScores.where((r) {
      if (r['student_id'].toString() != studentId) return false;
      if (r['category'].toString().toLowerCase() != category.toLowerCase()) return false;
      
      final itemLabel = r['item_label'].toString();
      final parts = itemLabel.split(' ');
      if (parts.length > 1) {
        final itemNum = int.tryParse(parts.last);
        if (itemNum != null && itemNum > maxItems) return false;
      }
      return true;
    }).toList();

    if (s.isEmpty) return 0.0;
    double total = 0, max = 0;
    for (final r in s) {
      total += (r['score'] as num?)?.toDouble() ?? 0;
      max += (r['total_score'] as num?)?.toDouble() ?? 0;
    }
    if (max == 0) return 0.0;
    return (total / max) * 100;
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _students.where((s) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          (s['name']?.toString().toLowerCase().contains(_searchQuery) ??
              false) ||
          (s['student_id']?.toString().toLowerCase().contains(_searchQuery) ??
              false);
      final matchesFilter =
          _selectedFilter == 'All' || s['status'] == _selectedFilter;

      bool matchesClass = true;
      if (_selectedClass != null) {
        final sGrade = s['grade_level']?.toString() ?? '';
        final sSection = s['section']?.toString() ?? '';
        final sClassLabel = '$sGrade - $sSection'.trim();
        matchesClass = sClassLabel == _selectedClass;
      }

      return matchesSearch && matchesFilter && matchesClass;
    }).toList();
  }

  int get _atRiskCount =>
      _students.where((s) => s['status'] == 'At-Risk').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6F0FA),
      appBar: widget.showAppBar ? AppBar(
        title: Text(_selectedClass ?? 'Class Students'),
        backgroundColor: const Color(0xFF3383B3),
        foregroundColor: Colors.white,
        elevation: 0,
      ) : null,
      body: _isLoading
          ? SkeletonPresets.cardList(itemCount: 6, showHeader: true)
          : RefreshIndicator(
              onRefresh: () => _loadData(isRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search students...',
                        hintStyle: TextStyle(
                          color: Colors.black38,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_outlined,
                          color: Color(0xFF0D6EFD),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.layers,
                            color: Color(0xFF0D6EFD),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Students',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (_classFilterOptions.isNotEmpty)
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedClass,
                              hint: const Text(
                                'All Classes',
                                style: TextStyle(fontSize: 13),
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF0D6EFD),
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Classes'),
                                ),
                                ..._classFilterOptions.map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedClass = val;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _filters.map((filter) {
                      bool isSelected = _selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                          }
                        },
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFF0D6EFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF0D6EFD)
                                : Colors.transparent,
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Total Students',
                          value: '${_students.length}',
                          subtitle:
                              '${_assignedClasses.length} class(es) assigned',
                          subtitleColor: const Color(0xFF198754),
                          icon: Icons.people,
                          iconBgColor: const Color(0xFFE7F1FF),
                          iconColor: const Color(0xFF0D6EFD),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'At-Risk Students',
                          value: '$_atRiskCount',
                          subtitle: 'Needs attention',
                          subtitleColor: const Color(0xFFE67E22),
                          icon: Icons.warning_amber_rounded,
                          iconBgColor: const Color(0xFFFEF2E8),
                          iconColor: const Color(0xFFE67E22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Student List or Empty State
                  if (_filteredStudents.isEmpty)
                    _buildEmptyState()
                  else ...[
                    ...paginateList(_filteredStudents, _currentPage, _pageSize)
                        .map((student) => _buildStudentCard(student)),
                    PaginationControls(
                      currentPage: clampPage(_currentPage, _filteredStudents.length, _pageSize),
                      totalItems: _filteredStudents.length,
                      pageSize: _pageSize,
                      accentColor: const Color(0xFF0D6EFD),
                      onPageChanged: (page) => setState(() => _currentPage = page),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No students found for "$_searchQuery"'
                : 'No students in your classes yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: iconBgColor,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    bool isPassed = student['status'] == 'Low Risk';
    bool isNoData = student['status'] == 'No Data';

    Color statusBgColor = isPassed
        ? const Color(0xFFE8F5E9)
        : (isNoData ? Colors.grey.shade100 : const Color(0xFFFEF2E8));
    Color statusTextColor = isPassed
        ? const Color(0xFF198754)
        : (isNoData ? Colors.grey.shade600 : const Color(0xFFE74C3C));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              AvatarUtils.buildAvatar(
                photo: student['profile_picture']?.toString(),
                name: student['name']?.toString(),
                radius: 28,
                backgroundColor: const Color(0xFFE7F1FF),
                foregroundColor: const Color(0xFF0D6EFD),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student['grade_level'] ?? ''} - ${student['section'] ?? ''}'
                          .trim()
                          .replaceAll(RegExp(r'^-\s*|\s*-$'), ''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LRN: ${student['student_id'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),

              // Status
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        student['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          student['isGood']
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 12,
                          color: student['isGood']
                              ? const Color(0xFF198754)
                              : const Color(0xFFE67E22),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            student['statusDesc'],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: student['isGood']
                                  ? const Color(0xFF198754)
                                  : const Color(0xFFE67E22),
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: (student['actions'] as List<String>).map((action) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: OutlinedButton(
                    onPressed: () {
                      if (action == 'View Profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                StudentDetailScreen(student: student),
                          ),
                        );
                      } else if (action == 'Grades') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                StudentGradesScreen(student: student),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D6EFD),
                      side: BorderSide(color: Colors.blue.shade100),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

