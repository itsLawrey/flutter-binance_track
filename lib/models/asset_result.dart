/// Represents a single asset's profit/loss calculation result
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
