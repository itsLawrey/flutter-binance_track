import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../config/constants.dart';

/// Service for fetching and converting currency using ECB exchange rates
class CurrencyService {
  // Cache exchange rates in memory for the session
  final Map<String, double> _rates = {};
  bool _ratesLoaded = false;

  /// Fetches latest exchange rates from European Central Bank
  /// Returns true if successful, false otherwise
  Future<bool> fetchExchangeRates() async {
    try {
      final response = await http.get(Uri.parse(AppConstants.ecbApiUrl));

      if (response.statusCode != 200) {
        return false;
      }

      // Parse XML response
      final document = XmlDocument.parse(response.body);

      // ECB XML structure: <Cube><Cube time="..."><Cube currency="USD" rate="1.23"/></Cube></Cube>
      final cubes = document.findAllElements('Cube');

      // Clear existing rates
      _rates.clear();

      // EUR is the base currency (always 1.0)
      _rates['EUR'] = 1.0;

      // Extract currency rates
      for (var cube in cubes) {
        final currency = cube.getAttribute('currency');
        final rate = cube.getAttribute('rate');

        if (currency != null && rate != null) {
          _rates[currency] = double.parse(rate);
        }
      }

      _ratesLoaded = _rates.isNotEmpty;
      return _ratesLoaded;
    } catch (e) {
      // Failed to fetch or parse rates
      _ratesLoaded = false;
      return false;
    }
  }

  /// Converts an amount from USD to the target currency
  /// Returns the converted amount, or the original amount if conversion fails
  double convertFromUSD(double usdAmount, String targetCurrency) {
    // If target is USD, no conversion needed
    if (targetCurrency == 'USD') {
      return usdAmount;
    }

    // If rates not loaded or target currency not supported, return original
    if (!_ratesLoaded || !_rates.containsKey(targetCurrency)) {
      return usdAmount;
    }

    // Get USD/EUR rate and target/EUR rate
    final usdToEur = _rates['USD'];
    final targetToEur = _rates[targetCurrency];

    if (usdToEur == null || targetToEur == null || usdToEur == 0) {
      return usdAmount;
    }

    // Convert: USD -> EUR -> Target Currency
    // 1 USD = X EUR, so USD amount * (1/X) = EUR amount
    // 1 EUR = Y Target, so EUR amount * Y = Target amount
    final eurAmount = usdAmount / usdToEur;
    final targetAmount = eurAmount * targetToEur;

    return targetAmount;
  }

  /// Gets the currency symbol for a given currency code
  String getCurrencySymbol(String currencyCode) {
    return AppConstants.currencySymbols[currencyCode] ?? '\$';
  }

  /// Check if rates are loaded
  bool get isRatesLoaded => _ratesLoaded;
}
