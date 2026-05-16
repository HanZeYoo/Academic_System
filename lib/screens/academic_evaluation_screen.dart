import 'package:flutter/material.dart';

class AcademicEvaluationScreen extends StatelessWidget {
  const AcademicEvaluationScreen({super.key});

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
              hintText: 'Search evaluations...',
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
              Icon(Icons.assignment, color: Color(0xFF1664C5)),
              SizedBox(width: 8),
              Text(
                'Academic & Evaluation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment_turned_in,
                  iconBgColor: const Color(0xFFE3F0FF),
                  iconColor: const Color(0xFF1664C5),
                  title: 'Total Evaluations',
                  value: '128',
                  percentage: '4.2%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.insert_chart_outlined,
                  iconBgColor: const Color(0xFFE2F6E7),
                  iconColor: const Color(0xFF00A364),
                  title: 'Average Performance',
                  value: '88.4%',
                  percentage: '3.8%',
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
                'Add Evaluation',
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
          // List
          Expanded(
            child: ListView(
              children: [
                _buildEvaluationCard(
                  icon: Icons.calculate,
                  iconColor: const Color(0xFF1664C5),
                  iconBgColor: const Color(0xFFE3F0FF),
                  title: 'Mathematics Evaluation',
                  subtitle1: 'Grade 10-A • Quarter 2',
                  subtitle2: 'Average: 89%',
                  status: 'Completed',
                  isCompleted: true,
                ),
                _buildEvaluationCard(
                  icon: Icons.science,
                  iconColor: const Color(0xFF00A364),
                  iconBgColor: const Color(0xFFE2F6E7),
                  title: 'Science Evaluation',
                  subtitle1: 'Grade 9-B • Quarter 2',
                  subtitle2: 'Average: 86%',
                  status: 'Completed',
                  isCompleted: true,
                ),
                _buildEvaluationCard(
                  icon: Icons.menu_book,
                  iconColor: const Color(0xFFE67E22),
                  iconBgColor: const Color(0xFFFDECDA),
                  title: 'English Evaluation',
                  subtitle1: 'Grade 8-C • Quarter 2',
                  subtitle2: 'Average: 78%',
                  status: 'Ongoing',
                  isCompleted: false,
                ),
                _buildEvaluationCard(
                  icon: Icons.history_edu,
                  iconColor: const Color(0xFF8E44AD),
                  iconBgColor: const Color(0xFFF4E5FA),
                  title: 'Filipino Evaluation',
                  subtitle1: 'Grade 10-B • Quarter 2',
                  subtitle2: 'Average: 91%',
                  status: 'Completed',
                  isCompleted: true,
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
                    fontSize: 9,
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
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.green,
                      size: 10,
                    ),
                    Text(
                      percentage,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
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

  Widget _buildEvaluationCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle1,
    required String subtitle2,
    required String status,
    required bool isCompleted,
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
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 26,
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle1,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle2,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFE2F6E7)
                        : const Color(0xFFFDECDA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF00A364)
                              : const Color(0xFFE67E22),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: isCompleted
                              ? const Color(0xFF00A364)
                              : const Color(0xFFE67E22),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Color(0xFF1664C5),
              size: 20,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF1664C5),
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
