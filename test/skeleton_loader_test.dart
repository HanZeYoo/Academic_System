import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/widgets/skeleton_loader.dart';

void main() {
  Future<void> verifyPresetAtViewport(
    WidgetTester tester, {
    required Size viewportSize,
    required Widget child,
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: child),
      ),
    );
    expect(tester.takeException(), isNull);

    // Advance shimmer animation without pumpAndSettle (repeats forever).
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    // Verify clean ticker disposal when transitioning out of loading state.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  group('SkeletonLoader presets', () {
    const mobileSize = Size(360, 800);
    const desktopSize = Size(1280, 800);

    testWidgets('dashboard (banner + 3 stats + list) renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: SkeletonPresets.dashboard(showBanner: true, statCount: 3, listCount: 4),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: SkeletonPresets.dashboard(showBanner: true, statCount: 3, listCount: 4),
      );
    });

    testWidgets('dashboard (no banner + 2 stats + chart) renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: SkeletonPresets.dashboard(showBanner: false, statCount: 2, showChart: true, listCount: 3),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: SkeletonPresets.dashboard(showBanner: false, statCount: 2, showChart: true, listCount: 3),
      );
    });

    testWidgets('analytics renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: SkeletonPresets.analytics(),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: SkeletonPresets.analytics(),
      );
    });

    testWidgets('cardList (full-page with header & stats) renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: SkeletonPresets.cardList(itemCount: 5, showHeader: true, showStats: true),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: SkeletonPresets.cardList(itemCount: 5, showHeader: true, showStats: true),
      );
    });

    testWidgets('cardList with shrinkWrap: true nests safely inside SingleChildScrollView > Column', (tester) async {
      final nested = SingleChildScrollView(
        child: Column(
          children: [
            const Text('Header'),
            SkeletonPresets.cardList(itemCount: 4, shrinkWrap: true, padding: EdgeInsets.zero),
          ],
        ),
      );
      await verifyPresetAtViewport(tester, viewportSize: mobileSize, child: nested);
      await verifyPresetAtViewport(tester, viewportSize: desktopSize, child: nested);
    });

    testWidgets('formAndTable renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: SkeletonPresets.formAndTable(rowCount: 7),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: SkeletonPresets.formAndTable(rowCount: 7),
      );
    });

    testWidgets('profile renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: SkeletonPresets.profile(),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: SkeletonPresets.profile(),
      );
    });

    testWidgets('inlineField renders cleanly on mobile & desktop', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SkeletonPresets.inlineField(),
        ),
      );
      await verifyPresetAtViewport(
        tester,
        viewportSize: desktopSize,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SkeletonPresets.inlineField(),
        ),
      );
    });

    testWidgets('SkeletonBox renders static fallback cleanly when outside SkeletonShimmer', (tester) async {
      await verifyPresetAtViewport(
        tester,
        viewportSize: mobileSize,
        child: const Center(
          child: SkeletonBox(width: 120, height: 24),
        ),
      );
    });
  });
}
