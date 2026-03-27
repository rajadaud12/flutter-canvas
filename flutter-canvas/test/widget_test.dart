// Placeholder test — the default test references the old MyApp counter template.
// Our canvas app doesn't have a counter, so this is a basic smoke test.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_canvas/main.dart';

void main() {
  testWidgets('FlutterCanvasApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlutterCanvasApp());
    // Just verify the app builds without errors
    expect(find.byType(FlutterCanvasApp), findsOneWidget);
  });
}
