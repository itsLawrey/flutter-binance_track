import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/asset_result.dart';
import '../services/binance_api_service.dart';
import '../services/currency_service.dart';

/// Main portfolio screen showing profit/loss for all spot holdings
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<AssetResult> _portfolio = [];
  bool _isLoading = false;
  String _status = "Ready to scan";
  List<String> _skippedAssets = [];

  // API Keys
  String _apiKey = "";
  String _apiSecret = "";

  // Currency
  String _selectedCurrency = "USD";
  final CurrencyService _currencyService = CurrencyService();

  // Quote Assets
  List<String> _selectedQuoteAssets = AppConstants.getDefaultQuoteAssets();

  // Controllers for Drawer
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiSecretController = TextEditingController();
  final TextEditingController _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _loadCurrency();
    _loadQuoteAssets();
    _loadExchangeRates();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  // --- STORAGE & KEYS ---
  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString(AppConstants.prefKeyApiKey) ?? "";
      _apiSecret = prefs.getString(AppConstants.prefKeyApiSecret) ?? "";

      _apiKeyController.text = _apiKey;
      _apiSecretController.text = _apiSecret;

      if (_apiKey.isEmpty || _apiSecret.isEmpty) {
        _status = "Please set API Keys in the Menu";
      }
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefKeyApiKey,
      _apiKeyController.text.trim(),
    );
    await prefs.setString(
      AppConstants.prefKeyApiSecret,
      _apiSecretController.text.trim(),
    );

    // Update local state
    await _loadKeys();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved successfully!")),
      );
      Navigator.of(context).pop(); // Close drawer
    }
  }

  // --- CURRENCY MANAGEMENT ---
  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency =
          prefs.getString(AppConstants.prefKeyCurrency) ?? "USD";
    });
  }

  Future<void> _saveCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyCurrency, currency);
    setState(() {
      _selectedCurrency = currency;
    });
    // Reload exchange rates for the new currency
    await _loadExchangeRates();
  }

  Future<void> _loadExchangeRates() async {
    await _currencyService.fetchExchangeRates();
  }

  // --- QUOTE ASSETS MANAGEMENT ---
  Future<void> _loadQuoteAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAssets = prefs.getStringList(AppConstants.prefKeyQuoteAssets);
    setState(() {
      if (savedAssets != null && savedAssets.isNotEmpty) {
        _selectedQuoteAssets = savedAssets;
      } else {
        _selectedQuoteAssets = AppConstants.getDefaultQuoteAssets();
      }
    });
  }

  Future<void> _saveQuoteAssets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      AppConstants.prefKeyQuoteAssets,
      _selectedQuoteAssets,
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.sharkBlack,
        title: const Text(
          'Add Quote Asset',
          style: TextStyle(color: AppTheme.brightSunYellow),
        ),
        content: TextField(
          controller: _newTagController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter tag (e.g., BUSD)",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.brightSunYellow.withOpacity(0.5),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.brightSunYellow),
            ),
          ),
          onSubmitted: (value) {
            _addQuoteAsset(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newTagController.clear();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              _addQuoteAsset(_newTagController.text);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Add',
              style: TextStyle(color: AppTheme.brightSunYellow),
            ),
          ),
        ],
      ),
    );
  }

  void _addQuoteAsset(String asset) {
    final capitalizedAsset = asset.toUpperCase();
    if (capitalizedAsset.isNotEmpty &&
        !_selectedQuoteAssets.contains(capitalizedAsset)) {
      setState(() {
        _selectedQuoteAssets.add(capitalizedAsset);
        _newTagController.clear();
      });
      _saveQuoteAssets();
    }
  }

  void _removeQuoteAsset(String asset) {
    setState(() {
      _selectedQuoteAssets.remove(asset);
    });
    _saveQuoteAssets();
  }

  double _convertAmount(double usdAmount) {
    return _currencyService.convertFromUSD(usdAmount, _selectedCurrency);
  }

  String _getCurrencySymbol() {
    return _currencyService.getCurrencySymbol(_selectedCurrency);
  }

  // --- PORTFOLIO CALCULATION ---
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

    if (_selectedQuoteAssets.isEmpty) {
      setState(() => _status = "No quote assets selected!");
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please add at least one quote asset (e.g., USDC, USDT) in settings.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "Scanning balances...";
      _portfolio.clear();
      _skippedAssets.clear();
    });

    try {
      final service = BinanceApiService(apiKey: _apiKey, apiSecret: _apiSecret);

      final result = await service.calculatePortfolio(
        quoteAssets: _selectedQuoteAssets,
        onStatusUpdate: (status) {
          setState(() => _status = status);
        },
      );

      setState(() {
        _portfolio = result['results'] as List<AssetResult>;
        _skippedAssets = result['skippedAssets'] as List<String>;
        _isLoading = false;
        String timestamp = DateTime.now().toLocal().toString().split('.')[0];
        _status = "Updated: $timestamp";

        // Show info about skipped assets if any
        if (_skippedAssets.isNotEmpty) {
          _status += " (${_skippedAssets.length} assets skipped)";
        }
      });

      // Show snackbar if assets were skipped
      if (_skippedAssets.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Skipped ${_skippedAssets.length} assets (no trading pairs found): ${_skippedAssets.take(5).join(', ')}${_skippedAssets.length > 5 ? '...' : ''}",
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = "Error: $e";
      });
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxAppWidth),
          child: Column(
            children: [
              _buildStatusBar(),
              if (_portfolio.isNotEmpty) _buildPortfolioSummary(),
              Expanded(
                child: _portfolio.isEmpty
                    ? Center(
                        child: Text(
                          _apiKey.isEmpty || _apiSecret.isEmpty
                              ? 'Configure API Keys to get started'
                              : 'Tap Scan to view your portfolio',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        itemCount: _portfolio.length,
                        itemBuilder: (context, index) {
                          return _buildAssetCard(_portfolio[index]);
                        },
                      ),
              ),
              _buildScanButton(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppTheme.sharkBlack,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
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
                    color: AppTheme.brightSunYellow,
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
                const Text(
                  "Secret Key",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiSecretController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: "Enter Binance Secret Key",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 30),
                const Divider(color: Colors.white24),
                const SizedBox(height: 20),
                const Text(
                  "Display Currency",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brightSunYellow,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButton<String>(
                  value: _selectedCurrency,
                  dropdownColor: AppTheme.sharkBlack,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  isExpanded: true,
                  underline: const SizedBox(), // Remove white border
                  items: AppConstants.supportedCurrencies.map((
                    String currency,
                  ) {
                    return DropdownMenuItem<String>(
                      value: currency,
                      child: Text(
                        "$currency (${AppConstants.currencySymbols[currency]})",
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newCurrency) {
                    if (newCurrency != null) {
                      _saveCurrency(newCurrency);
                    }
                  },
                ),
                const SizedBox(height: 30),
                const Divider(color: Colors.white24),
                const SizedBox(height: 20),
                // Quote Assets Section
                const Text(
                  "Quote Assets",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brightSunYellow,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Select which currency pairs to scan (e.g., USDC, USDT)",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Tags display with Wrap
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._selectedQuoteAssets.map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: AppTheme.brightSunYellow.withOpacity(
                          0.2,
                        ),
                        labelStyle: const TextStyle(
                          color: AppTheme.brightSunYellow,
                          fontWeight: FontWeight.bold,
                        ),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppTheme.brightSunYellow,
                        ),
                        onDeleted: () => _removeQuoteAsset(tag),
                      ),
                    ),
                    // Add tag button
                    ActionChip(
                      label: const Icon(Icons.add, size: 18),
                      backgroundColor: AppTheme.brightSunYellow.withOpacity(
                        0.3,
                      ),
                      onPressed: _showAddTagDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Keys are stored only locally.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "API key must have read access to your account.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveKeys,
                  child: const Text(
                    "Save Settings",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.transparent),
      width: double.infinity,
      child: Text(
        _status,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPortfolioSummary() {
    // Calculate totals
    double totalValue = 0;
    double totalPnl = 0;

    for (final asset in _portfolio) {
      totalValue += asset.currentValue;
      totalPnl += asset.unrealizedPnl;
    }

    final totalCost = totalValue - totalPnl;
    final totalPnlPercent = totalCost > 0 ? (totalPnl / totalCost) * 100 : 0;
    final isProfit = totalPnl >= 0;
    final pnlColor = isProfit ? AppTheme.binanceGreen : AppTheme.binanceRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.brightSunYellow.withOpacity(0.1),
            AppTheme.sharkBlack.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.brightSunYellow.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Portfolio Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.brightSunYellow,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Total Value',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getCurrencySymbol()}${_convertAmount(totalValue).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(height: 40, width: 1, color: Colors.grey[700]),
              Column(
                children: [
                  Text(
                    'Total Profit/Loss',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalPnl > 0 ? '+' : ''}${_getCurrencySymbol()}${_convertAmount(totalPnl).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: pnlColor,
                    ),
                  ),
                  Text(
                    '${totalPnlPercent > 0 ? '+' : ''}${totalPnlPercent.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 14, color: pnlColor),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(AssetResult item) {
    final isProfit = item.unrealizedPnl >= 0;
    final pnlColor = isProfit ? AppTheme.binanceGreen : AppTheme.binanceRed;
    final displayName = AppConstants.formatAssetSymbol(item.symbol);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${_getCurrencySymbol()}${_convertAmount(item.currentValue).toStringAsFixed(2)}",
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
                      "Avg: ${_getCurrencySymbol()}${_convertAmount(item.avgBuyPrice).toStringAsFixed(_convertAmount(item.avgBuyPrice) < 1 ? 4 : 2)}",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    Text(
                      "Hold: ${item.quantityHeld.toStringAsFixed(4)}",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
                      "${item.unrealizedPnl > 0 ? '+' : ''}${_getCurrencySymbol()}${_convertAmount(item.unrealizedPnl).toStringAsFixed(2)}",
                      style: TextStyle(color: pnlColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _calculatePortfolio,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brightSunYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    "Scan Portfolio",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
