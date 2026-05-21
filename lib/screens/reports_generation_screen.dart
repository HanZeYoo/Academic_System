import 'package:flutter/material.dart';
import '../database_helper.dart';

class ReportsGenerationScreen extends StatefulWidget {
  final String? username;
  const ReportsGenerationScreen({super.key, this.username});

  @override
  State<ReportsGenerationScreen> createState() => _ReportsGenerationScreenState();
}

class _ReportsGenerationScreenState extends State<ReportsGenerationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClassData;
  String _selectedPeriod = '1st Quarter';
  static const _periods = ['1st Quarter', '2nd Quarter', '3rd Quarter', '4th Quarter'];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final db = DatabaseHelper();
    List<Map<String, dynamic>> classes = [];
    
    if (widget.username != null) {
      final teacher = await db.getTeacherByEmail(widget.username!);
      if (teacher != null) {
        classes = await db.getSubjectClassesByTeacher(teacher['name'].toString());
      }
    } else {
      classes = await db.getSubjectClasses();
    }
    
    if (mounted) {
      setState(() {
        _classes = classes;
        _selectedClassData = classes.isNotEmpty ? classes.first : null;
        _isLoading = false;
      });
    }
  }

  String get _classLabel {
    if (_selectedClassData == null) return 'No class selected';
    return '${_selectedClassData!["grade_level"]} - ${_selectedClassData!["section_name"]} (${_selectedClassData!["subject_name"]})';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          _buildStatCards(),
          const SizedBox(height: 16),
          _buildGenerateButton(),
          const SizedBox(height: 16),
          _buildReportCategories(),
          const SizedBox(height: 16),
          _buildRecentReports(),
          const SizedBox(height: 16),
          _buildExportOptions(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search reports...',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E66B4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bar_chart, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'Reports',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E66B4), // Matches the text color in mockup
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdownField(
                  label: 'Class',
                  value: _classLabel,
                  items: _classes.isEmpty 
                    ? ['No class selected'] 
                    : _classes.map((c) => '${c["grade_level"]} - ${c["section_name"]} (${c["subject_name"]})').toList(),
                  onChanged: (val) {
                    if (_classes.isEmpty) return;
                    final match = _classes.firstWhere((c) =>
                      '${c["grade_level"]} - ${c["section_name"]} (${c["subject_name"]})' == val,
                      orElse: () => _classes.first);
                    setState(() => _selectedClassData = match);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Grading Period',
                  value: _selectedPeriod,
                  items: _periods.toList(),
                  onChanged: (val) {
                    setState(() => _selectedPeriod = val!);
                  },
                ),
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            Icons.insert_chart,
            const Color(0xFF4A89DC),
            'Total Reports',
            '48',
            '5.2%',
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            Icons.calendar_today,
            const Color(0xFF4DC271),
            'Generated This Month',
            '16',
            '3.8%',
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    Color iconColor,
    String title,
    String value,
    String percentage,
    Color percentageColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.2),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.arrow_upward, color: percentageColor, size: 14),
              Text(
                ' $percentage',
                style: TextStyle(
                  color: percentageColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Expanded(
                child: Text(
                  ' from last month',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Generate Report',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E66B4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCategories() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Categories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  Icons.school,
                  const Color(0xFF4A89DC),
                  'Student Performance',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  Icons.show_chart,
                  const Color(0xFFF6A65C),
                  'Failure Analytics',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  Icons.calendar_today,
                  const Color(0xFF4DC271),
                  'Attendance Report',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  Icons.notifications,
                  const Color(0xFF7E57C2),
                  'Parent Notification Logs',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(IconData icon, Color color, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Reports',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildRecentReportItem(
            Icons.insert_chart,
            const Color(0xFF4A89DC),
            'Student Performance Report',
            'Grade 10-A • May 2025',
            'Ready',
            const Color(0xFFD4EED9),
            const Color(0xFF4DC271),
          ),
          const Divider(),
          _buildRecentReportItem(
            Icons.show_chart,
            const Color(0xFFF6A65C),
            'Failure Analytics Report',
            'Quarter 2 • All Sections',
            'Ready',
            const Color(0xFFD4EED9),
            const Color(0xFF4DC271),
          ),
          const Divider(),
          _buildRecentReportItem(
            Icons.calendar_today,
            const Color(0xFF4DC271),
            'Attendance Summary',
            'Grade 9-B • May 2025',
            'Processing',
            const Color(0xFFFEE1D2),
            const Color(0xFFF6A65C),
          ),
          const Divider(),
          _buildRecentReportItem(
            Icons.notifications,
            const Color(0xFF7E57C2),
            'Parent Notification Log',
            'Mathematics • May 2025',
            'Ready',
            const Color(0xFFD4EED9),
            const Color(0xFF4DC271),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReportItem(
    IconData icon,
    Color iconColor,
    String title,
    String subtitle,
    String status,
    Color statusBgColor,
    Color statusTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.15),
            radius: 20,
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.remove_red_eye, color: const Color(0xFF1E66B4)),
          const SizedBox(width: 4),
          Container(height: 20, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 4),
          Icon(Icons.download, color: const Color(0xFF1E66B4)),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Options',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildExportButton(
                  Icons.picture_as_pdf,
                  const Color(0xFFE53935),
                  'PDF',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExportButton(
                  Icons.table_chart,
                  const Color(0xFF4DC271),
                  'Excel',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExportButton(
                  Icons.print,
                  const Color(0xFF7E57C2),
                  'Print',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
