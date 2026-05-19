import 'package:flutter/material.dart';

class StudentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${student['student_id'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
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
                          title: 'Current GPA',
                          value: '88.5',
                          icon: Icons.grade,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSnapshotCard(
                          title: 'Attendance',
                          value: '95%',
                          icon: Icons.calendar_today,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFullWidthSnapshotCard(
                    title: 'Risk Status',
                    value: 'Low Risk',
                    icon: Icons.health_and_safety_outlined,
                    color: const Color(0xFF10B981), // Green for low risk
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
            color: Colors.black.withOpacity(0.03),
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
            color: Colors.black.withOpacity(0.03),
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
              color: color.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.03),
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
              color: color.withOpacity(0.1),
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
