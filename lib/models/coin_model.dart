class Coin {
  final String symbol;
  final String name;
  final double price;
  final double change24h;
  final double marketCap;
  final int rank;
  final String? imageUrl;

  Coin({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change24h,
    required this.marketCap,
    required this.rank,
    this.imageUrl,
  });

  Coin copyWith({
    String? symbol,
    String? name,
    double? price,
    double? change24h,
    double? marketCap,
    int? rank,
  }) {
    return Coin(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      price: price ?? this.price,
      change24h: change24h ?? this.change24h,
      marketCap: marketCap ?? this.marketCap,
      rank: rank ?? this.rank,
    );
  }

  factory Coin.fromBinanceStream(Map<String, dynamic> json, String name, int rank) {
    return Coin(
      symbol: json['s'].toString().replaceAll('USDT', ''),
      name: name,
      price: double.parse(json['c']),
      change24h: double.parse(json['P']),
      marketCap: double.parse(json['q']) * double.parse(json['c']), // Volume * Price
      rank: rank,
    );
  }

  factory Coin.fromBinanceRest(Map<String, dynamic> json, String name, int rank) {
    return Coin(
      symbol: json['symbol'].toString().replaceAll('USDT', ''),
      name: name,
      price: double.parse(json['lastPrice']),
      change24h: double.parse(json['priceChangePercent']),
      marketCap: double.parse(json['quoteVolume']),
      rank: rank,
    );
  }
}