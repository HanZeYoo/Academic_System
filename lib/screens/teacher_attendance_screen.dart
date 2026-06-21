import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database_helper.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final String username;
  final String? initialClass;
  final bool showAppBar;
  const TeacherAttendanceScreen({super.key, required this.username, this.initialClass, this.showAppBar = false});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  bool _isLoading = true;
  List<String> _classes = [];
  String? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _students = [];
  String _searchQuery = '';
  Set<DateTime> _markedDates = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final dbHelper = DatabaseHelper();
    // Get teacher details to get name
    final teacherData = await dbHelper.getTeacherByEmail(widget.username);
    if (teacherData != null) {
      final name = teacherData['name']?.toString() ?? '';
      // Get classes
      final assignedClasses = await dbHelper.getSubjectClassesByTeacher(name);
      // Create a unique list of classes (Grade Level - Section)
      final uniqueClasses = assignedClasses.map((c) => '${c['grade_level']} - ${c['section_name']}').toSet().toList();
      
      setState(() {
        _classes = uniqueClasses;
        if (_classes.isNotEmpty) {
          if (widget.initialClass != null && _classes.contains(widget.initialClass)) {
            _selectedClass = widget.initialClass;
          } else {
            _selectedClass = _classes.first;
          }
        }
      });
      if (_selectedClass != null) {
        await _loadMarkedDates();
        await _loadStudentsAndAttendance();
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadMarkedDates() async {
    if (_selectedClass == null) return;
    final dbHelper = DatabaseHelper();
    final datesStr = await dbHelper.getAttendanceDatesForClass(_selectedClass!);
    setState(() {
      _markedDates = datesStr.map((d) => DateTime.parse(d)).toSet();
    });
  }

  Future<void> _loadStudentsAndAttendance() async {
    if (_selectedClass == null) return;
    
    setState(() {
      _isLoading = true;
    });

    final parts = _selectedClass!.split(' - ');
    if (parts.length < 2) {
      setState(() {
        _isLoading = false;
        _students = [];
      });
      return;
    }
    final gradeLevel = parts[0];
    final section = parts[1];

    final dbHelper = DatabaseHelper();
    // Get students for this class
    final rawStudents = await dbHelper.getStudentsBySection(gradeLevel, section);
    
    // Format date string for DB (YYYY-MM-DD)
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    
    // Get saved attendance
    final savedAttendance = await dbHelper.getAttendanceForClassAndDate(_selectedClass!, dateStr);
    final attendanceMap = { for (var item in savedAttendance) item['student_id'].toString(): item['status'] };

    // Format for UI
    final List<Map<String, dynamic>> uiStudents = [];
    final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.indigo];
    
    for (int i = 0; i < rawStudents.length; i++) {
      final student = rawStudents[i];
      final sid = student['student_id'].toString();
      final status = attendanceMap[sid] ?? 'Present'; // Default to Present
      final baseColor = colors[i % colors.length];
      
      uiStudents.add({
        'id': sid,
        'name': student['name'].toString(),
        'class': _selectedClass,
        'status': status,
        'color': baseColor.shade100,
        'iconColor': baseColor,
      });
    }

    setState(() {
      _students = uiStudents;
      _isLoading = false;
    });
  }

  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students to save.')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final dbHelper = DatabaseHelper();
    
    for (var student in _students) {
      await dbHelper.saveAttendance({
        'student_id': student['id'],
        'student_name': student['name'],
        'class_name': _selectedClass,
        'date': dateStr,
        'status': student['status'],
      });
    }
    
    // Hide loading
    Navigator.pop(context);

    setState(() {
      // Add to marked dates so the calendar updates immediately
      _markedDates.add(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance Saved Successfully'), backgroundColor: Colors.green),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime focusedDate = _selectedDate;
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2101, 12, 31),
                  focusedDay: focusedDate,
                  currentDay: _selectedDate,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDate, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    Navigator.pop(context, selectedDay);
                  },
                  eventLoader: (day) {
                    // Check if the day is in _markedDates
                    final hasAttendance = _markedDates.any((marked) => isSameDay(marked, day));
                    if (hasAttendance) {
                      return ['Attendance Taken'];
                    }
                    return [];
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green, // Indicator color
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(color: Color(0xFF1E66B4), shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: Color(0xFF1E66B4), shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadStudentsAndAttendance();
    }
  }

  // Helper to format date for UI display
  String _formatDateForUI(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('Attendance'),
        backgroundColor: const Color(0xFF3383B3),
        foregroundColor: Colors.white,
      ) : null,
      backgroundColor: widget.showAppBar ? const Color(0xFFF4F7F6) : Colors.transparent, // Inherits from dashboard body
      body: _isLoading && _classes.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildFilters(),
                        const SizedBox(height: 16),
                        _buildStatsCards(),
                        const SizedBox(height: 24),
                        _buildStudentListHeader(),
                        const SizedBox(height: 12),
                        
                        if (_isLoading)
                           const Center(child: Padding(
                             padding: EdgeInsets.all(32.0),
                             child: CircularProgressIndicator(),
                           ))
                        else if (_students.isEmpty)
                           Center(
                             child: Padding(
                               padding: const EdgeInsets.all(32.0),
                               child: Text(
                                 _selectedClass == null ? 'No class selected' : 'No students found in $_selectedClass', 
                                 style: TextStyle(color: Colors.grey[600])
                               ),
                             )
                           )
                        else ...() {
                           final filteredStudents = _searchQuery.isEmpty 
                               ? _students 
                               : _students.where((student) {
                                   final nameMatches = student['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                                   final idMatches = student['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                                   return nameMatches || idMatches;
                                 }).toList();
                                 
                           if (filteredStudents.isEmpty) {
                             return [
                               Center(
                                 child: Padding(
                                   padding: const EdgeInsets.all(32.0),
                                   child: Text('No students found matching "$_searchQuery"', style: TextStyle(color: Colors.grey[600])),
                                 )
                               )
                             ];
                           }
                           return filteredStudents.map((student) => _buildStudentItem(student)).toList();
                        }(),
                        
                        const SizedBox(height: 24),
                        if (_students.isNotEmpty) _buildActionButtons(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            icon: Icon(Icons.search, color: Colors.grey),
            hintText: 'Search student by name or ID...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3383B3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.people_alt, size: 32, color: Color(0xFF3383B3)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF224A60),
              ),
            ),
            Text(
              'Track daily student attendance',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), // Match Date padding
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Class', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 20, // constrain height
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedClass,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                      items: _classes.isEmpty 
                          ? [const DropdownMenuItem(value: null, child: Text('No Classes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))]
                          : _classes.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              );
                            }).toList(),
                      onChanged: (newValue) async {
                        if (newValue != null && newValue != _selectedClass) {
                          setState(() {
                            _selectedClass = newValue;
                          });
                          await _loadMarkedDates();
                          await _loadStudentsAndAttendance();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(_formatDateForUI(_selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    int total = _students.length;
    int present = _students.where((s) => s['status'] == 'Present').length;
    int absent = _students.where((s) => s['status'] == 'Absent').length;
    int late = _students.where((s) => s['status'] == 'Late').length;

    String presentPct = total > 0 ? '${((present / total) * 100).toStringAsFixed(1)}%' : '0%';
    String absentPct = total > 0 ? '${((absent / total) * 100).toStringAsFixed(1)}%' : '0%';
    String latePct = total > 0 ? '${((late / total) * 100).toStringAsFixed(1)}%' : '0%';

    return Column(
      children: [
        Row(
          children: [
            _buildStatCard('Total Students', total.toString(), '', Colors.blue, Icons.people),
            _buildStatCard('Present', present.toString(), presentPct, Colors.green, Icons.check_circle),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('Absent', absent.toString(), absentPct, Colors.red, Icons.cancel),
            _buildStatCard('Late', late.toString(), latePct, Colors.orange, Icons.access_time_filled),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, String percentage, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 4),
            Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (percentage.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(percentage, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Student Attendance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              'Select status for each student',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentItem(Map<String, dynamic> student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: student['color'],
                child: Icon(Icons.person, color: student['iconColor'], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LRN: ${student['id']} • ${student['class']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusGroup(student),
        ],
      ),
    );
  }

  Widget _buildStatusGroup(Map<String, dynamic> student) {
    final String currentStatus = student['status'];

    return Row(
      children: [
        _buildStatusButton('Present', Colors.green, currentStatus, student),
        _buildStatusButton('Late', Colors.orange, currentStatus, student),
        _buildStatusButton('Absent', Colors.red, currentStatus, student),
        _buildStatusButton('Excused', Colors.purple, currentStatus, student),
      ],
    );
  }

  Widget _buildStatusButton(String label, Color color, String currentStatus, Map<String, dynamic> student) {
    final bool isSelected = currentStatus == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            student['status'] = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey.withOpacity(0.3),
            ),
            borderRadius: label == 'Present' 
                ? const BorderRadius.horizontal(left: Radius.circular(8))
                : label == 'Excused' 
                    ? const BorderRadius.horizontal(right: Radius.circular(8))
                    : BorderRadius.zero,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saveAttendance,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text('Save Attendance', style: TextStyle(fontSize: 16, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B659B), // Darker blue for primary button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              // Mark all as present
              setState(() {
                for (var student in _students) {
                  student['status'] = 'Present';
                }
              });
            },
            icon: const Icon(Icons.group_add, color: Color(0xFF1B659B)),
            label: const Text('Mark All Present', style: TextStyle(fontSize: 16, color: Color(0xFF1B659B))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1B659B)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
