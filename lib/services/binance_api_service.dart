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
    Map<String, dynamic> assetsToCheck = {};

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
      bool foundValidPair = false;

      // Try each quote asset until we find one with trades
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
          double totalQtyBought = 0.0;

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

          // Use actual balance from account, not calculated from trades
          // This handles deposits/withdrawals correctly
          if (actualBalance <= 0 || totalQtyBought <= 0) {
            foundValidPair = true; // Found trades but nothing to show
            break;
          }

          // Calculate average buy price from remaining cost basis
          double avgBuyPrice = totalCostBasis / actualBalance;

          // Fetch current price
          double? currentPrice = await _getCurrentPrice(symbol);
          if (currentPrice == null) continue;

          // Calculate final stats using actual balance
          double currentValue = actualBalance * currentPrice;
          double unrealizedPnl = currentValue - totalCostBasis;
          double pnlPercent = (unrealizedPnl / totalCostBasis) * 100;

          results.add(
            AssetResult(
              symbol: symbol,
              quantityHeld: actualBalance,
              avgBuyPrice: avgBuyPrice,
              currentPrice: currentPrice,
              totalCost: totalCostBasis,
              currentValue: currentValue,
              unrealizedPnl: unrealizedPnl,
              unrealizedPnlPercent: pnlPercent,
            ),
          );

          foundValidPair = true;
          break; // Found valid pair, no need to try other quotes
        } catch (e) {
          // Try next quote asset
          continue;
        }
      }

      // If no valid pair found for this asset, track it
      if (!foundValidPair) {
        skippedAssets.add(assetName);
      }

      // Rate limit pause
      await Future.delayed(
        const Duration(milliseconds: AppConstants.rateLimitDelayMs),
      );
    }

    return {'results': results, 'skippedAssets': skippedAssets};
  }
}
