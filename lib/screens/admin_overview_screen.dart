import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.black38),
                prefixIcon: Icon(Icons.search, color: Colors.black87),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary Cards
          _buildSummaryCard(
            title: 'Total Students',
            value: '1,248',
            percentage: '3.2%',
            icon: Icons.people,
            iconColor: const Color(0xFF1664C5),
            iconBgColor: const Color(0xFFD6EAFF),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            title: 'Total Teachers',
            value: '1,248',
            percentage: '3.2%',
            icon: Icons.person,
            iconColor: const Color(0xFF00A364),
            iconBgColor: const Color(0xFFD9F4E5),
          ),
          const SizedBox(height: 16),

          // Student Performance Trend Chart
          _buildTrendChartCard(),
          const SizedBox(height: 16),

          // Failure Rate by Subject
          _buildFailureRateCard(),
          const SizedBox(height: 16),

          // Attendance Overview
          _buildAttendanceOverviewCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String percentage,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconBgColor,
            radius: 28,
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, color: Color(0xFF00A364), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      percentage,
                      style: const TextStyle(
                        color: Color(0xFF00A364),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'from last month',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
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

  Widget _buildTrendChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Student Performance Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Text('6M', style: TextStyle(fontSize: 12, color: Colors.black87)),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black87),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 40,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.black.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.black54, fontSize: 12);
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('Dec', style: style); break;
                          case 1: text = const Text('Jan', style: style); break;
                          case 2: text = const Text('Feb', style: style); break;
                          case 3: text = const Text('Mar', style: style); break;
                          case 4: text = const Text('Apr', style: style); break;
                          case 5: text = const Text('May', style: style); break;
                          default: text = const Text('', style: style); break;
                        }
                        return SideTitleWidget(meta: meta, child: text);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 40,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: 120,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 60),
                      FlSpot(1, 100),
                      FlSpot(2, 110),
                      FlSpot(3, 120),
                      FlSpot(4, 105),
                      FlSpot(5, 125),
                    ],
                    isCurved: false,
                    color: const Color(0xFF1664C5),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1664C5).withOpacity(0.3),
                          const Color(0xFF1664C5).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 16, height: 4, color: const Color(0xFF1664C5)),
              const SizedBox(width: 8),
              const Text('Average Performance (%)', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFailureRateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Failure Rate by Subject',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Icon(Icons.info_outline, color: Colors.black38, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'This Month',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _buildFailureBar('Mathematics', 0.18, '18%', const Color(0xFF1664C5), const Color(0xFFEF4444)),
          const SizedBox(height: 12),
          _buildFailureBar('Science', 0.12, '12%', const Color(0xFF1664C5), const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildFailureBar('English', 0.08, '8%', const Color(0xFF1664C5), const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildFailureBar('Social Studies', 0.06, '6%', const Color(0xFF1664C5), const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildFailureBar('Computer Science', 0.04, '4%', const Color(0xFF1664C5), const Color(0xFF10B981)),
          const SizedBox(height: 20),
          _buildViewReportButton(),
        ],
      ),
    );
  }

  Widget _buildFailureBar(String subject, double value, String percentageStr, Color barColor, Color percentColor) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            subject,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          child: Text(
            percentageStr,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: percentColor),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Attendance Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Icon(Icons.info_outline, color: Colors.black38, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'This Month',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF10B981), // Present - Green
                            value: 92.3,
                            title: '',
                            radius: 16,
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFF59E0B), // Late - Orange
                            value: 5.1,
                            title: '',
                            radius: 16,
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFEF4444), // Absent - Red
                            value: 2.6,
                            title: '',
                            radius: 16,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            '92.3%',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Present',
                            style: TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildLegendItem(const Color(0xFF10B981), 'Present', '92.3%'),
                    const SizedBox(height: 12),
                    _buildLegendItem(const Color(0xFFF59E0B), 'Late', '5.1%'),
                    const SizedBox(height: 12),
                    _buildLegendItem(const Color(0xFFEF4444), 'Absent', '2.6%'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildViewReportButton(),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String percentage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
        Text(percentage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildViewReportButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.bar_chart, size: 18),
        label: const Text('View Full Report'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1664C5),
          backgroundColor: const Color(0xFFE6F0FA),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
