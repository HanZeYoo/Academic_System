import 'package:flutter/material.dart';

/// Returns up to [visibleCount] items from the start of [items].
List<T> takeVisibleItems<T>(List<T> items, int visibleCount) {
  if (items.isEmpty || visibleCount <= 0) return const [];
  final end = visibleCount > items.length ? items.length : visibleCount;
  return items.sublist(0, end);
}

/// Compact "Show More" / "Show Less" footer control for feeds and chronological logs.
class ShowMoreControls extends StatelessWidget {
  final int visibleCount;
  final int totalItems;
  final int step;
  final VoidCallback onShowMore;
  final VoidCallback? onShowLess;
  final Color accentColor;
  final EdgeInsetsGeometry margin;

  const ShowMoreControls({
    super.key,
    required this.visibleCount,
    required this.totalItems,
    required this.step,
    required this.onShowMore,
    this.onShowLess,
    this.accentColor = const Color(0xFF1664C5),
    this.margin = const EdgeInsets.only(top: 12, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= step) return const SizedBox.shrink();

    final shown = visibleCount.clamp(0, totalItems);
    final remaining = totalItems - shown;

    return Padding(
      padding: margin,
      child: Column(
        children: [
          Text(
            'Showing $shown of $totalItems',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (remaining > 0)
                OutlinedButton.icon(
                  onPressed: onShowMore,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text('Show More ($remaining remaining)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor.withValues(alpha: 0.45)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (onShowLess != null && shown > step)
                TextButton.icon(
                  onPressed: onShowLess,
                  icon: const Icon(Icons.expand_less_rounded, size: 18),
                  label: const Text('Show Less'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
