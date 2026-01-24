import 'package:flutter/foundation.dart';

/// Application-wide constants and configuration
class AppConstants {
  // Binance API Configuration
  /// Uses Firebase Cloud Functions proxy for web production builds
  /// Direct URL for local development and mobile platforms
  static String get binanceApiBaseUrl {
    if (kIsWeb && kReleaseMode) {
      return 'https://us-central1-itslawrey-flutter-demos.cloudfunctions.net/binanceProxy';
    }
    return 'https://api.binance.com';
  }

  /// Supported quote assets for spot trading pairs
  /// USDC and USDT are the most common quote assets on Binance
  static const List<String> quoteAssets = ['USDC', 'USDT'];

  /// Fiat currencies to exclude from portfolio calculations
  /// These don't generate trading profits and can bias the total P/L
  static const List<String> fiatCurrencies = [
    'EUR',
    'USD',
    'GBP',
    'AUD',
    'BRL',
    'BUSD',
    'DAI',
    'FDUSD',
    'TUSD',
    'USDC',
    'USDP',
    'USDT',
  ];

  /// Maximum app width for web/desktop (mobile-first design)
  static const double maxAppWidth = 800.0;

  /// Maximum number of trades to fetch per symbol
  static const String tradeLimit = '1000';

  /// Rate limit delay between API requests (milliseconds)
  static const int rateLimitDelayMs = 300;

  // SharedPreferences Keys
  static const String prefKeyApiKey = 'binance_api_key';
  static const String prefKeyApiSecret = 'binance_api_secret';
  static const String prefKeyCurrency = 'display_currency';
  static const String prefKeyQuoteAssets = 'quote_assets';

  // Currency Configuration
  /// Supported currencies for display conversion
  static const List<String> supportedCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'CHF',
    'JPY',
    'AUD',
    'CAD',
    'SEK',
    'NOK',
    'DKK',
    'RON',
    'HUF',
  ];

  /// Currency symbols for display
  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'CHF': 'CHF',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'RON': 'lei',
    'HUF': 'Ft',
  };

  /// European Central Bank exchange rates API
  /// Uses Firebase Cloud Functions proxy for web production builds
  static String get ecbApiUrl {
    if (kIsWeb && kReleaseMode) {
      return 'https://us-central1-itslawrey-flutter-demos.cloudfunctions.net/ecbProxy';
    }
    return 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml';
  }

  /// Returns the default quote assets list
  static List<String> getDefaultQuoteAssets() {
    return List<String>.from(quoteAssets);
  }

  /// Formats asset symbol for display by separating base from quote asset
  /// Example: "BTCUSDC" -> "BTC - USDC"
  static String formatAssetSymbol(String symbol) {
    // Try to match and remove quote assets
    for (final quote in quoteAssets) {
      if (symbol.endsWith(quote)) {
        final base = symbol.substring(0, symbol.length - quote.length);
        return '$base - $quote';
      }
    }
    // If no quote asset found, return original symbol
    return symbol;
  }
}
