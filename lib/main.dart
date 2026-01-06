import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- CONFIGURATION ---
// Keys are now loaded from SharedPreferences
const String quoteAsset = 'USDC';

// --- THEME CONFIGURATION ---
final ThemeData binanceTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF1E2329), // "Shark" Black
  primaryColor: const Color(0xFFFCD535), // "Bright Sun" Yellow
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E2329),
    elevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    ),
    iconTheme: IconThemeData(color: Color(0xFFFCD535)),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF2B3139), // Slightly lighter for cards
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFCD535), // Yellow buttons
      foregroundColor: Colors.black, // Black text on buttons
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2B3139),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFFCD535)), // Yellow border
    ),
    labelStyle: const TextStyle(color: Colors.grey),
  ),
  // Define standard colors for use in the app
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFCD535),
    secondary: Color(0xFFFCD535),
    surface: Color(0xFF2B3139),
    error: Color(0xFFF6465D), // Binance "Sell" Red
  ),
);

void main() {
  runApp(
    MaterialApp(
      home: const PortfolioScreen(),
      theme: binanceTheme,
      debugShowCheckedModeBanner: false,
      title: "Binance Profit Tracker",
      color: const Color(0xFFFCD535), // Yellow
    ),
  );
}

// --- DATA MODELS ---
class AssetResult {
  final String symbol;
  final double quantityHeld;
  final double avgBuyPrice;
  final double currentPrice;
  final double totalCost;
  final double currentValue;
  final double unrealizedPnl;
  final double unrealizedPnlPercent;

  AssetResult({
    required this.symbol,
    required this.quantityHeld,
    required this.avgBuyPrice,
    required this.currentPrice,
    required this.totalCost,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.unrealizedPnlPercent,
  });
}

// --- UI SCREEN ---
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<AssetResult> _portfolio = [];
  bool _isLoading = false;
  String _status = "Ready to scan";

  // API Keys
  String _apiKey = "";
  String _apiSecret = "";

  // Controllers for Drawer
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  // --- LOGIC: STORAGE & KEYS ---
  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('binance_api_key') ?? "";
      _apiSecret = prefs.getString('binance_api_secret') ?? "";

      _apiKeyController.text = _apiKey;
      _apiSecretController.text = _apiSecret;

      if (_apiKey.isEmpty || _apiSecret.isEmpty) {
        _status = "Please set API Keys in the Menu";
      }
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('binance_api_key', _apiKeyController.text.trim());
    await prefs.setString(
      'binance_api_secret',
      _apiSecretController.text.trim(),
    );

    // Update local state
    await _loadKeys();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Keys saved successfully!")));
      Navigator.of(context).pop(); // Close drawer
    }
  }

  // --- LOGIC: HELPER FUNCTIONS ---

  // Binance requires HMAC SHA256 signature
  String _sign(String queryString) {
    if (_apiSecret.isEmpty) return "";
    var key = utf8.encode(_apiSecret);
    var bytes = utf8.encode(queryString);
    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  // Generic secure GET request
  Future<dynamic> _privateGet(
    String endpoint, [
    Map<String, String>? params,
  ]) async {
    if (_apiKey.isEmpty || _apiSecret.isEmpty) {
      throw Exception('API Keys not set. Please configure them in the menu.');
    }

    params ??= {};
    params['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

    // Create query string
    String queryString = Uri(queryParameters: params).query;
    String signature = _sign(queryString);

    final uri = Uri.parse(
      'https://api.binance.com$endpoint?$queryString&signature=$signature',
    );

    final response = await http.get(uri, headers: {'X-MBX-APIKEY': _apiKey});

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Binance API Error: ${response.body}');
    }
  }

  // --- LOGIC: YOUR PYTHON ALGORITHM TRANSLATED ---

  Future<void> _calculatePortfolio() async {
    if (_apiKey.isEmpty || _apiSecret.isEmpty) {
      setState(() => _status = "Missing API Keys! Check Settings.");
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please configure API Keys in the side menu first."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "Scanning balances...";
      _portfolio.clear();
    });

    try {
      // 1. Get Account Info (get_all_non_zero_assets)
      final accountData = await _privateGet('/api/v3/account');
      List<String> assetsToCheck = [];

      for (var balance in accountData['balances']) {
        double free = double.parse(balance['free']);
        double locked = double.parse(balance['locked']);
        if ((free + locked) > 0 && balance['asset'] != quoteAsset) {
          assetsToCheck.add(balance['asset']);
        }
      }

      // 2. Loop through assets
      List<AssetResult> results = [];

      for (String assetName in assetsToCheck) {
        String symbol = assetName + quoteAsset; // e.g. BTCUSDT
        setState(() => _status = "Processing $symbol...");

        try {
          // Fetch Trades
          final trades = await _privateGet('/api/v3/myTrades', {
            'symbol': symbol,
            'limit': '1000',
          });
          if (trades.isEmpty) continue;

          double totalQtyHeld = 0.0;
          double totalCostBasis = 0.0;

          // Calculate Weighted Average (Your logic)
          for (var trade in trades) {
            if (trade['isBuyer'] == true) {
              // double price = double.parse(trade['price']); // Unused
              double qty = double.parse(trade['qty']);
              double quoteQty = double.parse(trade['quoteQty']);
              double commission = double.parse(trade['commission']);
              String commissionAsset = trade['commissionAsset'];

              totalCostBasis += quoteQty;

              // Fee adjustment
              if (commissionAsset == assetName) {
                totalQtyHeld += (qty - commission);
              } else {
                totalQtyHeld += qty;
              }
            }
          }

          if (totalQtyHeld <= 0) continue;

          double avgBuyPrice = totalCostBasis / totalQtyHeld;

          // Fetch Current Price
          final ticker = await http.get(
            Uri.parse(
              'https://api.binance.com/api/v3/ticker/price?symbol=$symbol',
            ),
          );
          if (ticker.statusCode != 200) continue;
          double currentPrice = double.parse(jsonDecode(ticker.body)['price']);

          // Calculate Final Stats
          double currentValue = totalQtyHeld * currentPrice;
          double unrealizedPnl = currentValue - totalCostBasis;
          double pnlPercent = (unrealizedPnl / totalCostBasis) * 100;

          results.add(
            AssetResult(
              symbol: symbol,
              quantityHeld: totalQtyHeld,
              avgBuyPrice: avgBuyPrice,
              currentPrice: currentPrice,
              totalCost: totalCostBasis,
              currentValue: currentValue,
              unrealizedPnl: unrealizedPnl,
              unrealizedPnlPercent: pnlPercent,
            ),
          );
        } catch (e) {
          print("Skipping $symbol: $e");
        }

        // Rate limit pause equivalent
        await Future.delayed(const Duration(milliseconds: 300));
      }

      setState(() {
        _portfolio = results;
        _isLoading = false;
        _status = "Updated: ${DateTime.now().toLocal()}";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = "Error: $e";
      });
    }
  }

  // --- VISUAL LAYOUT ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Binance Profit Tracker"),
            const SizedBox(width: 8),
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/5/57/Binance_Logo.png',
              height: 24,
            ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1E2329), // Match theme
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              const Text(
                "Configuration",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFCD535),
                ),
              ),
              const SizedBox(height: 20),
              const Text("API Key", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  hintText: "Enter Binance API Key",
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text("Secret Key", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: _apiSecretController,
                decoration: const InputDecoration(
                  hintText: "Enter Binance Secret Key",
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveKeys,
                child: const Text(
                  "Save Keys",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      Text(
                        "Keys are stored only locally.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "API key must have read access to your account.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Status Bar (Updated to match Dark Theme)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor, // Uses the theme's card color
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _calculatePortfolio,
                    // Loading indicator is now black to match the button text
                    child: _isLoading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text("Scan"),
                  ),
                ),
              ],
            ),
          ),

          // List of Assets
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: _portfolio.length,
              itemBuilder: (context, index) {
                final item = _portfolio[index];
                final isProfit = item.unrealizedPnl >= 0;
                // Use Binance-style Red/Green
                final pnlColor = isProfit
                    ? const Color(0xFF0ECB81)
                    : const Color(0xFFF6465D);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  // Card color comes from theme
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "\$${item.currentValue.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Avg: \$${item.avgBuyPrice.toStringAsFixed(item.avgBuyPrice < 1 ? 4 : 2)}",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "Hold: ${item.quantityHeld.toStringAsFixed(4)}",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${item.unrealizedPnlPercent > 0 ? '+' : ''}${item.unrealizedPnlPercent.toStringAsFixed(2)}%",
                                  style: TextStyle(
                                    color: pnlColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "${item.unrealizedPnl > 0 ? '+' : ''}\$${item.unrealizedPnl.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: pnlColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
