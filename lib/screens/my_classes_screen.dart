import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'teacher_student_screen.dart';

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
    if (s.contains('math')) return Icons.calculate;
    if (s.contains('science') || s.contains('biology') || s.contains('chem') || s.contains('physics')) return Icons.science;
    if (s.contains('english') || s.contains('literature') || s.contains('reading')) return Icons.menu_book;
    if (s.contains('computer') || s.contains('ict') || s.contains('programming') || s.contains('tech')) return Icons.computer;
    if (s.contains('history') || s.contains('social') || s.contains('araling')) return Icons.public;
    if (s.contains('art') || s.contains('music') || s.contains('pe') || s.contains('mapeh')) return Icons.palette;
    if (s.contains('filipino') || s.contains('wika')) return Icons.translate;
    return Icons.class_;
  }

  Color _colorFor(int index) {
    const colors = [
      Color(0xFF0D6EFD), // Blue
      Color(0xFF198754), // Green
      Color(0xFF6F42C1), // Purple
      Color(0xFFE67E22), // Orange
      Color(0xFF0DCAF0), // Cyan
      Color(0xFFD63384), // Pink
      Color(0xFF20C997), // Teal
      Color(0xFFFFC107), // Amber
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
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header
                Row(
                  children: [
                    const Icon(Icons.layers, color: Color(0xFF0D6EFD), size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      'My Classes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    // Class count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6EFD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_classes.length} ${_classes.length == 1 ? 'Class' : 'Classes'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0D6EFD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Empty state
                if (_classes.isEmpty)
                  _buildEmptyState()
                else ...[
                  // Class Cards
                  ..._classes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cls = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.security, size: 16, color: Colors.black87),
                    SizedBox(width: 6),
                    Text(
                      'Secure & Private',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D6EFD).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.class_outlined,
              size: 48,
              color: Color(0xFF0D6EFD),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Classes Assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _teacherName != null
                ? 'No classes are assigned to you yet.\nAsk the admin to assign classes to your account.'
                : 'Your teacher account was not found.\nPlease contact the administrator.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D6EFD),
              side: const BorderSide(color: Color(0xFF0D6EFD)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
    final scheduleStr = [schedule, time].where((s) => s.isNotEmpty).join(' - ');
    final finalSchedule = scheduleStr.isEmpty ? 'No schedule set' : scheduleStr;
    final room = data['room']?.toString() ?? '';
    final capacity = data['capacity']?.toString() ?? '0';
    final status = data['status']?.toString() ?? '';
    final gradeLine = [gradeLevel, section].where((s) => s.isNotEmpty).join(' - ');

    final iconColor = _colorFor(index);
    final icon = _iconFor(subject);

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (status == 'Active')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF198754).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF198754),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (status == 'Inactive')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (gradeLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          gradeLine,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event_note, size: 14, color: Colors.black45),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                finalSchedule,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              if (room.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  room,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Student count from capacity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, size: 14, color: Color(0xFF0D6EFD)),
                      const SizedBox(width: 4),
                      Text(
                        capacity,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        ' Cap.',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D6EFD),
                    side: BorderSide(color: Colors.blue.shade100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View Class', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


}
