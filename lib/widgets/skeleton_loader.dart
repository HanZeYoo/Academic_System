import 'package:flutter/material.dart';

class _ShimmerNotifier extends InheritedNotifier<AnimationController> {
  const _ShimmerNotifier({
    required AnimationController super.notifier,
    required super.child,
  });

  static AnimationController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerNotifier>()?.notifier;
  }
}

/// Drives a single shared shimmer animation across all descendant [SkeletonBox] widgets.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerNotifier(
      notifier: _controller,
      child: widget.child,
    );
  }
}

/// Animated skeleton placeholder block tuned to NotifyED's airy blue palette.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  static const Color _baseColor = Color(0xFFE2ECF5);
  static const Color _highlightColor = Color(0xFFF5F9FD);

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final controller = _ShimmerNotifier.of(context);
    final BorderRadius? effectiveRadius =
        shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius);

    if (controller == null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: _baseColor,
          shape: shape,
          borderRadius: effectiveRadius,
        ),
      );
    }

    final slide = (controller.value * 2.6) - 1.3;
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: effectiveRadius,
        gradient: LinearGradient(
          begin: Alignment(-1.0 + slide, -0.25),
          end: Alignment(1.0 + slide, 0.25),
          colors: const [_baseColor, _highlightColor, _baseColor],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const _SkeletonCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E4663),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Layout-matched skeleton presets for NotifyED screens.
class SkeletonPresets {
  SkeletonPresets._();

  static Widget dashboard({
    bool showBanner = true,
    int statCount = 3,
    int listCount = 4,
    bool showChart = false,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBanner) ...[
              _SkeletonCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const SkeletonBox(
                      width: 48,
                      height: 48,
                      shape: BoxShape.circle,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 160, height: 18, borderRadius: 6),
                          SizedBox(height: 8),
                          SkeletonBox(width: 210, height: 13, borderRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const SkeletonBox(width: 74, height: 26, borderRadius: 13),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildResponsiveStatGrid(statCount),
            const SizedBox(height: 18),
            if (showChart) ...[
              _buildChartCard(),
              const SizedBox(height: 18),
            ],
            const SkeletonBox(width: 150, height: 16, borderRadius: 6),
            const SizedBox(height: 12),
            ...List.generate(
              listCount,
              (index) => _SkeletonCard(
                margin: EdgeInsets.only(bottom: index == listCount - 1 ? 0 : 12),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const SkeletonBox(width: 42, height: 42, borderRadius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: double.infinity, height: 14, borderRadius: 6),
                          SizedBox(height: 8),
                          SkeletonBox(width: 140, height: 11, borderRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SkeletonBox(width: 58, height: 26, borderRadius: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget analytics({
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 210, height: 22, borderRadius: 7),
            const SizedBox(height: 6),
            const SkeletonBox(width: 160, height: 13, borderRadius: 6),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: _SkeletonCard(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    borderRadius: 12,
                    child: SkeletonBox(height: 18, borderRadius: 6),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SkeletonCard(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    borderRadius: 12,
                    child: SkeletonBox(height: 18, borderRadius: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResponsiveStatGrid(4),
            const SizedBox(height: 18),
            _buildChartCard(),
            const SizedBox(height: 18),
            const SkeletonBox(width: 170, height: 16, borderRadius: 6),
            const SizedBox(height: 12),
            ...List.generate(
              5,
              (index) => _SkeletonCard(
                margin: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SkeletonBox(
                          width: 40,
                          height: 40,
                          shape: BoxShape.circle,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonBox(width: double.infinity, height: 14, borderRadius: 6),
                              SizedBox(height: 6),
                              SkeletonBox(width: 120, height: 11, borderRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const SkeletonBox(width: 64, height: 24, borderRadius: 12),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Expanded(child: SkeletonBox(height: 24, borderRadius: 8)),
                        SizedBox(width: 8),
                        Expanded(child: SkeletonBox(height: 24, borderRadius: 8)),
                        SizedBox(width: 8),
                        Expanded(child: SkeletonBox(height: 24, borderRadius: 8)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget cardList({
    int itemCount = 6,
    bool showHeader = false,
    bool showStats = false,
    bool shrinkWrap = false,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final List<Widget> children = [
      if (showHeader) ...[
        Row(
          children: [
            const SkeletonBox(width: 42, height: 42, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 180, height: 20, borderRadius: 7),
                  SizedBox(height: 6),
                  SkeletonBox(width: 230, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
      if (showStats) ...[
        Row(
          children: List.generate(3, (idx) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: idx == 2 ? 0 : 10),
                child: _SkeletonCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 28, height: 28, borderRadius: 8),
                      SizedBox(height: 10),
                      SkeletonBox(width: 44, height: 18, borderRadius: 6),
                      SizedBox(height: 6),
                      SkeletonBox(width: double.infinity, height: 10, borderRadius: 5),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
      ],
      ...List.generate(
        itemCount,
        (index) => _SkeletonCard(
          margin: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SkeletonBox(
                width: 44,
                height: 44,
                shape: BoxShape.circle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: double.infinity, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 150, height: 11, borderRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const SkeletonBox(width: 62, height: 26, borderRadius: 13),
            ],
          ),
        ),
      ),
    ];

    if (shrinkWrap) {
      return SkeletonShimmer(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
    }

    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  static Widget formAndTable({
    int rowCount = 7,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Expanded(
                  child: _SkeletonCard(
                    padding: EdgeInsets.all(14),
                    borderRadius: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 70, height: 11, borderRadius: 5),
                        SizedBox(height: 8),
                        SkeletonBox(height: 20, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SkeletonCard(
                    padding: EdgeInsets.all(14),
                    borderRadius: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 70, height: 11, borderRadius: 5),
                        SizedBox(height: 8),
                        SkeletonBox(height: 20, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _SkeletonCard(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SkeletonBox(width: 38, height: 38, borderRadius: 10),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 150, height: 15, borderRadius: 6),
                        SizedBox(height: 7),
                        SkeletonBox(width: 210, height: 11, borderRadius: 5),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  SkeletonBox(width: 68, height: 34, borderRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SkeletonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(rowCount, (index) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          const SkeletonBox(
                            width: 36,
                            height: 36,
                            shape: BoxShape.circle,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SkeletonBox(width: double.infinity, height: 14, borderRadius: 6),
                                SizedBox(height: 6),
                                SkeletonBox(width: 100, height: 11, borderRadius: 5),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const SkeletonBox(width: 64, height: 36, borderRadius: 10),
                        ],
                      ),
                      if (index < rowCount - 1)
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget profile({
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          children: [
            _SkeletonCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: const [
                  SkeletonBox(width: 84, height: 84, shape: BoxShape.circle),
                  SizedBox(height: 14),
                  SkeletonBox(width: 160, height: 18, borderRadius: 6),
                  SizedBox(height: 8),
                  SkeletonBox(width: 200, height: 13, borderRadius: 6),
                  SizedBox(height: 12),
                  SkeletonBox(width: 110, height: 24, borderRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileSectionCard(),
            const SizedBox(height: 16),
            _buildProfileSectionCard(),
          ],
        ),
      ),
    );
  }

  static Widget inlineField({
    double height = 52,
    double borderRadius = 12,
  }) {
    return SkeletonShimmer(
      child: SkeletonBox(
        width: double.infinity,
        height: height,
        borderRadius: borderRadius,
      ),
    );
  }

  static Widget _buildProfileSectionCard() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 140, height: 16, borderRadius: 6),
          const SizedBox(height: 16),
          ...List.generate(4, (idx) {
            return Padding(
              padding: EdgeInsets.only(bottom: idx == 3 ? 0 : 12),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: SkeletonBox(height: 12, borderRadius: 5)),
                  SizedBox(width: 16),
                  Expanded(flex: 3, child: SkeletonBox(height: 14, borderRadius: 6)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Widget _buildChartCard() {
    const heights = [62.0, 95.0, 78.0, 114.0, 88.0, 102.0];
    return _SkeletonCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 180, height: 16, borderRadius: 6),
          const SizedBox(height: 6),
          const SkeletonBox(width: 120, height: 11, borderRadius: 5),
          const SizedBox(height: 18),
          SizedBox(
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: heights
                  .map(
                    (h) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: SkeletonBox(height: h, borderRadius: 8),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildResponsiveStatGrid(int count) {
    Widget buildStatCard() {
      return const _SkeletonCard(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 36, height: 36, borderRadius: 10),
            SizedBox(height: 12),
            SkeletonBox(width: 64, height: 22, borderRadius: 6),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 11, borderRadius: 5),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            children: List.generate(count, (idx) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx == count - 1 ? 0 : 12),
                  child: buildStatCard(),
                ),
              );
            }),
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < count; i += 2) {
          final hasSecond = i + 1 < count;
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < count ? 12 : 0),
              child: Row(
                children: [
                  Expanded(child: buildStatCard()),
                  if (hasSecond) ...[
                    const SizedBox(width: 12),
                    Expanded(child: buildStatCard()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}
