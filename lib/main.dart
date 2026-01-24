import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/portfolio_screen.dart';

void main() {
  runApp(const BinanceProfitTrackerApp());
}

class BinanceProfitTrackerApp extends StatelessWidget {
  const BinanceProfitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const PortfolioScreen(),
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      title: "Binance Profit Tracker",
    );
  }
}
