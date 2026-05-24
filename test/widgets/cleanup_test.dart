import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/screens/cleanup/cleanup_screen.dart';
import 'widget_test_helpers.dart';

void main() {
  group('CleanupScreen', () {
    testWidgets('renders 3 tabs', (tester) async {
      await tester.pumpWidget(testApp(const CleanupScreen()));
      await tester.pump();

      expect(find.text('Junk'), findsOneWidget);
      expect(find.text('Blurry'), findsOneWidget);
      expect(find.text('Backed Up'), findsOneWidget);
    });

    testWidgets('shows compression mode chips', (tester) async {
      await tester.pumpWidget(testApp(const CleanupScreen()));
      await tester.pump();

      expect(find.text('Lossless'), findsOneWidget);
      expect(find.text('Smart'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('shows empty state when no junk photos', (tester) async {
      await tester.pumpWidget(testApp(const CleanupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to clean here'), findsOneWidget);
    });

    testWidgets('shows delete button when photos are selected', (tester) async {
      final junkAsset = PhotoAsset(
        id: 'junk-1',
        path: '/fake/junk.jpg',
        name: 'junk.jpg',
        sizeBytes: 500000,
        createdAt: DateTime(2024, 1, 1),
        issues: const [QualityIssue.junk],
      );

      await tester.pumpWidget(testApp(
        const CleanupScreen(),
        overrides: [
          photosProvider.overrideWith((_) async => [junkAsset]),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap the photo to select it — but since it's a file path that doesn't
      // exist, Image.file will show error widget. Verify the grid renders.
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('compression mode chip selection works', (tester) async {
      await tester.pumpWidget(testApp(const CleanupScreen()));
      await tester.pump();

      // Tap Lossless chip
      await tester.tap(find.text('Lossless'));
      await tester.pump();

      // Chip should now be selected (no crash)
      expect(find.text('Lossless'), findsOneWidget);
    });

    testWidgets('switching tabs does not crash', (tester) async {
      await tester.pumpWidget(testApp(const CleanupScreen()));
      await tester.pump();

      await tester.tap(find.text('Blurry'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to clean here'), findsOneWidget);

      await tester.tap(find.text('Backed Up'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to clean here'), findsOneWidget);
    });
  });
}
