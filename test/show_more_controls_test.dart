import 'package:academic_system/widgets/show_more_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('takeVisibleItems', () {
    test('slices up to visibleCount and handles edge cases safely', () {
      final items = [1, 2, 3, 4, 5];
      expect(takeVisibleItems(items, 3), [1, 2, 3]);
      expect(takeVisibleItems(items, 10), [1, 2, 3, 4, 5]);
      expect(takeVisibleItems(items, 0), isEmpty);
      expect(takeVisibleItems<int>([], 5), isEmpty);
    });
  });

  group('ShowMoreControls widget', () {
    testWidgets('hides when totalItems <= step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShowMoreControls(
              visibleCount: 10,
              totalItems: 10,
              step: 10,
              onShowMore: () {},
              onShowLess: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Showing'), findsNothing);
      expect(find.textContaining('Show More'), findsNothing);
      expect(find.text('Show Less'), findsNothing);
    });

    testWidgets('shows remaining count and triggers onShowMore', (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShowMoreControls(
              visibleCount: 10,
              totalItems: 25,
              step: 10,
              onShowMore: () => expanded = true,
              onShowLess: () {},
            ),
          ),
        ),
      );

      expect(find.text('Showing 10 of 25'), findsOneWidget);
      expect(find.text('Show More (15 remaining)'), findsOneWidget);
      expect(find.text('Show Less'), findsNothing);

      await tester.tap(find.text('Show More (15 remaining)'));
      expect(expanded, isTrue);
    });

    testWidgets('shows Show Less when expanded past step and triggers callback', (tester) async {
      var collapsed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShowMoreControls(
              visibleCount: 25,
              totalItems: 25,
              step: 10,
              onShowMore: () {},
              onShowLess: () => collapsed = true,
            ),
          ),
        ),
      );

      expect(find.text('Showing 25 of 25'), findsOneWidget);
      expect(find.textContaining('Show More'), findsNothing);
      expect(find.text('Show Less'), findsOneWidget);

      await tester.tap(find.text('Show Less'));
      expect(collapsed, isTrue);
    });
  });
}
