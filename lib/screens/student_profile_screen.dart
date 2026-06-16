import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database_helper.dart';

class StudentProfileScreen extends StatefulWidget {
  final String username;
  const StudentProfileScreen({super.key, required this.username});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _subjectDetails = [];
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final db = DatabaseHelper();
    final data = await db.getStudentByEmail(widget.username);
    final schedule = await db.getStudentSchedule(widget.username);

    if (mounted) {
      setState(() {
        _studentData = data;
        _subjectDetails = schedule;
        _profilePicturePath = data?['profile_picture']?.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickProfilePicture() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F4FF),
                child: Icon(Icons.camera_alt, color: Color(0xFF1E66B4)),
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F4FF),
                child: Icon(Icons.photo_library, color: Color(0xFF1E66B4)),
              ),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_profilePicturePath != null)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE8E8),
                  child: Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await DatabaseHelper().updateStudentProfilePicture(widget.username, '');
                  setState(() => _profilePicturePath = null);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (picked != null) {
      await DatabaseHelper().updateStudentProfilePicture(widget.username, picked.path);
      setState(() => _profilePicturePath = picked.path);
    }
  }

  void _showEditProfileDialog() {
    final s = _studentData ?? {};
    final nameParts = (s['name'] ?? '').toString().split(' ');
    final firstNameCtrl = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(0, nameParts.length - 1).join(' ') : s['name'] ?? '',
    );
    final lastNameCtrl = TextEditingController(text: nameParts.length > 1 ? nameParts.last : '');
    final contactCtrl = TextEditingController(text: s['contact_number'] ?? '');
    final addressCtrl = TextEditingController(text: s['address'] ?? '');
    final parentNameCtrl = TextEditingController(text: s['parent_name'] ?? '');
    final parentContactCtrl = TextEditingController(text: s['parent_contact'] ?? '');
    final parentEmailCtrl = TextEditingController(text: s['parent_email'] ?? '');
    String? selectedGender = ['Male', 'Female', 'Other'].contains(s['gender']) ? s['gender'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF224A60),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _dialogField('First Name', firstNameCtrl)),
                            const SizedBox(width: 12),
                            Expanded(child: _dialogField('Last Name', lastNameCtrl)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _dialogLabel('Gender'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedGender,
                              hint: const Text('Select gender', style: TextStyle(color: Colors.grey)),
                              items: ['Male', 'Female', 'Other'].map((g) =>
                                DropdownMenuItem(value: g, child: Text(g))
                              ).toList(),
                              onChanged: (val) => setDialogState(() => selectedGender = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _dialogField('Contact Number', contactCtrl, keyboardType: TextInputType.phone),
                        const SizedBox(height: 14),
                        _dialogField('Home Address', addressCtrl, maxLines: 2),
                        const Divider(height: 28),
                        const Text('Parent / Guardian Info',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF224A60)),
                        ),
                        const SizedBox(height: 14),
                        _dialogField('Parent Name', parentNameCtrl),
                        const SizedBox(height: 14),
                        _dialogField('Parent Contact', parentContactCtrl, keyboardType: TextInputType.phone),
                        const SizedBox(height: 14),
                        _dialogField('Parent Email', parentEmailCtrl, keyboardType: TextInputType.emailAddress),
                      ],
                    ),
                  ),
                ),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF224A60)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF224A60))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF224A60),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final fullName = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}'.trim();
                            if (fullName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name cannot be empty.')),
                              );
                              return;
                            }
                            await DatabaseHelper().updateStudent(
                              _studentData!['id'],
                              name: fullName,
                              gender: selectedGender,
                              contactNumber: contactCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              parentName: parentNameCtrl.text.trim(),
                              parentContact: parentContactCtrl.text.trim(),
                              parentEmail: parentEmailCtrl.text.trim(),
                            );
                            if (context.mounted) Navigator.pop(context);
                            await _loadProfileData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = _studentData?['name']?.toString() ?? 'Unknown Student';
    final email = _studentData?['email']?.toString() ?? widget.username;
    final studentId = _studentData?['student_id']?.toString() ?? 'N/A';
    final gradeLvl = _studentData?['grade_level']?.toString() ?? 'N/A';

    return SingleChildScrollView(
      child: Container(
        color: const Color(0xFFCBEAFB),
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────────────────────────────────────────────
            SizedBox(
              height: 160,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Dark blue top bar (full width)
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: const Color(0xFF224A60),
                  ),
                  // Tappable Avatar
                  Positioned(
                    top: 30,
                    left: 24,
                    child: GestureDetector(
                      onTap: _pickProfilePicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white,
                            backgroundImage: _profilePicturePath != null && _profilePicturePath!.isNotEmpty
                                ? FileImage(File(_profilePicturePath!))
                                : null,
                            child: _profilePicturePath == null || _profilePicturePath!.isEmpty
                                ? const Icon(Icons.person, size: 90, color: Colors.black)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E66B4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Edit Profile Button
                  Positioned(
                    top: 110,
                    right: 24,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showEditProfileDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA1C6E6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Student Info ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Name: ', name),
                        const SizedBox(height: 12),
                        _buildInfoRow('LRN: ', studentId),
                        const SizedBox(height: 12),
                        _buildInfoRow('Email: ', email),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildInfoRow('Grade Lvl: ', gradeLvl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 24),

            // ─── Subject Details ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subject details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_subjectDetails.isEmpty)
                      const Text('No subjects assigned yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                    else
                      ..._subjectDetails.map((c) => _buildListText(
                        '${c['subject_code']} - ${c['subject_name']}',
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Login Activity ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Login Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text('First access to site:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    SizedBox(height: 4),
                    Text('Saturday, 24 January 2026, 8:45 PM (110 days 18 hours)',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    SizedBox(height: 24),
                    Text('Last access to site:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    SizedBox(height: 4),
                    Text('Friday, 15 May 2026, 3:20 PM (5 secs)',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'Roboto'),
        children: [
          TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildListText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
    );
  }

  Widget _dialogField(String label, TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF224A60)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF224A60)));
  }
}
