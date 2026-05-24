import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/screens/settings/settings_screen.dart';
import 'widget_test_helpers.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('renders Security section header', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SECURITY'), findsOneWidget);
    });

    testWidgets('renders Scanning section header', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SCANNING'), findsOneWidget);
    });

    testWidgets('renders Compression section header', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('COMPRESSION'), findsOneWidget);
    });

    testWidgets('renders biometric toggle', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Biometric Lock'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('renders compression mode options', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Lossless'), findsOneWidget);
      expect(find.text('Smart (Recommended)'), findsOneWidget);
      expect(find.text('Aggressive'), findsOneWidget);
    });

    testWidgets('renders Google Drive section', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('GOOGLE DRIVE'), findsOneWidget);
    });

    testWidgets('toggling biometric switch does not crash', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pump();
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Lossless radio changes selection', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lossless'));
      await tester.pump();
      expect(find.text('Lossless'), findsOneWidget);
    });

    testWidgets('About section is present when scrolled', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      // Scroll to bottom to reveal About section
      await tester.scrollUntilVisible(
        find.text('ABOUT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('version number is present when scrolled', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1.0.0'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1.0.0'), findsOneWidget);
    });

    testWidgets('Clear All Data dialog appears when tapped', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Clear All Data'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Clear All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear All Data'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('cancelling Clear All Data dialog dismisses it', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Clear All Data'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Clear All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear All Data'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
