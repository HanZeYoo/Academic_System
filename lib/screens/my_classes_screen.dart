import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'teacher_student_screen.dart';
import 'teacher_attendance_screen.dart';
import '../utils/role_theme.dart';

class MyClassesScreen extends StatefulWidget {
  final String username; // teacher's login email
  const MyClassesScreen({super.key, required this.username});

  @override
  State<MyClassesScreen> createState() => _MyClassesScreenState();
}

class _MyClassesScreenState extends State<MyClassesScreen> {
  bool _isLoading = true;
  String? _teacherName;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper();

    // Look up teacher record by their login email (username)
    final teacher = await db.getTeacherByEmail(widget.username);

    List<Map<String, dynamic>> classes = [];
    if (teacher != null) {
      final name = teacher['name'].toString();
      _teacherName = name;
      classes = await db.getSubjectClassesByTeacher(name);
    } else {
      // Fallback: if teacher record not found, load all classes
      classes = await db.getSubjectClasses();
    }

    if (mounted) {
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    }
  }

  // Pick icon & color based on subject name keywords
  IconData _iconFor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return Icons.calculate_rounded;
    if (s.contains('science') || s.contains('biology') || s.contains('chem') || s.contains('physics')) return Icons.science_rounded;
    if (s.contains('english') || s.contains('literature') || s.contains('reading')) return Icons.menu_book_rounded;
    if (s.contains('computer') || s.contains('ict') || s.contains('programming') || s.contains('tech')) return Icons.computer_rounded;
    if (s.contains('history') || s.contains('social') || s.contains('araling')) return Icons.public_rounded;
    if (s.contains('art') || s.contains('music') || s.contains('pe') || s.contains('mapeh')) return Icons.palette_rounded;
    if (s.contains('filipino') || s.contains('wika')) return Icons.translate_rounded;
    return Icons.school_rounded;
  }

  Color _colorFor(int index) {
    const colors = [
      Color(0xFF1E40AF), // Sapphire Blue
      Color(0xFF059669), // Emerald
      Color(0xFF7C3AED), // Purple
      Color(0xFFD97706), // Amber
      Color(0xFF0284C7), // Sky Blue
      Color(0xFFDB2777), // Pink
      Color(0xFF0D9488), // Teal
      Color(0xFF4F46E5), // Indigo
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: RoleTheme.teacherTheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header Bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: RoleTheme.teacherTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.class_rounded, color: RoleTheme.teacherTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Assigned Classes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Active teaching load, schedules, and class rosters',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Class count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: RoleTheme.teacherTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: RoleTheme.teacherTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '${_classes.length} ${_classes.length == 1 ? 'Class' : 'Classes'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: RoleTheme.teacherTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Empty state or Class Cards
                if (_classes.isEmpty)
                  _buildEmptyState()
                else ...[
                  ..._classes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cls = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildClassCard(
                        index: index,
                        data: cls,
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ]),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.verified_user_rounded, size: 15, color: Color(0xFF94A3B8)),
                    SizedBox(width: 6),
                    Text(
                      'Official Academic System Faculty Record',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: RoleTheme.teacherTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              size: 48,
              color: RoleTheme.teacherTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Classes Assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _teacherName != null
                ? 'No classes are assigned to you yet.\nAsk the administrator to assign subjects to your account.'
                : 'Your faculty teacher account was not found.\nPlease contact the administrator.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh Classes'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: RoleTheme.teacherTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard({
    required int index,
    required Map<String, dynamic> data,
  }) {
    final subject = data['subject_name']?.toString() ?? 'Unknown Subject';
    final gradeLevel = data['grade_level']?.toString() ?? '';
    final section = data['section_name']?.toString() ?? '';
    final schedule = data['schedule']?.toString() ?? '';
    final time = data['time']?.toString() ?? '';
    final scheduleStr = [schedule, time].where((s) => s.isNotEmpty).join(' • ');
    final finalSchedule = scheduleStr.isEmpty ? 'Schedule to be announced' : scheduleStr;
    final room = data['room']?.toString() ?? '';
    final capacity = data['capacity']?.toString() ?? '0';
    final status = data['status']?.toString() ?? '';
    final gradeLine = [gradeLevel, section].where((s) => s.isNotEmpty).join(' • ');

    final iconColor = _colorFor(index);
    final icon = _iconFor(subject);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject Icon Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Subject Title & Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (status.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: status == 'Active'
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: status == 'Active'
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: status == 'Active'
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '$capacity Seats',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (gradeLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            gradeLine,
                            style: TextStyle(
                              fontSize: 12,
                              color: iconColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Schedule row
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            finalSchedule,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Room row
                    if (room.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.meeting_room_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              room.toLowerCase().startsWith('room') ? room : 'Room: $room',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherStudentScreen(
                          username: widget.username,
                          initialClass: gradeLine.isNotEmpty ? gradeLine : null,
                          showAppBar: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.groups_rounded, size: 16),
                  label: const Text('View Class Roster', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RoleTheme.teacherTheme.primary,
                    side: BorderSide(color: RoleTheme.teacherTheme.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherAttendanceScreen(
                          username: widget.username,
                          initialClass: gradeLine.isNotEmpty ? gradeLine : null,
                          showAppBar: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.checklist_rounded, size: 16),
                  label: const Text('Attendance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF059669),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
