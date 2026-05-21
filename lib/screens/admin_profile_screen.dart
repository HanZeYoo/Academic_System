import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminProfileScreen extends StatefulWidget {
  final String username;
  const AdminProfileScreen({super.key, this.username = 'admin'});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  String? _profilePicturePath;

  // Editable admin info (in-memory for admin since there's no admin table)
  String _name = 'System Administrator';
  String _adminId = 'ADM-2026-001';
  String _email = 'admin@school.edu.ph';
  String _department = 'IT Department';
  String _contact = '';
  String _address = '';

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
                child: Icon(Icons.camera_alt, color: Color(0xFF24445A)),
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F4FF),
                child: Icon(Icons.photo_library, color: Color(0xFF24445A)),
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
                onTap: () {
                  setState(() => _profilePicturePath = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final XFile? picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked != null) {
      setState(() => _profilePicturePath = picked.path);
    }
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _name);
    final adminIdCtrl = TextEditingController(text: _adminId);
    final emailCtrl = TextEditingController(text: _email);
    final departmentCtrl = TextEditingController(text: _department);
    final contactCtrl = TextEditingController(text: _contact);
    final addressCtrl = TextEditingController(text: _address);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF24445A),
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
                      _dialogField('Admin ID', adminIdCtrl),
                      const SizedBox(height: 14),
                      _dialogField('Email', emailCtrl, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _dialogField('Department', departmentCtrl),
                      const SizedBox(height: 14),
                      _dialogField('Contact Number', contactCtrl, keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),
                      _dialogField('Address', addressCtrl, maxLines: 2),
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
                          side: const BorderSide(color: Color(0xFF24445A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF24445A))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF24445A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            _name = nameCtrl.text.trim().isEmpty ? _name : nameCtrl.text.trim();
                            _adminId = adminIdCtrl.text.trim().isEmpty ? _adminId : adminIdCtrl.text.trim();
                            _email = emailCtrl.text.trim().isEmpty ? _email : emailCtrl.text.trim();
                            _department = departmentCtrl.text.trim().isEmpty ? _department : departmentCtrl.text.trim();
                            _contact = contactCtrl.text.trim();
                            _address = addressCtrl.text.trim();
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────────
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                Container(height: 160, width: double.infinity, color: const Color(0xFF24445A)),
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
                              ? const Icon(Icons.person, size: 80, color: Colors.black) : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: Color(0xFF1E66B4), shape: BoxShape.circle),
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

          // ─── Admin Info ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name: ', _name),
                      const SizedBox(height: 12),
                      _buildInfoRow('Admin ID: ', _adminId),
                      const SizedBox(height: 12),
                      _buildInfoRow('Email: ', _email),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Role: ', 'Super Admin'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Department: ', _department),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 24),

          // ─── Privileges Card ─────────────────────────────────────
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
                  const Text('System Privileges & Managed Modules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildListText('• Full Access - Student Information Management'),
                  _buildListText('• Full Access - Teacher Profiles & Assignments'),
                  _buildListText('• Read/Write - Subject & Curriculum Scheduling'),
                  _buildListText('• Read/Write - Academic Evaluations & Analytics'),
                  _buildListText('• Full Access - System Reports & Parent Notifications'),
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
                  Text('Login Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('First access to site:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Saturday, 24 January 2026, 8:45 PM  (110 days 18 hours)',
                    style: TextStyle(fontSize: 13, color: Colors.black87)),
                  SizedBox(height: 24),
                  Text('Last access to site:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Friday, 15 May 2026, 3:20 PM  (5 secs)',
                    style: TextStyle(fontSize: 13, color: Colors.black87)),
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
      padding: const EdgeInsets.symmetric(vertical: 2.0),
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
              borderSide: const BorderSide(color: Color(0xFF24445A))),
          ),
        ),
      ],
    );
  }

  Widget _dialogLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF24445A)));
  }
}
