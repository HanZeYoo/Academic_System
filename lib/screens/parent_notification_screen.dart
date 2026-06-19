import 'package:flutter/material.dart';
import '../database_helper.dart';

class ParentNotificationScreen extends StatefulWidget {
  const ParentNotificationScreen({super.key});

  @override
  State<ParentNotificationScreen> createState() =>
      _ParentNotificationScreenState();
}

class _ParentNotificationScreenState extends State<ParentNotificationScreen> {
  String _selectedTab = 'History'; // 'History' or 'New Notification'
  final DatabaseHelper db = DatabaseHelper();

  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];

  String? _selectedStudentId;
  String? _selectedClassCode;
  String? _selectedReason;
  final TextEditingController _messageController = TextEditingController();

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

    _classes = await db.getSubjectClasses();
    _students = await db.getStudents();
    
    await _loadHistory();

    setState(() => _isLoading = false);
  }

  Future<void> _loadHistory() async {
    final notifications = await db.getNotificationsSentBy('admin');
    
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
        'date': n['date'] ?? '',
        'status': n['status'] ?? 'Sent',
      });
    }
    
    setState(() {
      _history = loadedHistory;
    });
  }

  void _updateDraftMessage() {
    if (_selectedReason == null || _selectedStudentId == null) return;

    final student = _students.firstWhere(
      (s) => s['student_id'].toString() == _selectedStudentId,
    );
    final studentName = student['name'].toString();

    String message = "";
    switch (_selectedReason) {
      case 'Failing Grades':
        message =
            "Dear Parent, this is to inform you that $studentName is currently at risk of failing. We suggest a meeting to discuss improvement plans.";
        break;
      case 'Frequent Absences':
        message =
            "Dear Parent, we noticed that $studentName has many absences recently. This is affecting their academic performance.";
        break;
      case 'Outstanding Performance':
        message =
            "Dear Parent, I am happy to inform you that $studentName has been showing outstanding performance! Keep up the good work.";
        break;
      case 'Parent-Teacher Conference':
        message =
            "Dear Parent, we would like to invite you for a short conference to discuss $studentName's progress.";
        break;
      default:
        message =
            "Dear Parent, we would like to discuss some matters regarding $studentName.";
    }

    setState(() {
      _messageController.text = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats
        Container(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 20,
          ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2F0FB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.campaign,
                            color: Color(0xFF1664C5),
                          ),
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showNotifyAllAtRiskDialog();
                    },
                    icon: const Icon(Icons.warning, size: 16),
                    label: const Text(
                      'Notify All',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                      icon: Icons.access_time_filled,
                      iconBgColor: const Color(0xFFFDF0E1),
                      iconColor: const Color(0xFFE67E22),
                      title: 'Pending Replies',
                      value: '14',
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
                Row(
                  children: [
                    Expanded(child: _buildTabButton('History', Icons.history)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabButton(
                        'New Notification',
                        Icons.add_comment,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main Body Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedTab == 'History'
                      ? _buildHistoryView()
                      : _buildNewNotificationView(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showNotifyAllAtRiskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Color(0xFFE74C3C)),
            const SizedBox(width: 8),
            const Text('Bulk Notification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will automatically detect all students flagged as "At-Risk" and send their parents a notification.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message Preview:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                'Dear Parent, this is an update regarding your child\'s academic performance. They are currently tagged as "At-Risk" in our latest evaluation. Please review their status or contact us for a scheduled meeting.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notifications successfully queued for sending!',
                  ),
                  backgroundColor: Color(0xFF198754),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send to All At-Risk'),
          ),
        ],
      ),
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
      icon: Icon(icon, size: 18),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : const Color(0xFF224A60),
        backgroundColor: isSelected ? const Color(0xFF3383B3) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        elevation: isSelected ? 2 : 0,
      ),
    );
  }

  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Notifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _history.isEmpty 
              ? const Center(child: Text("No notifications sent yet."))
              : ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFDECEE),
                      child: const Icon(
                        Icons.warning,
                        color: Color(0xFFE74C3C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['reason'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'To: ${item['parentName']} (Parent of ${item['studentName']})',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['date'],
                            style: const TextStyle(
                              color: Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item['status'] == 'Read'
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFE3F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item['status'],
                        style: TextStyle(
                          color: item['status'] == 'Read'
                              ? const Color(0xFF198754)
                              : const Color(0xFF1664C5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewNotificationView() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: ListView(
        children: [
          const Text(
            'Compose Notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          _buildLabel('Select Student'),
          const SizedBox(height: 6),
          _buildDropdownContainer(
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text(
                'Choose a student...',
                style: TextStyle(fontSize: 13),
              ),
              value: _selectedStudentId,
              items: _students.map((s) {
                return DropdownMenuItem(
                  value: s['student_id'].toString(),
                  child: Text(
                    s['name'].toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedStudentId = val);
                _updateDraftMessage();
              },
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('Subject/Class (Optional)'),
          const SizedBox(height: 6),
          _buildDropdownContainer(
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text(
                'Choose class...',
                style: TextStyle(fontSize: 13),
              ),
              value: _selectedClassCode,
              items: _classes.map((c) {
                return DropdownMenuItem(
                  value: c['subject_code'].toString(),
                  child: Text(
                    '${c['subject_name']} (${c['section_name']})',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedClassCode = val),
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('Reason for Notification'),
          const SizedBox(height: 6),
          _buildDropdownContainer(
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text(
                'Choose a reason...',
                style: TextStyle(fontSize: 13),
              ),
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

          _buildLabel('Custom Message'),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Type your message here...',
              hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_selectedStudentId == null || _selectedReason == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a student and reason.'),
                    ),
                  );
                  return;
                }
                
                final student = _students.firstWhere((s) => s['student_id'].toString() == _selectedStudentId);
                final parentEmail = student['parent_email']?.toString() ?? '';
                
                if (parentEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Parent email is not configured for this student.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }

                String dateNow = "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
                
                await db.insertNotification({
                  'sender_username': 'admin',
                  'receiver_username': parentEmail.isNotEmpty ? parentEmail : 'jaymar.riveral@neu.edu.ph.com',
                  'student_id': _selectedStudentId,
                  'title': _selectedReason,
                  'message': _messageController.text,
                  'date': dateNow,
                  'status': 'Sent'
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification sent successfully! (In-app + Email Mock)'),
                    backgroundColor: Color(0xFF198754),
                  ),
                );
                
                setState(() {
                  _selectedStudentId = null;
                  _selectedReason = null;
                  _messageController.clear();
                  _selectedTab = 'History';
                });
                
                await _loadHistory();
              },
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send to Parent'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF198754),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
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
