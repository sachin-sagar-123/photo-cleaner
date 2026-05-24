import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_cleaner/main.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PhotoCleanerApp()),
    );
    expect(find.byType(PhotoCleanerApp), findsOneWidget);
  });
}
