import 'package:flutter/material.dart';

class ParentNotificationScreen extends StatelessWidget {
  const ParentNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search parent or student...',
              prefixIcon: const Icon(Icons.search, color: Colors.black87),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Row(
            children: const [
              Icon(Icons.campaign, color: Color(0xFF1664C5), size: 28),
              SizedBox(width: 8),
              Text(
                'Parent Notification',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.send,
                  iconBgColor: const Color(0xFFE2F6E7),
                  iconColor: const Color(0xFF00A364),
                  title: 'Notifications Sent',
                  value: '326',
                  percentage: '8.7%',
                  percentageColor: const Color(0xFF00A364),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.notifications,
                  iconBgColor: const Color(0xFFFDF0E1),
                  iconColor: const Color(0xFFE67E22),
                  title: 'Pending Alerts',
                  value: '24',
                  percentage: '14.3%',
                  percentageColor: const Color(0xFFE67E22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Send Notification',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1664C5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Status Overview
          _buildStatusOverview(),
          const SizedBox(height: 16),
          // Recent Notifications Title
          const Text(
            'Recent Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          // List
          Expanded(
            child: ListView(
              children: [
                _buildNotificationCard(
                  parentName: 'Maria Dela Cruz',
                  studentInfo: 'Student: Juan Dela Cruz • Grade 10-A',
                  reason: 'Mathematics low grade',
                  status: 'Sent',
                  statusColor: const Color(0xFF00A364),
                  statusBgColor: const Color(0xFFE2F6E7),
                ),
                _buildNotificationCard(
                  parentName: 'Pedro Santos',
                  studentInfo: 'Student: Maria Santos • Grade 9-B',
                  reason: 'Attendance warning',
                  status: 'Pending',
                  statusColor: const Color(0xFFE67E22),
                  statusBgColor: const Color(0xFFFDECDA),
                ),
                _buildNotificationCard(
                  parentName: 'Ana Cruz',
                  studentInfo: 'Student: John Paulo Cruz • Grade 8-C',
                  reason: 'English evaluation result',
                  status: 'Sent',
                  statusColor: const Color(0xFF00A364),
                  statusBgColor: const Color(0xFFE2F6E7),
                ),
                _buildNotificationCard(
                  parentName: 'Elena Gomez',
                  studentInfo: 'Student: Alyssa Gomez • Grade 9-B',
                  reason: 'Parent conference reminder',
                  status: 'Scheduled',
                  statusColor: const Color(0xFF1664C5),
                  statusBgColor: const Color(0xFFE3F0FF),
                ),
              ],
            ),
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
    required String percentage,
    required Color percentageColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 20,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward, color: percentageColor, size: 10),
                    Text(
                      percentage,
                      style: TextStyle(
                        fontSize: 9,
                        color: percentageColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        ' from last month',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBadge(
                  icon: Icons.check_circle,
                  label: 'Sent',
                  value: '248',
                  color: const Color(0xFF00A364),
                  bgColor: const Color(0xFFE2F6E7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBadge(
                  icon: Icons.access_time_filled,
                  label: 'Pending',
                  value: '24',
                  color: const Color(0xFFE67E22),
                  bgColor: const Color(0xFFFDF0E1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBadge(
                  icon: Icons.event,
                  label: 'Scheduled',
                  value: '54',
                  color: const Color(0xFF1664C5),
                  bgColor: const Color(0xFFE3F0FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required String parentName,
    required String studentInfo,
    required String reason,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: statusBgColor,
            radius: 20,
            child: Icon(Icons.person, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  studentInfo,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Color(0xFF1664C5),
                  size: 20,
                ),
                onPressed: () {},
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: Colors.black26),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.send,
                  color: Color(0xFF1664C5),
                  size: 18,
                ),
                onPressed: () {},
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
