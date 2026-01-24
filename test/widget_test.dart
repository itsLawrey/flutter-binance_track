import 'package:flutter_test/flutter_test.dart';

import 'package:binance_checker/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BinanceProfitTrackerApp());

    // Verify that the title is present.
    expect(find.text('Binance Profit Tracker'), findsOneWidget);
  });
}
