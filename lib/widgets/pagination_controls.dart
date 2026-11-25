import 'package:flutter/material.dart';

/// Returns the sublist of [items] for a 1-based [page] and [pageSize],
/// clamping [page] safely within `[1, totalPages]`.
List<T> paginateList<T>(List<T> items, int page, int pageSize) {
  if (items.isEmpty || pageSize <= 0) return const [];
  final totalPages = (items.length / pageSize).ceil();
  final safePage = page.clamp(1, totalPages);
  final start = (safePage - 1) * pageSize;
  final end = (start + pageSize > items.length) ? items.length : start + pageSize;
  return items.sublist(start, end);
}

/// Computes the clamped 1-based page number for [items] and [pageSize].
int clampPage(int page, int totalItems, int pageSize) {
  if (totalItems <= 0 || pageSize <= 0) return 1;
  final totalPages = (totalItems / pageSize).ceil();
  return page.clamp(1, totalPages);
}

/// Compact, overflow-safe pagination bar for lists and tables.
class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final Color accentColor;
  final EdgeInsetsGeometry margin;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.accentColor = const Color(0xFF1664C5),
    this.margin = const EdgeInsets.only(top: 14, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= pageSize) return const SizedBox.shrink();

    final totalPages = (totalItems / pageSize).ceil();
    final safePage = currentPage.clamp(1, totalPages);
    final startItem = (safePage - 1) * pageSize + 1;
    final endItem = (safePage * pageSize > totalItems) ? totalItems : safePage * pageSize;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            'Showing $startItem–$endItem of $totalItems',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                label: 'Prev',
                enabled: safePage > 1,
                accentColor: accentColor,
                onTap: () => onPageChanged(safePage - 1),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $safePage of $totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                label: 'Next',
                iconAfter: true,
                enabled: safePage < totalPages,
                accentColor: accentColor,
                onTap: () => onPageChanged(safePage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool iconAfter;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.accentColor,
    required this.onTap,
    this.iconAfter = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? accentColor : const Color(0xFF94A3B8);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? accentColor.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!iconAfter) Icon(icon, size: 16, color: fg),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            if (iconAfter) Icon(icon, size: 16, color: fg),
          ],
        ),
      ),
    );
  }
}
