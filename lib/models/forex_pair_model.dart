// models/forex_pair.dart
class ForexPair {
  final String symbol;
  final String name;
  final double price;
  final double change24h;
  final double volume;
  final String baseCurrency;
  final String quoteCurrency;

  ForexPair({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change24h,
    required this.volume,
    required this.baseCurrency,
    required this.quoteCurrency,
  });

  ForexPair copyWith({
    double? price,
    double? change24h,
    double? volume,
  }) {
    return ForexPair(
      symbol: symbol,
      name: name,
      price: price ?? this.price,
      change24h: change24h ?? this.change24h,
      volume: volume ?? this.volume,
      baseCurrency: baseCurrency,
      quoteCurrency: quoteCurrency,
    );
  }
}