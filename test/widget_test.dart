import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binance_checker/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We wrap PortfolioScreen in MaterialApp as it is done in main()
    await tester.pumpWidget(
      MaterialApp(home: const PortfolioScreen(), theme: binanceTheme),
    );

    // Verify that the title is present.
    expect(find.text('Binance Profit Tracker'), findsOneWidget);
  });
}
