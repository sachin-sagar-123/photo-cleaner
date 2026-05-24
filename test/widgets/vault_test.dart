import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/screens/vault/vault_screen.dart';
import 'widget_test_helpers.dart';

void main() {
  group('VaultScreen', () {
    testWidgets('shows lock screen when vault is locked', (tester) async {
      await tester.pumpWidget(testApp(const VaultScreen()));
      await tester.pump();

      expect(find.text('Document Vault'), findsOneWidget);
      expect(find.text('Unlock Vault'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows document list when vault is unlocked', (tester) async {
      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
        ],
      ));
      await tester.pumpAndSettle();

      // Empty vault shows placeholder
      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.text('Tap + to add a document'), findsOneWidget);
    });

    testWidgets('shows FAB when unlocked', (tester) async {
      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows search field when unlocked', (tester) async {
      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Search documents...'),
          findsOneWidget);
    });

    testWidgets('shows lock button in app bar when unlocked', (tester) async {
      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('tapping lock button re-locks vault', (tester) async {
      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();

      // Should now show lock screen
      expect(find.text('Unlock Vault'), findsOneWidget);
    });

    testWidgets('shows document tiles when documents exist', (tester) async {
      final doc = VaultDocument(
        id: 'doc-1',
        title: 'My Passport',
        imagePath: '/fake/passport.jpg',
        type: DocumentType.passport,
        addedAt: DateTime(2024, 1, 15),
      );

      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
          vaultDocumentsProvider.overrideWith((_) async => [doc]),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Passport'), findsOneWidget);
      expect(find.textContaining('passport'), findsOneWidget);
    });

    testWidgets('tapping FAB shows add document sheet', (tester) async {
      await tester.pumpWidget(testApp(
        const VaultScreen(),
        overrides: [
          vaultUnlockedProvider.overrideWith((_) => true),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Sheet title is visible
      expect(find.text('Add Document'), findsWidgets);
      // Title text field is present
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    });
  });
}
