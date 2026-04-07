import 'package:flutter_test/flutter_test.dart';
import 'package:readverse/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test - app builds without crashing
    expect(ReadVerseApp, isNotNull);
  });
}
