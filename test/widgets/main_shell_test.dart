import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/screens/main_shell.dart';
import 'widget_test_helpers.dart';

void main() {
  group('MainShell navigation', () {
    testWidgets('renders NavigationBar with 6 destinations', (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      // Each label appears once in the nav bar
      expect(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Dashboard'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cleanup'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Duplicates'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Drive'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Vault'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ), findsOneWidget);
    });

    testWidgets('starts on Dashboard tab', (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();
      expect(find.text('PhotoCleaner'), findsOneWidget);
    });

    testWidgets('tapping Cleanup tab shows Cleanup screen', (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cleanup'),
      ));
      await tester.pumpAndSettle();

      // Cleanup AppBar title
      expect(find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Cleanup'),
      ), findsOneWidget);
    });

    testWidgets('tapping Duplicates tab shows Duplicates screen',
        (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Duplicates'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No duplicates found'), findsOneWidget);
    });

    testWidgets('tapping Settings tab shows Settings screen', (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('SECURITY'), findsOneWidget);
    });

    testWidgets('tapping Drive tab shows Drive screen', (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Drive'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Google Drive Analysis'), findsOneWidget);
    });

    testWidgets('tapping Vault tab shows Vault lock screen', (tester) async {
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Vault'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Vault'), findsOneWidget);
    });
  });
}
