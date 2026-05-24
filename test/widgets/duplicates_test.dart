import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/screens/duplicates/duplicates_screen.dart';
import 'widget_test_helpers.dart';

void main() {
  group('DuplicatesScreen', () {
    testWidgets('shows empty state when no duplicates', (tester) async {
      await tester.pumpWidget(testApp(const DuplicatesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No duplicates found'), findsOneWidget);
      expect(find.text('Run a scan to detect duplicates'), findsOneWidget);
    });

    testWidgets('shows summary banner when duplicates exist', (tester) async {
      final assets = [
        stubAsset('dup-a'),
        stubAsset('dup-b'),
      ];
      final group = DuplicateGroup(
        groupId: 'g1',
        assets: assets,
        similarity: 0.95,
      );

      await tester.pumpWidget(testApp(
        const DuplicatesScreen(),
        overrides: [
          duplicatesProvider.overrideWith((_) async => [group]),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 duplicate group'), findsOneWidget);
      expect(find.textContaining('wasted'), findsOneWidget);
    });

    testWidgets('shows similarity percentage', (tester) async {
      final group = DuplicateGroup(
        groupId: 'g1',
        assets: [stubAsset('a'), stubAsset('b')],
        similarity: 0.95,
      );

      await tester.pumpWidget(testApp(
        const DuplicatesScreen(),
        overrides: [
          duplicatesProvider.overrideWith((_) async => [group]),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('95% match'), findsOneWidget);
    });

    testWidgets('shows Auto-select button per group', (tester) async {
      final group = DuplicateGroup(
        groupId: 'g1',
        assets: [stubAsset('a'), stubAsset('b')],
        similarity: 0.9,
      );

      await tester.pumpWidget(testApp(
        const DuplicatesScreen(),
        overrides: [
          duplicatesProvider.overrideWith((_) async => [group]),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Auto-select'), findsOneWidget);
    });

    testWidgets('shows error state on provider failure', (tester) async {
      await tester.pumpWidget(testApp(
        const DuplicatesScreen(),
        overrides: [
          duplicatesProvider
              .overrideWith((_) async => throw Exception('scan error')),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error'), findsOneWidget);
    });
  });
}
