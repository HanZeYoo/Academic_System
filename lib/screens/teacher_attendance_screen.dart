import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../database_helper.dart';
import '../utils/dialog_utils.dart';
import '../utils/avatar_utils.dart';

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
  List<Map<String, dynamic>> _assignedClassesFull = [];
  Timer? _endClassTimer;

  @override
  void dispose() {
    _endClassTimer?.cancel();
    super.dispose();
  }

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
      // Create a unique list of classes (SubjectCode - Grade Level - Section)
      final uniqueClasses = assignedClasses.map((c) => '${c['subject_code']} - ${c['grade_level']} - ${c['section_name']}').toSet().toList();
      
      setState(() {
        _assignedClassesFull = assignedClasses;
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
    if (parts.length < 3) {
      setState(() {
        _isLoading = false;
        _students = [];
      });
      return;
    }
    // parts[0] is subject_code, parts[1] is gradeLevel, parts[2] is section
    final gradeLevel = parts[1];
    final section = parts[2];

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
    final prefs = await SharedPreferences.getInstance();
    
    for (int i = 0; i < rawStudents.length; i++) {
      final student = rawStudents[i];
      final sid = student['student_id'].toString();
      final email = student['email']?.toString() ?? '';
      final status = attendanceMap[sid] ?? 'Absent'; // Default to Absent
      final baseColor = colors[i % colors.length];

      String? photo = student['profile_picture']?.toString();
      if (photo == null || photo.trim().isEmpty) {
        if (email.isNotEmpty) {
          photo = prefs.getString('profile_pic_student_$email');
        }
        if ((photo == null || photo.isEmpty) && sid.isNotEmpty) {
          photo = prefs.getString('profile_pic_student_$sid');
        }
      }
      
      uiStudents.add({
        'id': sid,
        'name': student['name'].toString(),
        'email': email,
        'class': _selectedClass,
        'status': status,
        'color': baseColor.shade100,
        'iconColor': baseColor,
        'profile_picture': photo,
      });
    }

    setState(() {
      _students = uiStudents;
      _isLoading = false;
    });

    _setupAutoSweep();
  }

  void _setupAutoSweep() {
    _endClassTimer?.cancel();
    if (_selectedClass == null || _assignedClassesFull.isEmpty) return;
    
    // Only sweep if the selected date is today
    final now = DateTime.now();
    if (_selectedDate.year != now.year || _selectedDate.month != now.month || _selectedDate.day != now.day) {
      return;
    }

    final classRecord = _assignedClassesFull.firstWhere(
      (c) => '${c['subject_code']} - ${c['grade_level']} - ${c['section_name']}' == _selectedClass,
      orElse: () => {},
    );
    final timeStr = classRecord['time']?.toString() ?? '';
    if (timeStr.isEmpty) return;

    final timeParts = timeStr.split(' - ');
    if (timeParts.length < 2) return;
    
    final endTimeStr = timeParts[1];
    final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false).firstMatch(endTimeStr.trim());
    if (match != null) {
      int h = int.parse(match.group(1)!);
      int m = int.parse(match.group(2)!);
      String ampm = match.group(3)!.toUpperCase();
      if (ampm == 'PM' && h < 12) h += 12;
      if (ampm == 'AM' && h == 12) h = 0;
      
      final endDateTime = DateTime(now.year, now.month, now.day, h, m);
      
      if (now.isAfter(endDateTime)) {
        bool hasUnsavedAbsents = _students.any((s) => s['status'] == 'Absent');
        if (hasUnsavedAbsents) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAutoSweepDialog();
          });
        }
      } else {
        // Class will end later today. Set up a timer.
        final duration = endDateTime.difference(now);
        _endClassTimer = Timer(duration, () {
          if (mounted) {
            _saveAttendance(isAutoSweep: true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Class ended. Remaining students auto-saved as Absent.')),
            );
          }
        });
      }
    }
  }

  void _showAutoSweepDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Class Ended'),
        content: const Text('The time for this class has already ended. Do you want to automatically save the remaining unmarked students as Absent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveAttendance(isAutoSweep: true);
            },
            child: const Text('Auto-Save Absents'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF224A60)),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Got it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAttendance({bool isAutoSweep = false}) async {
    if (_selectedClass == null || _students.isEmpty) {
      if (!isAutoSweep) _showErrorDialog('Warning', 'No students to save.');
      return;
    }

    // --- TIME LOCKING LOGIC ---
    final classRecord = _assignedClassesFull.firstWhere(
      (c) => '${c['subject_code']} - ${c['grade_level']} - ${c['section_name']}' == _selectedClass,
      orElse: () => {},
    );
    
    final timeStr = classRecord['time']?.toString() ?? '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (!isAutoSweep) {
      if (selectedDay.isBefore(today)) {
        _showErrorDialog('Action Blocked', 'Cannot edit attendance for past dates.\n\nClass time is already over.');
        return;
      }
      if (selectedDay.isAfter(today)) {
        _showErrorDialog('Action Blocked', 'Cannot take attendance for future dates.');
        return;
      }
    }

    if (!isAutoSweep && timeStr.isNotEmpty) {
      final timeParts = timeStr.split(' - ');
      if (timeParts.length == 2) {
        final endTimeStr = timeParts[1];
        final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false).firstMatch(endTimeStr.trim());
        if (match != null) {
          int h = int.parse(match.group(1)!);
          int m = int.parse(match.group(2)!);
          String ampm = match.group(3)!.toUpperCase();
          if (ampm == 'PM' && h < 12) h += 12;
          if (ampm == 'AM' && h == 12) h = 0;
          
          final endDateTime = DateTime(now.year, now.month, now.day, h, m);
          if (now.isAfter(endDateTime)) {
            _showErrorDialog('Attendance Locked', 'Class time is over. Attendance editing is now locked.');
            return;
          }
        }
      }
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

      // --- SEND PUSH NOTIFICATIONS ---
      if (student['status'] == 'Absent' || student['status'] == 'Late') {
        final currentStatus = student['status'].toString().toUpperCase();
        debugPrint('--- ATTENDANCE PUSH FOR ${student['name']} ($currentStatus) ---');
        
        String parentEmail = '';
        String studentEmail = '';
        
        try {
          // 1. Get Parent and Student Email from Students table
          final studentData = await Supabase.instance.client
              .from('students')
              .select('parent_email, email')
              .eq('student_id', student['id'])
              .maybeSingle();

          parentEmail = studentData?['parent_email']?.toString() ?? '';
          studentEmail = studentData?['email']?.toString() ?? '';
          debugPrint('Parent Email: $parentEmail | Student Email: $studentEmail');
        } catch (e) {
          debugPrint('Error fetching emails: $e');
        }

        // --- NOTIFY PARENT (Absent only, as per original logic) ---
        if (parentEmail.isNotEmpty && student['status'] == 'Absent') {
          try {
            final reasonToSend = 'Attendance Alert: $currentStatus';
            final messageToSend = '${student['name']} was marked $currentStatus for $_selectedClass today ($dateStr).';

            // Insert In-App Notification Record for Parent
            await dbHelper.insertNotification({
              'sender_username': widget.username,
              'receiver_username': parentEmail,
              'student_id': student['id'],
              'title': reasonToSend,
              'message': messageToSend,
              'date': "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}",
              'status': 'Sent'
            });

            // Get Parent FCM Token & Send Push
            final parentUser = await Supabase.instance.client
                .from('users')
                .select('fcm_token')
                .eq('username', parentEmail)
                .maybeSingle();

            final fcmToken = parentUser?['fcm_token'];
            debugPrint('Parent FCM Token: $fcmToken');
            if (fcmToken != null && fcmToken.toString().isNotEmpty) {
              await Supabase.instance.client.functions.invoke('send-fcm', body: {
                'title': reasonToSend,
                'body': messageToSend,
                'token': fcmToken.toString(),
                'data': {
                  'route': 'notifications',
                },
              });
              debugPrint('Parent Push Notification Invoked.');
            } else {
              debugPrint('Failed to send Parent Push: FCM Token is null/empty.');
            }
          } catch (e) {
            debugPrint('Error sending PARENT attendance notification: $e');
          }
        }

        // --- NOTIFY STUDENT (Absent or Late, Push Only) ---
        if (studentEmail.isNotEmpty) {
          try {
            final reasonToSend = 'Attendance Alert: $currentStatus';
            final messageToSend = 'You were marked $currentStatus for $_selectedClass today ($dateStr).';

            // Get Student FCM Token & Send Push
            final studentUser = await Supabase.instance.client
                .from('users')
                .select('fcm_token')
                .eq('username', studentEmail)
                .maybeSingle();

            final studentFcmToken = studentUser?['fcm_token'];
            debugPrint('Student FCM Token: $studentFcmToken');
            
            if (studentFcmToken != null && studentFcmToken.toString().isNotEmpty) {
              await Supabase.instance.client.functions.invoke('send-fcm', body: {
                'title': reasonToSend,
                'body': messageToSend,
                'token': studentFcmToken.toString(),
                'data': {
                  'route': 'attendance', // Route to attendance screen or dashboard
                },
              });
              debugPrint('Student Push Notification Invoked.');
            } else {
              debugPrint('Failed to send Student Push: FCM Token is null/empty.');
            }
          } catch (e) {
            debugPrint('Error sending STUDENT attendance notification: $e');
          }
        } else {
          debugPrint('Failed to send Student Push: Student Email is empty in DB.');
        }
      }
    }
    
    // Hide loading
    Navigator.pop(context);

    setState(() {
      // Add to marked dates so the calendar updates immediately
      _markedDates.add(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
    });

    AestheticDialogs.showSuccessDialog(
      context,
      title: 'Attendance Saved',
      message: 'Attendance records have been saved successfully!',
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
              AvatarUtils.buildAvatar(
                photo: student['profile_picture']?.toString(),
                name: student['name'],
                radius: 22,
                backgroundColor: student['color'],
                foregroundColor: student['iconColor'],
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
        // Start NFC Scan Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _startNfcScan,
            icon: const Icon(Icons.nfc, color: Colors.white),
            label: const Text('Start NFC Scan', style: TextStyle(fontSize: 16, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F52BA), // Deep blue
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

  void _startNfcScan() {
    if (_selectedClass == null || _students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class with enrolled students first.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NfcAttendanceModalDialog(
        selectedClass: _selectedClass!,
        selectedDate: _selectedDate,
        students: _students,
        assignedClassesFull: _assignedClassesFull,
        onAttendanceMarked: (studentId, status, [photo]) {
          setState(() {
            for (var student in _students) {
              if (student['id'].toString() == studentId) {
                student['status'] = status;
                if (photo != null && photo.toString().isNotEmpty) {
                  student['profile_picture'] = photo.toString();
                }
                break;
              }
            }
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NFC ATTENDANCE POP-UP MODAL
// ─────────────────────────────────────────────────────────────────────────────

enum _NfcScanState { waiting, success, late, alreadyRecorded, unregistered, wrongClass }

class _NfcAttendanceModalDialog extends StatefulWidget {
  final String selectedClass;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> assignedClassesFull;
  final Function(String studentId, String status, [String? profilePicture]) onAttendanceMarked;

  const _NfcAttendanceModalDialog({
    required this.selectedClass,
    required this.selectedDate,
    required this.students,
    required this.assignedClassesFull,
    required this.onAttendanceMarked,
  });

  @override
  State<_NfcAttendanceModalDialog> createState() => _NfcAttendanceModalDialogState();
}

class _NfcAttendanceModalDialogState extends State<_NfcAttendanceModalDialog>
    with SingleTickerProviderStateMixin {
  _NfcScanState _scanState = _NfcScanState.waiting;
  bool _isNfcAvailable = true;
  bool _isListening = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _scannedStudent;
  String _lastUid = '';
  int _sessionScanCount = 0;
  final Set<String> _recordedStudentIdsInSession = {};
  Timer? _countdownTimer;
  int _countdownSeconds = 3;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Pre-populate with students already marked Present or Late for this class today
    for (var s in widget.students) {
      if (s['status'] == 'Present' || s['status'] == 'Late') {
        _recordedStudentIdsInSession.add(s['id'].toString());
      }
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initNfc();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) {
        setState(() => _isNfcAvailable = available);
      }
      if (available) {
        _startListening();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isNfcAvailable = false);
      }
    }
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;
    try {
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          _handleTagDiscovered(tag);
        },
      );
    } catch (e) {
      debugPrint('Error starting NFC session: $e');
    }
  }

  Future<void> _handleTagDiscovered(NfcTag tag) async {
    if (_isProcessing) return;
    try {
      final Map<String, dynamic> tagData = Map<String, dynamic>.from(tag.data as Map);
      final Map<String, dynamic>? mifare = tagData['mifareclassic'] != null
          ? Map<String, dynamic>.from(tagData['mifareclassic'] as Map)
          : null;
      final Map<String, dynamic>? nfca = tagData['nfca'] != null
          ? Map<String, dynamic>.from(tagData['nfca'] as Map)
          : null;
      final Map<String, dynamic>? ndef = tagData['ndef'] != null
          ? Map<String, dynamic>.from(tagData['ndef'] as Map)
          : null;

      final dynamic identifier = mifare?['identifier'] ?? nfca?['identifier'] ?? ndef?['identifier'];
      if (identifier != null && identifier is List) {
        final List<int> idBytes = List<int>.from(identifier);
        final String uid = idBytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
        _processUid(uid);
      }
    } catch (e) {
      debugPrint('NFC Tag processing error: $e');
    }
  }

  Future<void> _processUid(String uid) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _countdownTimer?.cancel();
    _lastUid = uid;

    try {
      final res = await Supabase.instance.client
          .from('students')
          .select('student_id, name, email, profile_picture, grade_level, section')
          .eq('nfc_uid', uid)
          .maybeSingle();

      if (!mounted) return;

      if (res == null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _scanState = _NfcScanState.unregistered;
        });
        _startAutoResetTimer();
        return;
      }

      final studentMap = Map<String, dynamic>.from(res);
      String? photo = studentMap['profile_picture']?.toString();

      // Fallback 1: check student list of current class
      if (photo == null || photo.trim().isEmpty) {
        final matchInList = widget.students.firstWhere(
          (s) => s['id']?.toString() == studentMap['student_id']?.toString(),
          orElse: () => {},
        );
        if (matchInList['profile_picture'] != null && matchInList['profile_picture'].toString().trim().isNotEmpty) {
          photo = matchInList['profile_picture'].toString();
        }
      }

      // Fallback 2: check SharedPreferences cache (by email or student_id)
      if (photo == null || photo.trim().isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final email = studentMap['email']?.toString() ?? '';
          final sid = studentMap['student_id']?.toString() ?? '';
          if (email.isNotEmpty) {
            photo = prefs.getString('profile_pic_student_$email');
          }
          if ((photo == null || photo.isEmpty) && sid.isNotEmpty) {
            photo = prefs.getString('profile_pic_student_$sid');
          }
        } catch (_) {}
      }

      studentMap['profile_picture'] = photo;

      await _recordAttendanceForStudent(studentMap);
    } catch (e) {
      debugPrint('Error processing UID: $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _isProcessing = false;
        }
      });
    }
  }

  Future<void> _recordAttendanceForStudent(Map<String, dynamic> studentData) async {
    final matchedStudentId = studentData['student_id'].toString();
    final studentInClass = widget.students.any((s) => s['id'].toString() == matchedStudentId);

    if (!studentInClass) {
      HapticFeedback.mediumImpact();
      setState(() {
        _scanState = _NfcScanState.wrongClass;
        _scannedStudent = studentData;
      });
      _startAutoResetTimer(seconds: 4);
      return;
    }

    // Check if student was already recorded in this session or already marked Present/Late
    final studentRecord = widget.students.firstWhere(
      (s) => s['id'].toString() == matchedStudentId,
      orElse: () => {},
    );
    final isAlreadyPresentOrLate = studentRecord['status'] == 'Present' || studentRecord['status'] == 'Late';
    final isAlreadyRecordedInSession = _recordedStudentIdsInSession.contains(matchedStudentId);

    if (isAlreadyRecordedInSession || isAlreadyPresentOrLate) {
      // Duplicate tap detected: DO NOT count again, DO NOT re-notify parent
      _recordedStudentIdsInSession.add(matchedStudentId);
      final currentStatus = studentRecord['status']?.toString() ?? 'Present';

      final now = DateTime.now();
      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final period = now.hour >= 12 ? 'PM' : 'AM';
      final formattedTime = "$hour:${now.minute.toString().padLeft(2, '0')} $period";

      HapticFeedback.selectionClick();

      setState(() {
        _scanState = _NfcScanState.alreadyRecorded;
        _scannedStudent = {
          ...studentData,
          'status': currentStatus,
          'time': formattedTime,
        };
        // NOTE: _sessionScanCount is NOT incremented!
      });

      _startAutoResetTimer(seconds: 3);
      return;
    }

    // Compute Present vs Late
    String newStatus = 'Present';
    if (widget.selectedClass.isNotEmpty && widget.assignedClassesFull.isNotEmpty) {
      final classRecord = widget.assignedClassesFull.firstWhere(
        (c) => '${c['subject_code']} - ${c['grade_level']} - ${c['section_name']}' == widget.selectedClass,
        orElse: () => {},
      );
      final timeStr = classRecord['time']?.toString() ?? '';
      if (timeStr.isNotEmpty) {
        final timeParts = timeStr.split(' - ');
        if (timeParts.isNotEmpty) {
          final startTimeStr = timeParts[0];
          final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false).firstMatch(startTimeStr.trim());
          if (match != null) {
            int h = int.parse(match.group(1)!);
            int m = int.parse(match.group(2)!);
            String ampm = match.group(3)!.toUpperCase();
            if (ampm == 'PM' && h < 12) h += 12;
            if (ampm == 'AM' && h == 12) h = 0;

            final now = DateTime.now();
            final startDateTime = DateTime(now.year, now.month, now.day, h, m);
            final lateThreshold = startDateTime.add(const Duration(minutes: 15));

            if (now.isAfter(lateThreshold)) {
              newStatus = 'Late';
            }
          }
        }
      }
    }

    // Mark student ID as recorded
    _recordedStudentIdsInSession.add(matchedStudentId);

    // Update parent screen list
    widget.onAttendanceMarked(matchedStudentId, newStatus, studentData['profile_picture']?.toString());

    // Save to database & send push/SMS notification
    final dateStr = "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";
    final dbHelper = DatabaseHelper();
    dbHelper.saveAttendance({
      'student_id': matchedStudentId,
      'class_name': widget.selectedClass,
      'date': dateStr,
      'status': newStatus,
    });
    dbHelper.sendAttendanceNotification(matchedStudentId, studentData['name'] ?? '', widget.selectedClass, newStatus);

    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final formattedTime = "$hour:${now.minute.toString().padLeft(2, '0')} $period";

    HapticFeedback.heavyImpact();

    setState(() {
      _scanState = newStatus == 'Late' ? _NfcScanState.late : _NfcScanState.success;
      _scannedStudent = {
        ...studentData,
        'status': newStatus,
        'time': formattedTime,
      };
      _sessionScanCount++;
    });

    _startAutoResetTimer(seconds: 3);
  }

  void _startAutoResetTimer({int seconds = 3}) {
    _countdownTimer?.cancel();
    _countdownSeconds = seconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        _resetToWaiting();
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  void _resetToWaiting() {
    _countdownTimer?.cancel();
    _isProcessing = false;
    if (mounted) {
      setState(() {
        _scanState = _NfcScanState.waiting;
        _scannedStudent = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      elevation: 16,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header
            _buildDialogHeader(),

            // Animated Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStateView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F52BA), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.nfc, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NFC Attendance Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.selectedClass,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Close Scanner',
            onPressed: () {
              NfcManager.instance.stopSession();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStateView() {
    switch (_scanState) {
      case _NfcScanState.waiting:
        return _buildWaitingState();
      case _NfcScanState.success:
      case _NfcScanState.late:
        return _buildScannedSuccessState();
      case _NfcScanState.alreadyRecorded:
        return _buildAlreadyRecordedState();
      case _NfcScanState.unregistered:
        return _buildUnregisteredState();
      case _NfcScanState.wrongClass:
        return _buildWrongClassState();
    }
  }

  // State 1: Waiting for NFC tap with radar effect
  Widget _buildWaitingState() {
    return Column(
      key: const ValueKey('waiting'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF0F52BA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F52BA).withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.contactless_rounded, color: Colors.white, size: 54),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tap Student ID Card',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Hold the student\'s RFID/NFC card against the back of your phone to take attendance.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 16),
              const SizedBox(width: 6),
              Text(
                '$_sessionScanCount student(s) recorded this session',
                style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!_isNfcAvailable) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NFC hardware not detected.',
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              NfcManager.instance.stopSession();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Stop Scanning', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // State 2: Pop-up modal when card is tapped
  Widget _buildScannedSuccessState() {
    final isLate = _scanState == _NfcScanState.late;
    final statusColor = isLate ? const Color(0xFFD97706) : const Color(0xFF16A34A);
    final statusBgColor = isLate ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7);
    final statusText = isLate ? 'LATE' : 'PRESENT';
    final student = _scannedStudent ?? {};

    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: statusBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLate ? Icons.schedule_rounded : Icons.check_circle_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ATTENDANCE RECORDED: $statusText',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Large Student Avatar with glowing border
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.25),
                blurRadius: 16,
                spreadRadius: 3,
              ),
            ],
          ),
          child: AvatarUtils.buildAvatar(
            photo: student['profile_picture']?.toString(),
            name: student['name']?.toString(),
            radius: 46,
            backgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: const Color(0xFF0F52BA),
          ),
        ),
        const SizedBox(height: 16),

        // Student Full Name
        Text(
          student['name']?.toString() ?? 'Student',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),

        // LRN & Section
        Text(
          'LRN: ${student['student_id'] ?? 'N/A'} • Grade ${student['grade_level'] ?? ''} - ${student['section'] ?? ''}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),

        // Time Stamp
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_rounded, size: 15, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                'Recorded at ${student['time'] ?? 'Just Now'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Real-time parent notification badge
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Color(0xFF16A34A), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Parent notified in real-time via Push Notification & Email',
                  style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Auto-dismiss countdown + action
        Text(
          'Scanning next student in $_countdownSeconds s...',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetToWaiting,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            label: const Text('Scan Next Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F52BA),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // State: Student already recorded / duplicate tap
  Widget _buildAlreadyRecordedState() {
    const statusColor = Color(0xFFD97706); // Amber
    const statusBgColor = Color(0xFFFEF3C7);
    final student = _scannedStudent ?? {};
    final recordedStatus = student['status']?.toString() ?? 'Present';

    return Column(
      key: const ValueKey('alreadyRecorded'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: statusBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: statusColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ALREADY RECORDED',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Student Avatar with glowing amber ring
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.2),
                blurRadius: 16,
                spreadRadius: 3,
              ),
            ],
          ),
          child: AvatarUtils.buildAvatar(
            photo: student['profile_picture']?.toString(),
            name: student['name']?.toString(),
            radius: 46,
            backgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: const Color(0xFF0F52BA),
          ),
        ),
        const SizedBox(height: 16),

        // Student Full Name
        Text(
          student['name']?.toString() ?? 'Student',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),

        // LRN & Section
        Text(
          'LRN: ${student['student_id'] ?? 'N/A'} • Grade ${student['grade_level'] ?? ''} - ${student['section'] ?? ''}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),

        // Status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 15, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(
                'Currently marked as $recordedStatus',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Duplicate Tap notice banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.repeat_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Card already tapped for this session. Not counted again.',
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Auto-dismiss countdown + action
        Text(
          'Scanning next student in $_countdownSeconds s...',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetToWaiting,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            label: const Text('Scan Next Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F52BA),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // State 3: Unregistered NFC card
  Widget _buildUnregisteredState() {
    return Column(
      key: const ValueKey('unregistered'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.credit_card_off_rounded, color: Color(0xFFDC2626), size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'Unregistered NFC Card',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
        ),
        const SizedBox(height: 6),
        Text(
          'UID: $_lastUid',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        Text(
          'This card is not yet linked to any student. Please register this card in Student Management before taking attendance.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _resetToWaiting,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F52BA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Try Another Card', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // State 4: Student is in another class
  Widget _buildWrongClassState() {
    final student = _scannedStudent ?? {};
    return Column(
      key: const ValueKey('wrongClass'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large Student Avatar with amber warning ring
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD97706), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 3,
              ),
            ],
          ),
          child: AvatarUtils.buildAvatar(
            photo: student['profile_picture']?.toString(),
            name: student['name']?.toString(),
            radius: 46,
            backgroundColor: const Color(0xFFFEF3C7),
            foregroundColor: const Color(0xFFD97706),
            fallbackIcon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Student Not in This Class',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
        ),
        const SizedBox(height: 8),
        Text(
          student['name']?.toString() ?? 'Student',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Enrolled in: Grade ${student['grade_level'] ?? ''} - ${student['section'] ?? ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        Text(
          'This student does not belong to ${widget.selectedClass}. Attendance was not recorded for this class.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _resetToWaiting,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F52BA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue Scanning', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

