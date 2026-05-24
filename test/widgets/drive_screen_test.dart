import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/screens/drive/drive_screen.dart';
import 'package:photo_cleaner/services/drive_sync_service.dart';
import 'widget_test_helpers.dart';

void main() {
  group('DriveScreen', () {
    testWidgets('shows sign-in prompt when not connected', (tester) async {
      await tester.pumpWidget(testApp(const DriveScreen()));
      await tester.pump();
      expect(find.text('Google Drive Analysis'), findsOneWidget);
      expect(find.text('Connect Google Drive'), findsOneWidget);
    });

    testWidgets('sign-in prompt lists feature rows', (tester) async {
      await tester.pumpWidget(testApp(const DriveScreen()));
      await tester.pump();
      expect(find.textContaining('MD5 checksum'), findsOneWidget);
      expect(find.textContaining('thumbnail'), findsOneWidget);
      expect(find.textContaining('Delete directly'), findsOneWidget);
    });

    testWidgets('shows 3 tabs when signed in', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [driveSignedInProvider.overrideWith((_) => true)],
      ));
      await tester.pumpAndSettle();
      expect(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Duplicates'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Blurry'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Junk'),
      ), findsOneWidget);
    });

    testWidgets('shows Scan Drive button when signed in', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [driveSignedInProvider.overrideWith((_) => true)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Scan Drive'), findsOneWidget);
    });

    testWidgets('shows empty state on Duplicates tab', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [driveSignedInProvider.overrideWith((_) => true)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('No Drive duplicates found'), findsOneWidget);
    });

    testWidgets('shows Drive file tile when duplicates exist', (tester) async {
      final driveAsset = PhotoAsset(
        id: 'drive_abc123',
        path: '',
        name: 'vacation.jpg',
        sizeBytes: 3 * 1024 * 1024,
        createdAt: DateTime(2024, 6, 1),
        isDriveOnly: false,
        driveFileId: 'abc123',
        driveMd5: 'md5abc',
      );
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [
          driveSignedInProvider.overrideWith((_) => true),
          driveDuplicatesProvider.overrideWith((_) async => [driveAsset]),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('vacation.jpg'), findsOneWidget);
      expect(find.text('Also local'), findsOneWidget);
    });

    testWidgets('shows scanning view during Drive scan', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [
          driveSignedInProvider.overrideWith((_) => true),
          driveScanStateProvider.overrideWith(
            (_) => _FixedDriveScanNotifier(
              DriveScanState(
                isScanning: true,
                progress: const DriveScanProgress(
                  scanned: 100,
                  total: 500,
                  currentFile: 'holiday.jpg',
                  phase: 'analyzing',
                ),
              ),
            ),
          ),
        ],
      ));
      await tester.pump();
      expect(find.textContaining('thumbnails are downloaded'), findsOneWidget);
    });

    testWidgets('shows disconnect button when signed in', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [driveSignedInProvider.overrideWith((_) => true)],
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.logout_outlined), findsOneWidget);
    });

    testWidgets('switching to Blurry tab shows empty state', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [driveSignedInProvider.overrideWith((_) => true)],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Blurry'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No blurry photos on Drive'), findsOneWidget);
    });

    testWidgets('switching to Junk tab shows empty state', (tester) async {
      await tester.pumpWidget(testApp(
        const DriveScreen(),
        overrides: [driveSignedInProvider.overrideWith((_) => true)],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Junk'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No junk photos on Drive'), findsOneWidget);
    });
  });
}

class _FixedDriveScanNotifier extends DriveScanNotifier {
  _FixedDriveScanNotifier(DriveScanState initial)
      : super(DriveSyncService(), null) {
    state = initial;
  }

  @override
  Future<void> startScan() async {}
}
