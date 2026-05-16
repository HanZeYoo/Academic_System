import 'package:flutter/material.dart';

class AnnouncementManagementScreen extends StatelessWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildPostButton(),
          const SizedBox(height: 24),
          const Text(
            'Active Announcements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAnnouncementCard(
            title: 'Final Examination Schedule',
            date: 'May 16, 2026',
            audience: 'All Students & Teachers',
            status: 'Active',
            statusColor: const Color(0xFF4DC271),
            content:
                'Please be reminded that the final examinations will commence next week. Refer to the updated schedule posted in the portal.',
            isPinned: true,
          ),
          const SizedBox(height: 12),
          _buildAnnouncementCard(
            title: 'System Maintenance Downtime',
            date: 'May 14, 2026',
            audience: 'System-wide',
            status: 'Active',
            statusColor: const Color(0xFF4DC271),
            content:
                'The academic system will undergo scheduled maintenance this coming Saturday from 12:00 AM to 4:00 AM.',
            isPinned: false,
          ),
          const SizedBox(height: 24),
          const Text(
            'Scheduled / Drafts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAnnouncementCard(
            title: 'Upcoming Intramurals 2026',
            date: 'Starts: June 1, 2026',
            audience: 'All Students',
            status: 'Scheduled',
            statusColor: const Color(0xFFF6A65C),
            content:
                'Get ready for this year\'s campus intramurals! Registration for various sports events will open soon.',
            isPinned: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E66B4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.campaign, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'Manage Announcements',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E66B4),
          ),
        ),
      ],
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_alert, color: Colors.white),
        label: const Text(
          'Post New Announcement',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E66B4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard({
    required String title,
    required String date,
    required String audience,
    required String status,
    required Color statusColor,
    required String content,
    required bool isPinned,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPinned ? const Color(0xFF1E66B4) : Colors.grey.shade300,
          width: isPinned ? 2 : 1,
        ),
        boxShadow: [
          if (isPinned)
            BoxShadow(
              color: const Color(0xFF1E66B4).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned) ...[
                const Icon(Icons.push_pin, color: Color(0xFF1E66B4), size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                date,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.group, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  audience,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(Icons.edit, 'Edit', Colors.orange),
              const SizedBox(width: 16),
              _buildActionButton(Icons.delete, 'Delete', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
