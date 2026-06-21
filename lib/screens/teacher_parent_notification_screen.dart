import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';
import '../services/email_service.dart';

class TeacherParentNotificationScreen extends StatefulWidget {
  final String username;
  const TeacherParentNotificationScreen({super.key, required this.username});

  @override
  State<TeacherParentNotificationScreen> createState() =>
      _TeacherParentNotificationScreenState();
}

class _TeacherParentNotificationScreenState
    extends State<TeacherParentNotificationScreen> {
  String _selectedTab = 'Needs Attention'; // 'Needs Attention', 'Compose', 'History'
  final DatabaseHelper db = DatabaseHelper();

  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _atRiskStudents = [];

  String? _selectedStudentId;
  String? _selectedClassCode;
  String? _selectedReason;
  final TextEditingController _messageController = TextEditingController();
  bool _sendViaEmail = true; // Toggle for mock Email sending

  final List<String> _reasons = [
    'Failing Grades',
    'Frequent Absences',
    'Behavioral Issue',
    'Outstanding Performance',
    'Parent-Teacher Conference',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // History List
  List<Map<String, dynamic>> _history = [];

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final teacher = await db.getTeacherByEmail(widget.username);
    if (teacher != null) {
      final teacherName = teacher['name'].toString();
      _classes = await db.getSubjectClassesByTeacher(teacherName);

      // Get all students for the classes taught by this teacher
      final List<Map<String, dynamic>> allMyStudents = [];
      final Set<String> seenIds = {};

      for (var cls in _classes) {
        final studentsInClass = await db.getStudentsBySection(
          cls['grade_level'].toString(),
          cls['section_name'].toString(),
        );
        for (var s in studentsInClass) {
          final sid = s['student_id'].toString();
          if (!seenIds.contains(sid)) {
            // Fetch general average
            String genAveStr = await db.getStudentGeneralAverage(sid);
            Map<String, dynamic> studentData = Map<String, dynamic>.from(s);
            studentData['general_average'] = genAveStr;
            allMyStudents.add(studentData);
            seenIds.add(sid);
          }
        }
      }
      
      _students = allMyStudents;
      
      // Filter At-Risk
      _atRiskStudents = _students.where((s) {
        if (s['general_average'] == 'N/A') return false;
        double ave = double.tryParse(s['general_average']) ?? 100.0;
        return ave < 80.0;
      }).toList();
    }
    
    await _loadHistory();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    final notifications = await db.getNotificationsSentBy(widget.username);
    
    List<Map<String, dynamic>> loadedHistory = [];
    for (var n in notifications) {
      final student = _students.firstWhere(
        (s) => s['student_id'].toString() == n['student_id'].toString(),
        orElse: () => {'name': 'Unknown Student', 'parent_name': 'Unknown Parent'},
      );
      
      loadedHistory.add({
        'studentName': student['name'] ?? 'Unknown',
        'parentName': student['parent_name'] ?? n['receiver_username'],
        'reason': n['title'] ?? 'No Reason',
        'message': n['message'] ?? '',
        'date': n['date'] ?? '',
        'status': n['status'] ?? 'Sent',
      });
    }
    
    if (mounted) {
      setState(() {
        _history = loadedHistory.reversed.toList(); // Newest first
      });
    }
  }

  void _updateDraftMessage() {
    if (_selectedReason == null || _selectedStudentId == null) return;

    final student = _students.firstWhere(
      (s) => s['student_id'].toString() == _selectedStudentId,
    );
    final studentName = student['name'].toString();
    final ave = student['general_average']?.toString() ?? 'N/A';

    String message = "";
    switch (_selectedReason) {
      case 'Failing Grades':
        message = "Dear Parent, this is to inform you that $studentName is currently at risk of failing with a current overall average of $ave%. We suggest a meeting to discuss improvement plans.";
        break;
      case 'Frequent Absences':
        message = "Dear Parent, we noticed that $studentName has many absences recently. This is currently affecting their academic performance (Average: $ave%).";
        break;
      case 'Outstanding Performance':
        message = "Dear Parent, I am happy to inform you that $studentName has been showing outstanding performance in our class with an average of $ave%! Keep up the good work.";
        break;
      case 'Parent-Teacher Conference':
        message = "Dear Parent, I would like to invite you for a short conference to discuss $studentName's progress and performance in class.";
        break;
      default:
        message = "Dear Parent, I would like to discuss some matters regarding $studentName.";
    }

    setState(() {
      _messageController.text = message;
    });
  }

  void _notifyAtRiskStudent(Map<String, dynamic> student) {
    setState(() {
      _selectedStudentId = student['student_id'].toString();
      _selectedReason = 'Failing Grades';
      _selectedTab = 'Compose';
    });
    _updateDraftMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2F0FB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign, color: Color(0xFF1664C5)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Parent Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF224A60),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.send,
                      iconBgColor: const Color(0xFFE2F6E7),
                      iconColor: const Color(0xFF00A364),
                      title: 'Notifications Sent',
                      value: _history.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.warning_amber_rounded,
                      iconBgColor: const Color(0xFFFDECEE),
                      iconColor: const Color(0xFFE74C3C),
                      title: 'At-Risk Students',
                      value: _atRiskStudents.length.toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body (Tabs and Content)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Toggle Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton('Needs Attention', Icons.notification_important),
                      const SizedBox(width: 8),
                      _buildTabButton('Compose', Icons.edit_document),
                      const SizedBox(width: 8),
                      _buildTabButton('History', Icons.chat),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Body Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedTab == 'Needs Attention'
                          ? _buildNeedsAttentionView()
                          : _selectedTab == 'Compose'
                              ? _buildNewNotificationView()
                              : _buildHistoryView(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 18,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon) {
    bool isSelected = _selectedTab == title;
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _selectedTab = title;
        });
      },
      icon: Icon(icon, size: 16),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : const Color(0xFF224A60),
        backgroundColor: isSelected ? const Color(0xFF3383B3) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        elevation: isSelected ? 2 : 0,
      ),
    );
  }

  Widget _buildNeedsAttentionView() {
    if (_atRiskStudents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('All good! No students are currently at risk.', style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _atRiskStudents.length,
      itemBuilder: (context, index) {
        final student = _atRiskStudents[index];
        double ave = double.tryParse(student['general_average'].toString()) ?? 100;
        bool isHighRisk = ave < 75;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isHighRisk ? const Color(0xFFFDECEE) : const Color(0xFFFFF3CD),
                child: Icon(Icons.warning, color: isHighRisk ? const Color(0xFFE74C3C) : Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student['name']?.toString() ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('General Average: ${student['general_average']}%', style: TextStyle(color: isHighRisk ? Colors.red : Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _notifyAtRiskStudent(student),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3383B3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
                child: const Text('Send Warning', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    if (_history.isEmpty) {
      return const Center(child: Text("No notifications sent yet.", style: TextStyle(color: Colors.black54)));
    }

    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16, left: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCF8C6), // Chat bubble green
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4), // Chat tail pointing right
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('To: ${item['parentName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF075E54))),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(item['date'], style: const TextStyle(color: Colors.black45, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Subject: ${item['reason']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
                const Divider(color: Colors.black12, height: 16),
                Text(item['message'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Delivered', style: TextStyle(fontSize: 10, color: Colors.black45)),
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 14, color: item['status'] == 'Read' ? Colors.blue : Colors.black45),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewNotificationView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListView(
        children: [
          const Text('Compose Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 20),

          _buildLabel('Select Student'),
          const SizedBox(height: 6),
          _buildDropdownContainer(
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Choose a student...', style: TextStyle(fontSize: 13)),
              value: _selectedStudentId,
              items: _students.map((s) {
                return DropdownMenuItem(
                  value: s['student_id'].toString(),
                  child: Text(s['name'].toString(), style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedStudentId = val);
                _updateDraftMessage();
              },
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('Reason for Notification'),
          const SizedBox(height: 6),
          _buildDropdownContainer(
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Choose a reason...', style: TextStyle(fontSize: 13)),
              value: _selectedReason,
              items: _reasons.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedReason = val);
                _updateDraftMessage();
              },
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('Message Content'),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Type your message here...',
              hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 16),

          // Send via Email Mock Toggle
          Row(
            children: [
              Checkbox(
                value: _sendViaEmail,
                onChanged: (val) {
                  setState(() => _sendViaEmail = val ?? true);
                },
                activeColor: const Color(0xFF3383B3),
              ),
              const Text('Send a copy via Email', style: TextStyle(fontSize: 13, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_selectedStudentId == null || _selectedReason == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student and reason.')));
                  return;
                }
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                try {
                  final student = _students.firstWhere((s) => s['student_id'].toString() == _selectedStudentId);
                  final parentEmail = student['parent_email']?.toString() ?? '';
                  
                  String dateNow = "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
                  
                  await db.insertNotification({
                    'sender_username': widget.username,
                    'receiver_username': parentEmail.isNotEmpty ? parentEmail : 'mock_parent@test.com',
                    'student_id': _selectedStudentId,
                    'title': _selectedReason,
                    'message': _messageController.text,
                    'date': dateNow,
                    'status': 'Sent'
                  });

                  if (_sendViaEmail && parentEmail.isNotEmpty) {
                    await EmailService.sendEmail(
                      toEmail: parentEmail,
                      subject: 'Academic System: ${_selectedReason}',
                      messageText: _messageController.text,
                    );
                  }

                  // Send Push Notification via Supabase Edge Function
                  if (parentEmail.isNotEmpty) {
                    try {
                      final parentUser = await Supabase.instance.client
                          .from('users')
                          .select('fcm_token')
                          .eq('email', parentEmail)
                          .maybeSingle();
                      
                      final fcmToken = parentUser?['fcm_token'];
                      if (fcmToken != null && fcmToken.toString().isNotEmpty) {
                        await Supabase.instance.client.functions.invoke('send-fcm', body: {
                          'title': 'Attention: $_selectedReason',
                          'body': _messageController.text,
                          'token': fcmToken.toString(),
                        });
                      }
                    } catch (e) {
                      print('Error sending push notification: $e');
                    }
                  }

                  if (mounted) {
                    Navigator.pop(context); // Close loading screen
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_sendViaEmail 
                            ? (parentEmail.isEmpty ? 'Notification saved! (Parent has no email)' : 'Notification sent! (In-app + Email sent to $parentEmail)') 
                            : 'Notification sent! (In-app only)'),
                        backgroundColor: const Color(0xFF198754),
                      ),
                    );
                  }
                  
                  setState(() {
                    _selectedStudentId = null;
                    _selectedReason = null;
                    _messageController.clear();
                    _selectedTab = 'History';
                  });
                  
                  await _loadHistory();
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading screen on error
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF3383B3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54));
  }

  Widget _buildDropdownContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }
}
