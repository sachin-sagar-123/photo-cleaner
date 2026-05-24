import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/screens/dashboard/dashboard_screen.dart';
import 'package:photo_cleaner/services/services.dart';
import 'package:photo_cleaner/widgets/storage_ring.dart';
import 'package:photo_cleaner/widgets/stat_card.dart';
import 'widget_test_helpers.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('renders scan button when not scanning', (tester) async {
      await tester.pumpWidget(testApp(const DashboardScreen()));
      await tester.pump();

      expect(find.text('Scan Photos'), findsOneWidget);
    });

    testWidgets('shows StorageRing when stats load', (tester) async {
      await tester.pumpWidget(testApp(
        const DashboardScreen(),
        overrides: [
          storageStatsProvider.overrideWith((_) async => stubStats),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(StorageRing), findsOneWidget);
    });

    testWidgets('shows 4 StatCards when stats load', (tester) async {
      await tester.pumpWidget(testApp(
        const DashboardScreen(),
        overrides: [
          storageStatsProvider.overrideWith((_) async => stubStats),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(StatCard), findsNWidgets(4));
    });

    testWidgets('shows total photo count from stats', (tester) async {
      await tester.pumpWidget(testApp(
        const DashboardScreen(),
        overrides: [
          storageStatsProvider.overrideWith((_) async => stubStats),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('1240'), findsOneWidget);
    });

    testWidgets('shows duplicate count from stats', (tester) async {
      await tester.pumpWidget(testApp(
        const DashboardScreen(),
        overrides: [
          storageStatsProvider.overrideWith((_) async => stubStats),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('87'), findsOneWidget);
    });

    testWidgets('shows category grid with 6 tiles', (tester) async {
      await tester.pumpWidget(testApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('People'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Nature'), findsOneWidget);
      expect(find.text('Screenshots'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('shows scanning progress when scan is active', (tester) async {
      await tester.pumpWidget(testApp(
        const DashboardScreen(),
        overrides: [
          scanStateProvider.overrideWith((_) => _ScanningScanNotifier()),
        ],
      ));
      await tester.pump();

      expect(find.text('Scanning photos...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when stats fail', (tester) async {
      await tester.pumpWidget(testApp(
        const DashboardScreen(),
        overrides: [
          storageStatsProvider.overrideWith(
              (_) async => throw Exception('DB error')),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error'), findsOneWidget);
    });
  });
}

/// Notifier that immediately reports a scanning-in-progress state.
class _ScanningScanNotifier extends ScanNotifier {
  _ScanningScanNotifier() : super(ScannerService()) {
    state = const ScanState(
      isScanning: true,
      progress: ScanProgress(
        scanned: 50,
        total: 200,
        currentFile: 'IMG_1234.jpg',
      ),
    );
  }

  @override
  Future<void> startScan() async {} // no-op in tests
}
