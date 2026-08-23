import 'package:flutter/material.dart';
import '../database_helper.dart';

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
        title: Text('Enroll '),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grade Level: ', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Assign Section (optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: sectionController,
              decoration: InputDecoration(
                hintText: 'e.g. Rizal, Bonifacio...',
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(' enrolled successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> student, String newStatus) async {
    await DatabaseHelper().updateEnrollmentStatus(student['student_id'].toString(), newStatus);
    await _loadStudents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to '), backgroundColor: Colors.blue),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Enrolled': return Colors.green;
      case 'Not Enrolled': return Colors.orange;
      case 'Transferred Out': return Colors.blueGrey;
      case 'Dropped': return Colors.red;
      case 'Graduated': return const Color(0xFF6A0DAD);
      case 'Conditional': return Colors.deepOrange;
      default: return Colors.grey;
    }
  }

  Color _promotionColor(String? status) {
    switch (status) {
      case 'Promoted': return Colors.green;
      case 'Graduated': return const Color(0xFF6A0DAD);
      case 'Conditional': return Colors.orange;
      case 'Retained': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Enrollment Management',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage student enrollment statuses for the active school year',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadStudents,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1664C5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Cards
          Row(
            children: [
              Expanded(child: _buildStatCard(Icons.people, const Color(0xFFCBEAFB), const Color(0xFF1664C5), 'Total Students', _allStudents.length.toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(Icons.check_circle, const Color(0xFFE2F6E7), const Color(0xFF00A364), 'Enrolled', (_statusCounts['Enrolled'] ?? 0).toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(Icons.hourglass_empty, Colors.orange.shade100, Colors.orange.shade800, 'Pending', (_statusCounts['Not Enrolled'] ?? 0).toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(Icons.school, Colors.purple.shade100, Colors.purple.shade700, 'Graduated', (_statusCounts['Graduated'] ?? 0).toString())),
            ],
          ),
          const SizedBox(height: 24),

          // Search and Tabs row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, or grade...',
                    prefixIcon: const Icon(Icons.search, color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) {
                    setState(() { _searchQuery = v; });
                  },
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF1664C5),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF1664C5),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: _tabs.map((t) => Tab(text: t)).toList(),
                  ),
                ),
              ),
            ],
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
                              Icon(Icons.inbox, size: 64, color: Colors.black26),
                              SizedBox(height: 12),
                              Text('No students found.', style: TextStyle(color: Colors.black45)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
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

  Widget _buildStatCard(IconData icon, Color iconBgColor, Color iconColor, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 24,
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFCBEAFB),
              child: Text(
                (student['name'] ?? 'S').toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1664C5), fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('  •    •  ',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  if (promotionStatus != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 14, color: _promotionColor(promotionStatus)),
                        const SizedBox(width: 4),
                        Text(
                          'Promotion: ',
                          style: TextStyle(fontSize: 12, color: _promotionColor(promotionStatus), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Enrollment Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            const SizedBox(width: 16),
            // Actions
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
  }
}
