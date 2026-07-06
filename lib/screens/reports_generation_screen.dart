import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../services/report_service.dart';

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
  String _selectedReportCategory = 'Student Performance';
  bool _isGenerating = false;
  List<Map<String, dynamic>> _recentReports = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadRecentReports();
  }

  Future<void> _loadRecentReports() async {
    final prefs = await SharedPreferences.getInstance();
    final String? reportsJson = prefs.getString('recent_reports');
    if (reportsJson != null) {
      final List<dynamic> decoded = jsonDecode(reportsJson);
      setState(() {
        _recentReports = decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _saveRecentReport(String category, String className, String period, Map<String, dynamic> classData) async {
    final newReport = {
      'category': category,
      'className': className,
      'period': period,
      'classData': classData,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _recentReports.insert(0, newReport);
      if (_recentReports.length > 5) {
        _recentReports.removeLast();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_reports', jsonEncode(_recentReports));
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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          _buildReportCategories(),
          const SizedBox(height: 16),
          if (_isGenerating) const Center(child: CircularProgressIndicator()) else _buildExportOptions(),
          const SizedBox(height: 16),
          _buildRecentReports(),
        ],
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
    final isSelected = _selectedReportCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReportCategory = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1),
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
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: isSelected ? color : Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
          if (_recentReports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No reports generated yet.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._recentReports.map((report) {
              IconData icon = Icons.insert_chart;
              Color color = const Color(0xFF4A89DC);
              
              if (report['category'] == 'Failure Analytics') {
                icon = Icons.show_chart;
                color = const Color(0xFFF6A65C);
              } else if (report['category'] == 'Attendance Report') {
                icon = Icons.calendar_today;
                color = const Color(0xFF4DC271);
              } else if (report['category'] == 'Parent Notification Logs') {
                icon = Icons.notifications;
                color = const Color(0xFF7E57C2);
              }

              return Column(
                children: [
                  _buildRecentReportItem(
                    icon,
                    color,
                    '${report['category']}',
                    '${report['className']} • ${report['period']}',
                    'Ready',
                    const Color(0xFFD4EED9),
                    const Color(0xFF4DC271),
                    () => _executeExport('pdf', report['category'], report['classData'], report['period']),
                    () => _executeExport('csv', report['category'], report['classData'], report['period']),
                  ),
                  if (_recentReports.last != report) const Divider(),
                ],
              );
            }).toList(),
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
    VoidCallback onView,
    VoidCallback onDownload,
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
          GestureDetector(
            onTap: onView,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.remove_red_eye, color: Color(0xFF1E66B4)),
            ),
          ),
          const SizedBox(width: 2),
          Container(height: 20, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDownload,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.download, color: Color(0xFF1E66B4)),
            ),
          ),
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
                  () => _exportReport('pdf'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExportButton(
                  Icons.table_chart,
                  const Color(0xFF4DC271),
                  'Excel / CSV',
                  () => _exportReport('csv'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
      ),
    );
  }

  Future<void> _exportReport(String format) async {
    if (_selectedClassData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class first.')));
      return;
    }
    
    await _executeExport(format, _selectedReportCategory, _selectedClassData!, _selectedPeriod, saveLog: true);
  }

  Future<void> _executeExport(String format, String category, Map<String, dynamic> classData, String period, {bool saveLog = false}) async {
    setState(() => _isGenerating = true);

    try {
      // Collect Data
      final db = DatabaseHelper();
      final gradeLevel = classData['grade_level'].toString();
      final section = classData['section_name'].toString();
      final subjectCode = classData['subject_code'].toString();
      final className = '$gradeLevel - $section';

      List<String> headers = [];
      List<List<dynamic>> data = [];
      String reportTitle = '$category - $className';

      if (category == 'Student Performance') {
        headers = ['Student ID', 'Name', 'Total Score', 'Percentage'];
        final scores = await db.getScoresForClass(
          subjectCode: subjectCode,
          sectionName: section,
          gradeLevel: gradeLevel,
          gradingPeriod: period,
        );
        
        // Aggregate scores by student
        Map<String, Map<String, dynamic>> studentScores = {};
        for (var row in scores) {
          final sId = row['student_id'].toString();
          if (!studentScores.containsKey(sId)) {
            studentScores[sId] = {
              'name': row['student_name'] ?? 'Unknown',
              'score': 0.0,
              'total': 0.0,
            };
          }
          studentScores[sId]!['score'] += (row['score'] as num?)?.toDouble() ?? 0.0;
          studentScores[sId]!['total'] += (row['total_score'] as num?)?.toDouble() ?? 0.0;
        }

        for (var sId in studentScores.keys) {
          final s = studentScores[sId]!;
          double pct = s['total'] > 0 ? (s['score'] / s['total']) * 100 : 0;
          data.add([sId, s['name'], '${s['score']}/${s['total']}', '${pct.toStringAsFixed(1)}%']);
        }
      } else if (category == 'Failure Analytics') {
        headers = ['Student ID', 'Name', 'Status'];
        final scores = await db.getScoresForClass(
          subjectCode: subjectCode,
          sectionName: section,
          gradeLevel: gradeLevel,
          gradingPeriod: period,
        );
        
        Map<String, Map<String, dynamic>> studentScores = {};
        for (var row in scores) {
          final sId = row['student_id'].toString();
          if (!studentScores.containsKey(sId)) {
            studentScores[sId] = {'name': row['student_name'] ?? 'Unknown', 'score': 0.0, 'total': 0.0};
          }
          studentScores[sId]!['score'] += (row['score'] as num?)?.toDouble() ?? 0.0;
          studentScores[sId]!['total'] += (row['total_score'] as num?)?.toDouble() ?? 0.0;
        }

        for (var sId in studentScores.keys) {
          final s = studentScores[sId]!;
          double pct = s['total'] > 0 ? (s['score'] / s['total']) * 100 : 0;
          if (pct < 75.0) {
            data.add([sId, s['name'], 'Failed (${pct.toStringAsFixed(1)}%)']);
          } else {
            data.add([sId, s['name'], 'Passed']);
          }
        }
      } else if (category == 'Attendance Report') {
        headers = ['Date', 'Student ID', 'Student Name', 'Status'];
        final allAttendance = await db.getAttendanceForClass(className);
        for (var record in allAttendance) {
          data.add([
            record['date'] ?? '',
            record['student_id'] ?? '',
            record['student_name'] ?? '',
            record['status'] ?? ''
          ]);
        }
      } else if (category == 'Parent Notification Logs') {
        headers = ['Date', 'Sender', 'Parent Email', 'Student ID', 'Subject', 'Message'];
        final studentsInClass = await db.getStudentsBySection(gradeLevel, section);
        final studentIds = studentsInClass.map((s) => s['student_id'].toString()).toSet();
        
        final allNotifications = await db.getNotificationsSentBy(widget.username ?? 'admin');
        final classNotifications = allNotifications.where((n) {
          return studentIds.contains(n['student_id'].toString());
        }).toList();

        for (var n in classNotifications) {
          data.add([
            n['date'] ?? '',
            n['sender_username'] ?? '',
            n['receiver_username'] ?? '',
            n['student_id'] ?? '',
            n['title'] ?? '',
            n['message'] ?? '',
          ]);
        }
      }

      if (data.isEmpty) {
        data.add(['No data found for this period/class']);
      }

      if (format == 'pdf') {
        await ReportService.generatePDFReport(
          title: reportTitle,
          subtitle: 'Grading Period: $period',
          headers: headers,
          data: data,
        );
      } else {
        final path = await ReportService.generateCSVReport(
          title: reportTitle,
          subtitle: 'Grading Period: $period',
          headers: headers,
          data: data,
        );
        if (mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved CSV to $path'), duration: const Duration(seconds: 4)));
        }
      }
      
      if (saveLog) {
        await _saveRecentReport(category, className, period, classData);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
