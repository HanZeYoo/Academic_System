import 'package:flutter/material.dart';
import '../database_helper.dart';

class SchoolYearRolloverScreen extends StatefulWidget {
  const SchoolYearRolloverScreen({super.key});

  @override
  State<SchoolYearRolloverScreen> createState() => _SchoolYearRolloverScreenState();
}

class _SchoolYearRolloverScreenState extends State<SchoolYearRolloverScreen> {
  bool _isLoadingPreview = false;
  bool _isRollingOver = false;
  bool _previewLoaded = false;

  String _currentSchoolYear = '';
  String _newSchoolYear = '';
  List<Map<String, dynamic>> _previewData = [];

  final TextEditingController _confirmController = TextEditingController();
  bool _confirmTyped = false;
  String _rolloverProgress = '';

  static const String _confirmPhrase = 'CONFIRM ROLLOVER';

  @override
  void initState() {
    super.initState();
    _loadCurrentYear();
    _confirmController.addListener(() {
      setState(() => _confirmTyped = _confirmController.text.trim() == _confirmPhrase);
    });
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentYear() async {
    final year = await DatabaseHelper().getActiveSchoolYear();
    setState(() {
      _currentSchoolYear = year;
      _newSchoolYear = _computeNextYear(year);
    });
  }

  String _computeNextYear(String current) {
    final regex = RegExp(r'(\d{4})-(\d{4})');
    final match = regex.firstMatch(current);
    if (match != null) {
      final start = int.tryParse(match.group(1)!) ?? 2025;
      return 'S.Y. ${start + 1}-${start + 2}';
    }
    return 'S.Y. 2026-2027';
  }

  Future<void> _loadPreview() async {
    setState(() { _isLoadingPreview = true; _previewLoaded = false; });
    try {
      final data = await DatabaseHelper().previewRollover();
      setState(() { _previewData = data; _previewLoaded = true; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoadingPreview = false);
  }

  Future<void> _executeRollover() async {
    if (!_confirmTyped) return;
    setState(() { _isRollingOver = true; _rolloverProgress = 'Starting rollover...'; });
    try {
      setState(() => _rolloverProgress = 'Creating new school year $_newSchoolYear...');
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _rolloverProgress = 'Processing ${_previewData.length} students...');
      await DatabaseHelper().performYearEndRollover(
        newSchoolYear: _newSchoolYear,
        previewData: _previewData,
      );
      setState(() => _rolloverProgress = 'Finalizing...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() { _isRollingOver = false; _rolloverProgress = ''; });
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() { _isRollingOver = false; _rolloverProgress = ''; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rollover failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
              ),
              const SizedBox(height: 16),
              const Text('Rollover Complete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'School Year updated to $_newSchoolYear.\nProceed to Enrollment Management to enroll returning students.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E66B4), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Promoted': return Colors.green;
      case 'Graduated': return const Color(0xFF6A0DAD);
      case 'Conditional': return Colors.orange;
      case 'Retained': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('End of School Year Rollover',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF1E66B4),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isRollingOver ? _buildProgressView() : _buildContent(),
    );
  }

  Widget _buildProgressView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF1E66B4), strokeWidth: 4),
          const SizedBox(height: 24),
          Text(_rolloverProgress, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E66B4))),
          const SizedBox(height: 8),
          const Text('Please do not close this screen.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Important Warning', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      const SizedBox(height: 4),
                      const Text(
                        'This process will promote/retain all active students and create a new School Year. '
                        'Recommended to backup Supabase first. This action cannot be undone.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('School Year Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildInfoTile('Current', _currentSchoolYear, Icons.school, Colors.blue)),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfoTile('New Year', _newSchoolYear, Icons.update, Colors.green)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingPreview ? null : _loadPreview,
                  icon: _isLoadingPreview
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.preview, size: 18),
                  label: Text(_isLoadingPreview ? 'Loading Preview...' : 'Generate Preview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E66B4), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          )),
          const SizedBox(height: 16),
          if (_previewLoaded) ...[
            _buildCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Promotion Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${_previewData.length} students', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Computed from scores. No scores = shown as N/A.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),
                _buildStatusSummary(),
                const SizedBox(height: 12),
                const Divider(),
                _buildTableHeader(),
                const Divider(height: 1),
                ..._previewData.map((p) => _buildPreviewRow(p)),
              ],
            )),
            const SizedBox(height: 16),
            _buildCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Text('Confirmation Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Type "" to enable the rollover button.', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  decoration: InputDecoration(
                    hintText: _confirmPhrase,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _confirmTyped ? Colors.green : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _confirmTyped ? Colors.green : Colors.grey.shade300, width: _confirmTyped ? 2 : 1),
                    ),
                    suffixIcon: _confirmTyped ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmTyped ? _executeRollover : null,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Execute Year-End Rollover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _confirmTyped ? Colors.red.shade600 : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    final counts = <String, int>{};
    for (final p in _previewData) {
      final s = p['promotion_status'] as String;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: counts.entries.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(e.key).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _statusColor(e.key).withValues(alpha: 0.3)),
        ),
        child: Text('${e.key}: ${e.value}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _statusColor(e.key))),
      )).toList(),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          Expanded(flex: 2, child: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          Expanded(flex: 2, child: Text('Avg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          Expanded(flex: 2, child: Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(Map<String, dynamic> preview) {
    final status = preview['promotion_status'] as String;
    final avg = (preview['average_grade'] as num?)?.toDouble() ?? 0;
    final hasScores = preview['has_scores'] as bool? ?? false;
    final color = _statusColor(status);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(preview['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(preview['grade_level'] ?? '', style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(
              hasScores ? avg.toStringAsFixed(1) : 'N/A',
              style: TextStyle(fontSize: 12, color: hasScores ? (avg >= 75 ? Colors.green.shade700 : Colors.red.shade700) : Colors.grey, fontWeight: FontWeight.w600),
            )),
            Expanded(flex: 2, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            )),
            Expanded(flex: 2, child: Text(preview['next_grade_level'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
            ],
          )),
        ],
      ),
    );
  }
}
