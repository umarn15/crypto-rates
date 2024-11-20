import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/coin_model.dart';

class BinanceService {
  static const String baseUrl = 'https://api.binance.com/api/v3';
  static const String websocketUrl = 'wss://stream.binance.com:9443/ws';

  static final Map<String, String> _symbolToName = {
    'BTC': 'Bitcoin',
    'ETH': 'Ethereum',
    'BNB': 'Binance Coin',
    'USDT': 'Tether',
    'USDC': 'USD Coin',
    'XRP': 'Ripple',
    'ADA': 'Cardano',
    'DOGE': 'Dogecoin',
    'SOL': 'Solana',
    'TRX': 'TRON',
    'DOT': 'Polkadot',
    'MATIC': 'Polygon',
    'LTC': 'Litecoin',
    'ATOM': 'Cosmos',
    'LINK': 'Chainlink',
    'AVAX': 'Avalanche',
    'XLM': 'Stellar',
    'UNI': 'Uniswap',
    'ETC': 'Ethereum Classic',
    'NEAR': 'NEAR Protocol',
  };


  // In BinanceService class
  static Future<List<Coin>> getInitialData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ticker/24hr'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Coin> coins = [];

        // First, filter USDT pairs and create coins
        data.where((item) => item['symbol'].toString().endsWith('USDT')).forEach((item) {
          final symbol = item['symbol'].toString().replaceAll('USDT', '');

          // Ensure only coins in _symbolToName are included
          if (_symbolToName.containsKey(symbol)) {
            final price = double.parse(item['lastPrice']);
            final volume = double.parse(item['quoteVolume']); // USDT volume
            final marketCap = price * volume; // Approximate market cap

            coins.add(Coin(
              symbol: symbol,
              name: _symbolToName[symbol]!,
              price: price,
              change24h: double.parse(item['priceChangePercent']),
              marketCap: marketCap,
              rank: 0, // Will set after sorting
            ));
          }
        });
        // Sort by market cap
        coins.sort((a, b) => b.marketCap.compareTo(a.marketCap));

        // Assign ranks after sorting
        for (int i = 0; i < coins.length; i++) {
          coins[i] = coins[i].copyWith(rank: i + 1);
        }

        // Take top 20
        return coins.take(20).toList();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error getting initial data: $e');
      rethrow;
    }
  }

  static WebSocketChannel getWebSocket(List<String> symbols) {
    final List<String> streams = symbols.map((symbol) =>
    '${symbol.toLowerCase()}usdt@ticker'
    ).toList();

    final url = Uri.parse('$websocketUrl/stream?streams=${streams.join("/")}');
    return WebSocketChannel.connect(url);
  }

  static WebSocketChannel getSingleCoinWebSocket(String symbol) {
    final streamName = '${symbol.toLowerCase()}usdt@ticker';
    final url = Uri.parse('$websocketUrl/$streamName');
    return WebSocketChannel.connect(url);
  }
}