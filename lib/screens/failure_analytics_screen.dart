import 'package:flutter/material.dart';

class FailureAnalyticsScreen extends StatelessWidget {
  const FailureAnalyticsScreen({super.key});

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
              hintText: 'Search student or section...',
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
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const Icon(
                    Icons.bar_chart,
                    color: Color(0xFF1664C5),
                    size: 28,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Color(0xFF1664C5),
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Text(
                'Failure Analytics',
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
                  icon: Icons.warning_amber_rounded,
                  iconBgColor: const Color(0xFFFDECEE),
                  iconColor: const Color(0xFFE74C3C),
                  title: 'At-Risk Students',
                  value: '142',
                  percentage: '12.6%',
                  percentageColor: const Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_down,
                  iconBgColor: const Color(0xFFFDECEE),
                  iconColor: const Color(0xFFE74C3C),
                  title: 'High-Risk Cases',
                  value: '58',
                  percentage: '4.1%',
                  percentageColor: const Color(0xFFE67E22),
                  isArrowOrange: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Chart section
                _buildBarChartSection(),
                const SizedBox(height: 12),
                // Risk Overview
                _buildRiskOverview(),
                const SizedBox(height: 12),
                // List of students
                _buildStudentRiskCard(
                  name: 'Daniel Reyes',
                  id: '2025-001',
                  grade: 'Grade 9-A',
                  subject: 'Mathematics',
                  average: '72%',
                  riskLevel: 'High Risk',
                  riskColor: const Color(0xFFE74C3C),
                  iconBgColor: const Color(0xFFFDECEE),
                ),
                _buildStudentRiskCard(
                  name: 'Maria Santos',
                  id: '2025-002',
                  grade: 'Grade 8-B',
                  subject: 'Science',
                  average: '75%',
                  riskLevel: 'Medium Risk',
                  riskColor: const Color(0xFFE67E22),
                  iconBgColor: const Color(0xFFFDECDA),
                ),
                _buildStudentRiskCard(
                  name: 'John Paulo Cruz',
                  id: '2025-003',
                  grade: 'Grade 10-A',
                  subject: 'English',
                  average: '70%',
                  riskLevel: 'High Risk',
                  riskColor: const Color(0xFFE74C3C),
                  iconBgColor: const Color(0xFFFDECEE),
                ),
                _buildStudentRiskCard(
                  name: 'Alyssa Gomez',
                  id: '2025-004',
                  grade: 'Grade 9-B',
                  subject: 'Social Studies',
                  average: '78%',
                  riskLevel: 'Low Risk',
                  riskColor: const Color(0xFF00A364),
                  iconBgColor: const Color(0xFFE2F6E7),
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
    bool isArrowOrange = false,
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

  Widget _buildBarChartSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Failure Rate by Subject',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120, // fixed height for chart
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-axis labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '100%',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '75%',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '50%',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '25%',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '0%',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      // Horizontal grid lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          return Container(
                            height: 1,
                            color: Colors.grey.withOpacity(0.2),
                          );
                        }),
                      ),
                      // Bars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBarItem(
                            '38%',
                            38,
                            'Math',
                            const Color(0xFF0F62D1),
                          ),
                          _buildBarItem(
                            '32%',
                            32,
                            'Science',
                            const Color(0xFF3282EA),
                          ),
                          _buildBarItem(
                            '28%',
                            28,
                            'English',
                            const Color(0xFF5BA3F5),
                          ),
                          _buildBarItem(
                            '22%',
                            22,
                            'Filipino',
                            const Color(0xFF86BFFB),
                          ),
                          _buildBarItem(
                            '18%',
                            18,
                            'Social Studies',
                            const Color(0xFFB5DAFE),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(
    String percentageLabel,
    double percentageValue,
    String subject,
    Color color,
  ) {
    // max height is container height (approx 100 for the bar area)
    double maxHeight = 100;
    double barHeight = (percentageValue / 100) * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          percentageLabel,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subject,
          style: const TextStyle(fontSize: 9, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildRiskOverview() {
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
            'Risk Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRiskBadge(
                  'High Risk',
                  '58',
                  const Color(0xFFFDECEE),
                  const Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRiskBadge(
                  'Medium Risk',
                  '67',
                  const Color(0xFFFDF0E1),
                  const Color(0xFFE67E22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRiskBadge(
                  'Low Risk',
                  '103',
                  const Color(0xFFE7F7ED),
                  const Color(0xFF00A364),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(
    String label,
    String count,
    Color bgColor,
    Color dotColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRiskCard({
    required String name,
    required String id,
    required String grade,
    required String subject,
    required String average,
    required String riskLevel,
    required Color riskColor,
    required Color iconBgColor,
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
            backgroundColor: iconBgColor,
            radius: 20,
            child: Icon(Icons.person, color: riskColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      'ID: $id',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      grade,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      'Average: $average',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
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
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF1664C5),
                  size: 20,
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
