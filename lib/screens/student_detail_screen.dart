import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../services/email_service.dart';
import 'login_screen.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  String _generalAverage = 'Loading...';
  String _attendance = 'Loading...';
  String _riskStatus = 'Loading...';
  Color _riskColor = const Color(0xFF10B981); // Green

  @override
  void initState() {
    super.initState();
    _loadPerformanceSnapshot();
  }

  Future<void> _loadPerformanceSnapshot() async {
    final studentId = widget.student['student_id']?.toString() ?? '';
    if (studentId.isEmpty) {
      setState(() {
        _generalAverage = 'N/A';
        _attendance = 'N/A';
        _riskStatus = 'Unknown';
        _riskColor = Colors.grey;
      });
      return;
    }

    final gradesSummary = await DatabaseHelper().getStudentGradesSummary(studentId);
    final attStr = await DatabaseHelper().getStudentAttendancePercentage(studentId);
    
    final genAveStr = gradesSummary['average'].toString();
    final double lowestGrade = (gradesSummary['lowest_grade'] as num?)?.toDouble() ?? 100.0;

    String risk = 'Low Risk';
    Color rColor = const Color(0xFF10B981); // Green
    
    if (genAveStr != 'N/A') {
      if (lowestGrade < 75) {
        risk = 'High Risk';
        rColor = Colors.red;
      } else if (lowestGrade < 80) {
        risk = 'Medium Risk';
        rColor = Colors.orange;
      }
    } else {
      risk = 'No Data';
      rColor = Colors.grey;
    }

    if (mounted) {
      setState(() {
        _generalAverage = genAveStr;
        _attendance = attStr;
        _riskStatus = risk;
        _riskColor = rColor;
      });
    }
  }

  void _resetPassword(BuildContext context, String email) {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email found for this student.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Are you sure you want to reset the password for $email to "student123"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper().updatePassword(email, 'student123');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully to "student123".')));
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _generateParentAccount(BuildContext context) async {
    final parentEmail = widget.student['parent_email']?.toString() ?? '';
    if (parentEmail.isEmpty || parentEmail == 'Not provided') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No parent email available.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Parent Account'),
        content: Text('This will create an account for $parentEmail and send them their login credentials. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F52BA)),
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (c) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final studentName = widget.student['name'] ?? 'your child';
                final parentName = widget.student['parent_name'] ?? 'Parent/Guardian';
                
                await DatabaseHelper().generateParentAccount(parentEmail, parentName, studentName);
                
                await EmailService.sendEmail(
                  toEmail: parentEmail,
                  subject: 'Parent Portal - Academic System',
                  messageText: 'Hello $parentName,<br><br>Your parent account for the Academic System has been created successfully. You can now monitor $studentName\'s academic progress.<br><br><b>Username/Email:</b> $parentEmail<br><b>Temporary Password:</b> parent123<br><br>Please log in to your account to get started and change your password.',
                );
                
                if (mounted) {
                  Navigator.pop(context); // close loading
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Parent account generated and credentials sent!'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // close loading
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text('Generate & Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _registerNfcId(BuildContext context) async {
    // Check if NFC is available
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not available on this device.')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show a dialog while waiting for scan
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan NFC ID'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 64, color: Color(0xFF0F52BA)),
            SizedBox(height: 16),
            Text('Please tap the student ID on the back of your phone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              NfcManager.instance.stopSession();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Start Session
    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
      NfcManager.instance.stopSession();
      if (!mounted) return;
      Navigator.pop(context); // Close the scanning dialog

      // Extract UID safely using platform_tags
      debugPrint('NFC Tag Data: ${tag.data}');
      
      List<int>? identifier;
      
      final mifare = MifareClassic.from(tag);
      final nfca = NfcA.from(tag);
      final ndef = Ndef.from(tag);

      identifier = mifare?.identifier ?? nfca?.identifier ?? ndef?.additionalData['identifier'] as List<int>?;
                         
      if (identifier != null && identifier.isNotEmpty) {
        // Convert to hex string
        final List<int> idBytes = List<int>.from(identifier);
        final String uid = idBytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
        
        debugPrint('Extracted UID: $uid');
        
        final studentId = widget.student['student_id']?.toString() ?? '';
        if (studentId.isNotEmpty) {
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (c) => const Center(child: CircularProgressIndicator()),
           );
           try {
             await DatabaseHelper().updateStudentNfcUid(studentId, uid);
             if (mounted) {
                setState(() {
                  widget.student['nfc_uid'] = uid;
                });
                Navigator.pop(context); // close loading
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Successfully linked NFC ID: $uid'),
                  backgroundColor: Colors.green,
                ));
             }
           } catch (e) {
             if (mounted) {
                Navigator.pop(context); // close loading
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to link NFC: $e'),
                  backgroundColor: Colors.red,
                ));
             }
           }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read ID from this tag.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F52BA),
        elevation: 0,
        title: const Text('Student Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (LoginScreen.loggedInRole == 'admin' || LoginScreen.loggedInRole == 'teacher')
            IconButton(
              icon: const Icon(Icons.nfc, color: Colors.white),
              tooltip: 'Link NFC ID',
              onPressed: () => _registerNfcId(context),
            ),
          if (LoginScreen.loggedInRole == 'admin')
            IconButton(
              icon: const Icon(Icons.lock_reset, color: Colors.white),
              tooltip: 'Reset Password',
              onPressed: () => _resetPassword(context, widget.student['email']?.toString() ?? ''),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0F52BA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 30, top: 10),
              child: Column(
                children: [
                  Hero(
                    tag: 'avatar_${student['id']}',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(Icons.person, size: 50, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    student['name'] ?? 'Unknown Student',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'LRN: ${student['student_id'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (student['nfc_uid'] != null && student['nfc_uid'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nfc, size: 14, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text(
                            'NFC Registered',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Details Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Academic Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow(Icons.school, 'Grade Level', student['grade_level'] ?? 'N/A'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.class_, 'Section', student['section'] ?? 'N/A'),
                  ]),

                  const SizedBox(height: 24),
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow(Icons.cake, 'Birthdate', student['birthdate'] ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.person_outline, 'Gender', student['gender'] ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.phone_android, 'Contact Number', student['contact_number'] ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.email_outlined, 'Student Email', student['email'] ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.home, 'Home Address', student['address'] ?? 'Not specified'),
                  ]),

                  const SizedBox(height: 24),
                  const Text(
                    'Parent/Guardian Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow(Icons.family_restroom, 'Parent Name', student['parent_name'] ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.phone, 'Contact Number', student['parent_contact'] ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoRow(Icons.email, 'Parent Email', student['parent_email'] ?? 'Not provided'),
                    if ((student['parent_email'] ?? '').toString().isNotEmpty && student['parent_email'] != 'Not provided') ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _generateParentAccount(context),
                            icon: const Icon(Icons.person_add_alt_1, size: 20),
                            label: const Text('Generate Parent Account & Send Credentials'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F52BA),
                              side: const BorderSide(color: Color(0xFF0F52BA)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 24),
                  const Text(
                    'Performance Snapshot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSnapshotCard(
                          title: 'General Average',
                          value: _generalAverage,
                          icon: Icons.grade,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSnapshotCard(
                          title: 'Attendance',
                          value: _attendance,
                          icon: Icons.calendar_today,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFullWidthSnapshotCard(
                    title: 'Risk Status',
                    value: _riskStatus,
                    icon: Icons.health_and_safety_outlined,
                    color: _riskColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0F52BA), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthSnapshotCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
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
