import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../utils/dialog_utils.dart';

class EnrollmentManagementScreen extends StatefulWidget {
  const EnrollmentManagementScreen({super.key});

  @override
  State<EnrollmentManagementScreen> createState() => _EnrollmentManagementScreenState();
}

class _EnrollmentManagementScreenState extends State<EnrollmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _allStudents = [];

  final List<String> _tabs = ['All', 'Enrolled', 'Pending', 'Conditional', 'Transferred', 'Graduated'];
  final Map<String, String> _tabFilter = {
    'All': 'All',
    'Enrolled': 'Enrolled',
    'Pending': 'Not Enrolled',
    'Conditional': 'Conditional',
    'Transferred': 'Transferred Out',
    'Graduated': 'Graduated',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Trigger rebuild to update tab content
      }
    });
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper().getStudentsByEnrollmentStatus('All');
    setState(() { _allStudents = data; _isLoading = false; });
  }

  List<Map<String, dynamic>> _filteredStudents(String tab) {
    final filterStatus = _tabFilter[tab] ?? 'All';
    var list = filterStatus == 'All' ? _allStudents
        : _allStudents.where((s) => (s['enrollment_status'] ?? 'Not Enrolled') == filterStatus).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) =>
        (s['name'] ?? '').toString().toLowerCase().contains(q) ||
        (s['student_id'] ?? '').toString().toLowerCase().contains(q) ||
        (s['grade_level'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final s in _allStudents) {
      final status = s['enrollment_status'] ?? 'Not Enrolled';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _enroll(Map<String, dynamic> student) async {
    final sectionController = TextEditingController(text: student['section'] ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enroll ${student['name'] ?? 'Student'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grade Level: ${student['grade_level'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 12),
              const Text('Assign Section (optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: sectionController,
                decoration: InputDecoration(
                  hintText: 'e.g. Rizal, Bonifacio...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1664C5), foregroundColor: Colors.white),
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper().enrollStudent(student['student_id'].toString(), section: sectionController.text.trim());
      await _loadStudents();
      if (mounted) {
        final studentName = student['name'] ?? 'Student';
        AestheticDialogs.showSuccessDialog(
          context,
          title: 'Enrollment Confirmed',
          message: '$studentName has been enrolled successfully in ${sectionController.text.trim()}!',
        );
      }
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> student, String newStatus) async {
    await DatabaseHelper().updateEnrollmentStatus(student['student_id'].toString(), newStatus);
    await _loadStudents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.blue),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Enrolled': return const Color(0xFF10B981);
      case 'Not Enrolled': return const Color(0xFFF59E0B);
      case 'Transferred Out': return const Color(0xFF64748B);
      case 'Dropped': return const Color(0xFFEF4444);
      case 'Graduated': return const Color(0xFF8B5CF6);
      case 'Conditional': return const Color(0xFFEA580C);
      default: return const Color(0xFF94A3B8);
    }
  }

  Color _promotionColor(String? status) {
    switch (status) {
      case 'Promoted': return const Color(0xFF10B981);
      case 'Graduated': return const Color(0xFF8B5CF6);
      case 'Conditional': return const Color(0xFFF59E0B);
      case 'Retained': return const Color(0xFFEF4444);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Enrollment Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage student enrollment statuses for the active school year',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadStudents,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1664C5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Responsive Stats Cards (Adapts smoothly from mobile 2x2 to desktop 4-in-a-row)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 860;
              final cardWidth = isDesktop ? (width - 36) / 4 : (width - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.people_alt_rounded,
                      const Color(0xFFDBEAFE),
                      const Color(0xFF1664C5),
                      'Total Students',
                      _allStudents.length.toString(),
                      isCompact: !isDesktop,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.check_circle_rounded,
                      const Color(0xFFDCFCE7),
                      const Color(0xFF10B981),
                      'Enrolled',
                      (_statusCounts['Enrolled'] ?? 0).toString(),
                      isCompact: !isDesktop,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.hourglass_empty_rounded,
                      const Color(0xFFFEF3C7),
                      const Color(0xFFD97706),
                      'Pending',
                      (_statusCounts['Not Enrolled'] ?? 0).toString(),
                      isCompact: !isDesktop,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.school_rounded,
                      const Color(0xFFEDE9FE),
                      const Color(0xFF7C3AED),
                      'Graduated',
                      (_statusCounts['Graduated'] ?? 0).toString(),
                      isCompact: !isDesktop,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search and Tabs (Stack vertically on narrow screens, row on desktop)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 720;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildSearchBar(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildTabBar(),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _buildTabBar(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      final students = _filteredStudents(tab);
                      if (students.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.inbox_rounded, size: 54, color: Color(0xFF94A3B8)),
                              SizedBox(height: 12),
                              Text('No students found in this category.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: students.length,
                        itemBuilder: (_, i) => _buildStudentCard(students[i]),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by name, ID, or grade level...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        onChanged: (v) {
          setState(() { _searchQuery = v; });
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 42,
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
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF1664C5),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF1664C5),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    Color iconBgColor,
    Color iconColor,
    String title,
    String value, {
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: isCompact ? 20 : 24),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
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

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final enrollStatus = student['enrollment_status'] ?? 'Not Enrolled';
    final promotionStatus = student['promotion_status']?.toString();
    final statusColor = _statusColor(enrollStatus);
    final studentName = student['name'] ?? 'Unknown';
    final studentId = student['student_id'] ?? '';
    final gradeLevel = student['grade_level'] ?? '';
    final section = student['section'] ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isNarrow
                // Mobile layout: Avatar + Name on top, tags and actions below
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              studentName.toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1664C5), fontSize: 17),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'LRN: $studentId  •  $gradeLevel ${section.isNotEmpty ? "- $section" : ""}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'Enrolled', child: Text('Mark as Enrolled')),
                              const PopupMenuItem(value: 'Not Enrolled', child: Text('Mark as Not Enrolled')),
                              const PopupMenuItem(value: 'Transferred Out', child: Text('Transferred Out')),
                              const PopupMenuItem(value: 'Dropped', child: Text('Dropped')),
                            ],
                            onSelected: (status) => _changeStatus(student, status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              enrollStatus,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                          if (promotionStatus != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _promotionColor(promotionStatus).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Promotion: $promotionStatus',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _promotionColor(promotionStatus),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (enrollStatus == 'Not Enrolled' || enrollStatus == 'Conditional')
                            ElevatedButton.icon(
                              onPressed: () => _enroll(student),
                              icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                              label: const Text('Enroll', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1664C5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                // Desktop layout: Horizontal row
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          studentName.toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1664C5), fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'LRN: $studentId  •  $gradeLevel ${section.isNotEmpty ? "- $section" : ""}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            if (promotionStatus != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.trending_up, size: 14, color: _promotionColor(promotionStatus)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Promotion: $promotionStatus',
                                    style: TextStyle(fontSize: 12, color: _promotionColor(promotionStatus), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          enrollStatus,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (enrollStatus == 'Not Enrolled' || enrollStatus == 'Conditional') ...[
                        ElevatedButton.icon(
                          onPressed: () => _enroll(student),
                          icon: const Icon(Icons.how_to_reg, size: 16),
                          label: const Text('Enroll'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1664C5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'Enrolled', child: Text('Mark as Enrolled')),
                          const PopupMenuItem(value: 'Not Enrolled', child: Text('Mark as Not Enrolled')),
                          const PopupMenuItem(value: 'Transferred Out', child: Text('Transferred Out')),
                          const PopupMenuItem(value: 'Dropped', child: Text('Dropped')),
                        ],
                        onSelected: (status) => _changeStatus(student, status),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
