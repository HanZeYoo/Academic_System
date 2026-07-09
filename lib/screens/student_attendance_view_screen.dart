import 'package:flutter/material.dart';
import '../database_helper.dart';

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
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadAttendance(isRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E66B4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_turned_in, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Attendance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E66B4),
                  ),
                ),
              ],
            ),
            if (_schoolYears.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSchoolYear,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E66B4)),
                      style: const TextStyle(color: Color(0xFF1E66B4), fontWeight: FontWeight.bold),
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
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_attendanceRecords.isEmpty)
              const Center(
                child: Text(
                  'No attendance records found.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ..._attendanceRecords.map((a) => _buildAttendanceCard(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final status = record['status'] ?? 'Present';
    Color statusColor = Colors.green;
    if (status == 'Absent') statusColor = Colors.red;
    if (status == 'Late') statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['class_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF224A60),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      record['date'] ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
