import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../utils/role_theme.dart';

class StudentAttendanceViewScreen extends StatefulWidget {
  final String username;
  const StudentAttendanceViewScreen({super.key, required this.username});

  @override
  State<StudentAttendanceViewScreen> createState() => _StudentAttendanceViewScreenState();
}

class _StudentAttendanceViewScreenState extends State<StudentAttendanceViewScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];
  String? _selectedSchoolYear;
  List<String> _schoolYears = [];
  final theme = RoleTheme.studentTheme;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    final db = DatabaseHelper();

    final years = await db.getAllSchoolYears();
    final activeYear = await db.getActiveSchoolYear();
    if (_selectedSchoolYear == null) {
      _selectedSchoolYear = activeYear;
    }

    final records = await db.getStudentAttendance(widget.username, _selectedSchoolYear);

    if (mounted) {
      setState(() {
        _schoolYears = years.isNotEmpty ? years : [activeYear];
        _attendanceRecords = records;
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

    final presentCount = _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'present').length;
    final lateCount = _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'late').length;
    final absentCount = _attendanceRecords.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'absent').length;

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () => _loadAttendance(isRefresh: true),
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
                      child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance Record',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Classroom presence & punctuality history',
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
                              _loadAttendance();
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

            // Summary Stats Cards
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
                          width: 140,
                          child: _buildAttendanceStatTile(
                            title: 'Present',
                            count: presentCount.toString(),
                            color: const Color(0xFF10B981),
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: _buildAttendanceStatTile(
                            title: 'Late',
                            count: lateCount.toString(),
                            color: const Color(0xFFF59E0B),
                            icon: Icons.access_time_filled_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: _buildAttendanceStatTile(
                            title: 'Absent',
                            count: absentCount.toString(),
                            color: const Color(0xFFEF4444),
                            icon: Icons.cancel_rounded,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceStatTile(
                        title: 'Present',
                        count: presentCount.toString(),
                        color: const Color(0xFF10B981),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAttendanceStatTile(
                        title: 'Late',
                        count: lateCount.toString(),
                        color: const Color(0xFFF59E0B),
                        icon: Icons.access_time_filled_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAttendanceStatTile(
                        title: 'Absent',
                        count: absentCount.toString(),
                        color: const Color(0xFFEF4444),
                        icon: Icons.cancel_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),

            if (_attendanceRecords.isEmpty)
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
                      child: Icon(Icons.event_available_outlined, size: 40, color: theme.primary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No attendance logs recorded',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Classroom attendance entries logged by teachers will be displayed here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._attendanceRecords.map((a) => _buildAttendanceCard(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatTile({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
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
                  count,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final status = (record['status']?.toString() ?? 'Present');
    final className = record['class_name']?.toString() ?? 'Class Session';
    final date = record['date']?.toString() ?? 'Recent';

    Color statusColor = const Color(0xFF10B981);
    Color statusBg = const Color(0xFFDCFCE7);
    IconData statusIcon = Icons.check_circle_rounded;

    if (status.toLowerCase() == 'absent') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEE2E2);
      statusIcon = Icons.cancel_rounded;
    } else if (status.toLowerCase() == 'late') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFEF3C7);
      statusIcon = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
