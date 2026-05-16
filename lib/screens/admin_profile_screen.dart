import 'package:flutter/material.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with dark blue background and overlapping avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 80,
                width: double.infinity,
                color: const Color(0xFF24445A), // Dark blue from the layout
              ),
              const Positioned(
                top: 30, // Avatar overlaps the blue header and light blue body
                left: 24,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 80, color: Colors.black),
                ),
              ),
              Positioned(
                top: 90,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA1C6E6), // Light grayish blue
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
            ],
          ),
          const SizedBox(height: 70), // Spacing after overlapping avatar
          // Admin Information Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name: ', 'System Administrator'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Admin ID: ', 'ADM-2026-001'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Email: ', 'admin@school.edu.ph'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Role: ', 'Super Admin'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Department: ', 'IT Department'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 24),

          // Admin Responsibilities / Modules Card (Replaces Course Details)
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
                  const Text(
                    'System Privileges & Managed Modules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildListText(
                    '• Full Access - Student Information Management',
                  ),
                  _buildListText(
                    '• Full Access - Teacher Profiles & Assignments',
                  ),
                  _buildListText(
                    '• Read/Write - Subject & Curriculum Scheduling',
                  ),
                  _buildListText(
                    '• Read/Write - Academic Evaluations & Analytics',
                  ),
                  _buildListText(
                    '• Full Access - System Reports & Parent Notifications',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login Activity Card
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
                  const Text(
                    'Login Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'First access to site:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saturday, 24 January 2026, 8:45 PM  (110 days 18 hours)',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Last access to site:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Friday, 15 May 2026, 3:20 PM  (5 secs)',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
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
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontFamily: 'Roboto', // Inherit default font, override weights
        ),
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildListText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }
}
