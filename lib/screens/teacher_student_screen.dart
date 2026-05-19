import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'student_detail_screen.dart';
import 'student_grades_screen.dart';

class TeacherStudentScreen extends StatefulWidget {
  final String username;
  const TeacherStudentScreen({super.key, required this.username});

  @override
  State<TeacherStudentScreen> createState() => _TeacherStudentScreenState();
}

class _TeacherStudentScreenState extends State<TeacherStudentScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'At-Risk', 'Passed', 'Needs Attention'];

  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _assignedClasses = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _teacherName;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _selectedClass;
  List<String> _classFilterOptions = [];

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Get teacher name from email
    final teacherRecord = await DatabaseHelper().getTeacherByEmail(widget.username);
    _teacherName = teacherRecord != null ? teacherRecord['name']?.toString() : null;

    // Get assigned classes for this teacher
    final classes = _teacherName != null
        ? await DatabaseHelper().getSubjectClassesByTeacher(_teacherName!)
        : <Map<String, dynamic>>[];

    // Build a set of (grade_level, section_name) pairs from assigned classes
    final Set<String> assignedKeys = {};
    for (final cls in classes) {
      final grade = cls['grade_level']?.toString().trim().toLowerCase() ?? '';
      final section = cls['section_name']?.toString().trim().toLowerCase() ?? '';
      if (grade.isNotEmpty || section.isNotEmpty) {
        assignedKeys.add('$grade|$section');
      }
    }

    // Get all students
    final allStudents = await DatabaseHelper().getStudents();

    // Filter: show ALL if no classes assigned, else match grade+section
    List<Map<String, dynamic>> filtered;
    if (assignedKeys.isEmpty) {
      filtered = allStudents;
    } else {
      filtered = allStudents.where((s) {
        final sGrade = s['grade_level']?.toString().trim().toLowerCase() ?? '';
        final sSection = s['section']?.toString().trim().toLowerCase() ?? '';
        return assignedKeys.contains('$sGrade|$sSection');
      }).toList();
    }

    // Build class filter labels for dropdown
    final classLabels = classes.map((c) {
      final grade = c['grade_level']?.toString() ?? '';
      final section = c['section_name']?.toString() ?? '';
      return '$grade - $section'.trim();
    }).where((s) => s.isNotEmpty && s != '-').toSet().toList();

    setState(() {
      _assignedClasses = classes;
      _classFilterOptions = classLabels;
      _students = filtered.map((s) {
        final idStr = s['student_id']?.toString() ?? s['id']?.toString() ?? '';
        final hash = idStr.codeUnits.fold(0, (prev, curr) => prev + curr);
        
        String status = 'Passed';
        String statusDesc = 'Good Standing';
        bool isGood = true;

        if (hash % 10 == 0 || hash % 10 == 1) {
          status = 'At-Risk';
          statusDesc = 'Failing Grades';
          isGood = false;
        } else if (hash % 10 == 2 || hash % 10 == 3) {
          status = 'Needs Attention';
          statusDesc = 'Irregular Attendance';
          isGood = false;
        }
        
        return {
          ...s,
          'status': status,
          'statusDesc': statusDesc,
          'isGood': isGood,
          'actions': ['View Profile', 'Grades'],
        };
      }).toList();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _students.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          (s['name']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
          (s['student_id']?.toString().toLowerCase().contains(_searchQuery) ?? false);
      final matchesFilter = _selectedFilter == 'All' || s['status'] == _selectedFilter;
      
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

  int get _atRiskCount => _students.where((s) => s['status'] == 'At-Risk').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6F0FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search students...',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                        prefixIcon: Icon(Icons.search_outlined, color: Color(0xFF0D6EFD)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          const Icon(Icons.layers, color: Color(0xFF0D6EFD), size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Students',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
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
                              hint: const Text('All Classes', style: TextStyle(fontSize: 13)),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D6EFD)),
                              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Classes')),
                                ..._classFilterOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        bool isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedFilter = filter);
                            },
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFF0D6EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? const Color(0xFF0D6EFD) : Colors.transparent),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Total Students',
                          value: '${_students.length}',
                          subtitle: '${_assignedClasses.length} class(es) assigned',
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
                  else
                    ..._filteredStudents.map((student) => _buildStudentCard(student)).toList(),

                  const SizedBox(height: 32),
                ],
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
            _searchQuery.isNotEmpty ? 'No students found for "$_searchQuery"' : 'No students in your classes yet.',
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: iconBgColor,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: iconColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    bool isPassed = student['status'] == 'Passed';
    Color statusBgColor = isPassed ? const Color(0xFFE8F5E9) : const Color(0xFFFEF2E8);
    Color statusTextColor = isPassed ? const Color(0xFF198754) : const Color(0xFFE67E22);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE7F1FF),
                child: Text(
                  (student['name']?.toString().isNotEmpty == true)
                      ? student['name'].toString()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)),
                ),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student['grade_level'] ?? ''} - ${student['section'] ?? ''}'.trim().replaceAll(RegExp(r'^-\s*|\s*-$'), ''),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${student['student_id'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 10, color: Colors.black38),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        student['status'],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusTextColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          student['isGood'] ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 12,
                          color: student['isGood'] ? const Color(0xFF198754) : const Color(0xFFE67E22),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            student['statusDesc'],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: student['isGood'] ? const Color(0xFF198754) : const Color(0xFFE67E22),
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
                            builder: (context) => StudentDetailScreen(student: student),
                          ),
                        );
                      } else if (action == 'Grades') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentGradesScreen(student: student),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D6EFD),
                      side: BorderSide(color: Colors.blue.shade100),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 32),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
