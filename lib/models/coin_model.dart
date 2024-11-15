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

// import 'package:fl_chart/fl_chart.dart';
//
// class Coin {
//   final String symbol;
//   final String name;
//   final double price;
//   final String iconUrl;
//   final double change24h;
//   final double marketCap;
//   final int rank;
//   final List<FlSpot> sparkline;
//
//   Coin({
//     required this.symbol,
//     required this.name,
//     required this.price,
//     required this.iconUrl,
//     required this.change24h,
//     required this.marketCap,
//     required this.rank,
//     required this.sparkline,
//   });
//
//   factory Coin.fromJson(Map<String, dynamic> json) {
//     List<dynamic> sparklineData = json['sparkline'];
//     return Coin(
//       symbol: json['symbol'],
//       name: json['name'],
//       price: double.parse(json['price']),
//       iconUrl: json['iconUrl'],
//       change24h: double.parse(json['change']),
//       marketCap: double.parse(json['marketCap']),
//       rank: json['rank'],
//       sparkline: sparklineData
//           .asMap()
//           .entries
//           .where((entry) => entry.value != null)
//           .map((entry) => FlSpot(
//         entry.key.toDouble(),
//         double.parse(entry.value),
//       ))
//           .toList(),
//     );
//   }
//
//   // Convert coin to JSON for caching
//   Map<String, dynamic> toJson() => {
//     'symbol': symbol,
//     'name': name,
//     'price': price,
//     'iconUrl': iconUrl,
//     'change24h': change24h,
//     'marketCap': marketCap,
//     'rank': rank,
//     'sparkline': sparkline.map((spot) => {
//       'x': spot.x,
//       'y': spot.y,
//     }).toList(),
//   };
//
//   // Create Coin from cached JSON
//   factory Coin.fromCachedJson(Map<String, dynamic> json) {
//     return Coin(
//       symbol: json['symbol'],
//       name: json['name'],
//       price: json['price'],
//       iconUrl: json['iconUrl'],
//       change24h: json['change24h'],
//       marketCap: json['marketCap'],
//       rank: json['rank'],
//       sparkline: (json['sparkline'] as List).map((spot) =>
//           FlSpot(spot['x'], spot['y'])
//       ).toList(),
//     );
//   }
// }