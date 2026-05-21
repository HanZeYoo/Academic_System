import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database_helper.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String username;
  const TeacherProfileScreen({super.key, required this.username});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _teacherData;
  List<Map<String, dynamic>> _assignedClasses = [];
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final db = DatabaseHelper();
    final data = await db.getTeacherByEmail(widget.username);
    if (data != null) {
      final name = data['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        _assignedClasses = await db.getSubjectClassesByTeacher(name);
      }
    }
    if (mounted) {
      setState(() {
        _teacherData = data;
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
            const Text('Change Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F4FF),
                child: Icon(Icons.camera_alt, color: Color(0xFF3383B3)),
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F4FF),
                child: Icon(Icons.photo_library, color: Color(0xFF3383B3)),
              ),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_profilePicturePath != null && _profilePicturePath!.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE8E8),
                  child: Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await DatabaseHelper().updateTeacherProfilePicture(widget.username, '');
                  setState(() => _profilePicturePath = null);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final XFile? picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked != null) {
      await DatabaseHelper().updateTeacherProfilePicture(widget.username, picked.path);
      setState(() => _profilePicturePath = picked.path);
    }
  }

  void _showEditDialog() {
    final s = _teacherData ?? {};
    final nameCtrl = TextEditingController(text: s['name'] ?? '');
    final contactCtrl = TextEditingController(text: s['contact_number'] ?? '');
    final addressCtrl = TextEditingController(text: s['address'] ?? '');
    final specializationCtrl = TextEditingController(text: s['specialization'] ?? '');
    String? selectedGender = ['Male', 'Female', 'Other'].contains(s['gender']) ? s['gender'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3383B3),
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
                        child: Text('Edit Profile',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogField('Full Name', nameCtrl),
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
                        _dialogField('Address', addressCtrl, maxLines: 2),
                        const SizedBox(height: 14),
                        _dialogField('Specialization', specializationCtrl),
                      ],
                    ),
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3383B3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF3383B3))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3383B3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            await DatabaseHelper().updateTeacher(
                              _teacherData!['id'],
                              name: nameCtrl.text.trim(),
                              gender: selectedGender,
                              contactNumber: contactCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              specialization: specializationCtrl.text.trim(),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final name = _teacherData?['name']?.toString() ?? 'Unknown Teacher';
    final email = _teacherData?['email']?.toString() ?? widget.username;
    final department = _teacherData?['department']?.toString() ?? 'N/A';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───────────────────────────────────────────────
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                Container(height: 160, width: double.infinity, color: const Color(0xFF3383B3)),
                // Avatar
                Positioned(
                  top: 30, left: 24,
                  child: GestureDetector(
                    onTap: _pickProfilePicture,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: _profilePicturePath != null && _profilePicturePath!.isNotEmpty
                              ? FileImage(File(_profilePicturePath!)) : null,
                          child: _profilePicturePath == null || _profilePicturePath!.isEmpty
                              ? const Icon(Icons.person, size: 80, color: Color(0xFF3383B3)) : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: Color(0xFF224A60), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Edit Profile Button
                Positioned(
                  top: 110, right: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showEditDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA1C6E6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Edit Profile',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Teacher Info ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name: ', name),
                      const SizedBox(height: 12),
                      _buildInfoRow('Email: ', email),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Role: ', 'Teacher'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Department: ', department),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 24),

          // ─── Assigned Classes ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Classes & Subjects',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_assignedClasses.isEmpty)
                    const Text('No classes assigned yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    ..._assignedClasses.map((c) => _buildListText(
                      '• ${c['subject_name']} (${c['grade_level']} - ${c['section_name']})'
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Login Activity ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Status:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Active and verified',
                    style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    );
  }

  Widget _dialogField(String label, TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text, int maxLines = 1,
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3383B3))),
          ),
        ),
      ],
    );
  }

  Widget _dialogLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3383B3)));
  }
}
