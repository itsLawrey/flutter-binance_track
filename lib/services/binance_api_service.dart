import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/asset_result.dart';

/// Service class for all Binance API interactions
/// Handles authentication, signing, and portfolio calculations
class BinanceApiService {
  final String apiKey;
  final String apiSecret;

  BinanceApiService({required this.apiKey, required this.apiSecret});

  /// Generates HMAC SHA256 signature for Binance API requests
  String _sign(String queryString) {
    if (apiSecret.isEmpty) return "";
    var key = utf8.encode(apiSecret);
    var bytes = utf8.encode(queryString);
    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Makes a signed GET request to Binance API
  Future<dynamic> _privateGet(
    String endpoint, [
    Map<String, String>? params,
  ]) async {
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      throw Exception('API Keys not set. Please configure them in the menu.');
    }

    params ??= {};
    params['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

    // Create query string
    String queryString = Uri(queryParameters: params).query;
    String signature = _sign(queryString);

    final uri = Uri.parse(
      '${AppConstants.binanceApiBaseUrl}$endpoint?$queryString&signature=$signature',
    );

    final response = await http.get(uri, headers: {'X-MBX-APIKEY': apiKey});

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Binance API Error: ${response.body}');
    }
  }

  /// Fetches current price for a trading symbol
  Future<double?> _getCurrentPrice(String symbol) async {
    try {
      final ticker = await http.get(
        Uri.parse(
          '${AppConstants.binanceApiBaseUrl}/api/v3/ticker/price?symbol=$symbol',
        ),
      );
      if (ticker.statusCode == 200) {
        return double.parse(jsonDecode(ticker.body)['price']);
      }
    } catch (e) {
      // Price fetch failed
    }
    return null;
  }

  /// Calculates portfolio profit/loss for all spot holdings
  /// Returns a list of AssetResults and a list of skipped asset names
  Future<Map<String, dynamic>> calculatePortfolio({
    List<String>? quoteAssets,
    required Function(String) onStatusUpdate,
  }) async {
    List<AssetResult> results = [];
    List<String> skippedAssets = [];

    // Use provided quote assets or default to constants
    final assetsToTry = quoteAssets ?? AppConstants.quoteAssets;

    // 1. Get Account Info
    final accountData = await _privateGet('/api/v3/account');
    Map<String, double> assetsToCheck = {};

    for (var balance in accountData['balances']) {
      double free = double.parse(balance['free']);
      double locked = double.parse(balance['locked']);
      double total = free + locked;
      String asset = balance['asset'];

      // Skip if zero balance, if it's a quote asset, or if it's a fiat currency
      if (total > 0 &&
          !AppConstants.quoteAssets.contains(asset) &&
          !AppConstants.fiatCurrencies.contains(asset)) {
        assetsToCheck[asset] = total;
      }
    }

    // 2. Process each asset
    for (String assetName in assetsToCheck.keys) {
      double actualBalance = assetsToCheck[assetName]!;

      // Temporary storage for pairs found for this asset
      // Map key: symbol (e.g. BTCUSDT), value: Struct with stats
      Map<String, _PairStats> pairStats = {};
      double totalNetQtyBoughtAllPairs = 0.0;

      // Try each quote asset to find ALL valid pairs
      for (String quoteAsset in assetsToTry) {
        String symbol = assetName + quoteAsset;
        onStatusUpdate("Processing $symbol...");

        try {
          // Fetch trade history
          final trades = await _privateGet('/api/v3/myTrades', {
            'symbol': symbol,
            'limit': AppConstants.tradeLimit,
          });
          if (trades.isEmpty) continue;

          double totalCostBasis = 0.0;
          double totalQtyBought =
              0.0; // This is actually "net quantity remaining from trades"

          // Calculate cost basis across ALL trades (buys and sells)
          for (var trade in trades) {
            double qty = double.parse(trade['qty']);
            double quoteQty = double.parse(trade['quoteQty']);
            double commission = double.parse(trade['commission']);
            String commissionAsset = trade['commissionAsset'];

            if (trade['isBuyer'] == true) {
              // BUY: Add to cost basis
              totalCostBasis += quoteQty;

              // Track quantity bought (for averaging)
              if (commissionAsset == assetName) {
                totalQtyBought += (qty - commission);
              } else {
                totalQtyBought += qty;
              }
            } else {
              // SELL: Reduce cost basis proportionally
              // Use FIFO accounting: reduce cost basis by average cost
              if (totalQtyBought > 0) {
                double avgCostAtSale = totalCostBasis / totalQtyBought;
                totalCostBasis -= (avgCostAtSale * qty);
                totalQtyBought -= qty;
              }
            }
          }

          if (totalQtyBought <= 0) continue;

          // Fetch current price
          double? currentPrice = await _getCurrentPrice(symbol);
          if (currentPrice == null) continue;

          // Store stats for this pair
          pairStats[symbol] = _PairStats(
            netQtyBought: totalQtyBought,
            avgPrice: totalCostBasis / totalQtyBought,
            currentPrice: currentPrice,
          );

          totalNetQtyBoughtAllPairs += totalQtyBought;
        } catch (e) {
          // Try next quote asset
          continue;
        }
      }

      // If no valid pairs found
      if (pairStats.isEmpty) {
        skippedAssets.add(assetName);
        continue;
      }

      // 3. Apportion actual balance to pairs and create results
      pairStats.forEach((symbol, stats) {
        // Calculate portion of the actual wallet balance this pair represents
        double allocationRatio = stats.netQtyBought / totalNetQtyBoughtAllPairs;
        double quantityHeld = actualBalance * allocationRatio;

        // Calculate final values based on the allocated quantity
        double totalCostForAllocatedQty = quantityHeld * stats.avgPrice;
        double currentValue = quantityHeld * stats.currentPrice;
        double unrealizedPnl = currentValue - totalCostForAllocatedQty;
        // Avoid division by zero
        double pnlPercent = totalCostForAllocatedQty > 0
            ? (unrealizedPnl / totalCostForAllocatedQty) * 100
            : 0.0;

        results.add(
          AssetResult(
            symbol: symbol,
            quantityHeld: quantityHeld,
            avgBuyPrice: stats.avgPrice,
            currentPrice: stats.currentPrice,
            totalCost: totalCostForAllocatedQty,
            currentValue: currentValue,
            unrealizedPnl: unrealizedPnl,
            unrealizedPnlPercent: pnlPercent,
          ),
        );
      });

      // Rate limit pause
      await Future.delayed(
        const Duration(milliseconds: AppConstants.rateLimitDelayMs),
      );
    }

    return {'results': results, 'skippedAssets': skippedAssets};
  }
}

/// Helper class to store temporary statistics for a trading pair
class _PairStats {
  final double netQtyBought;
  final double avgPrice;
  final double currentPrice;

  _PairStats({
    required this.netQtyBought,
    required this.avgPrice,
    required this.currentPrice,
  });
}
