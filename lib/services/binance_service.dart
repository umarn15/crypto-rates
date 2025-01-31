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
    'ALGO': 'Algorand',
    'FIL': 'Filecoin',
    'VET': 'VeChain',
    'ICP': 'Internet Computer',
    'AAVE': 'Aave',
    'XTZ': 'Tezos',
    'EOS': 'EOS',
    'MKR': 'Maker',
    'ZEC': 'Zcash',
    'DASH': 'Dash',
    'NEO': 'NEO',
    'WAVES': 'Waves',
    'QTUM': 'Qtum',
    'KSM': 'Kusama',
    'BAT': 'Basic Attention Token',
    'COMP': 'Compound',
    'YFI': 'Yearn.finance',
    'SNX': 'Synthetix',
    'GRT': 'The Graph',
    'SUSHI': 'SushiSwap',
    'CRV': 'Curve DAO Token',
    '1INCH': '1inch Network',
    'ENJ': 'Enjin Coin',
  };

  static Future<List<Coin>> getInitialData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ticker/24hr'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Coin> coins = [];

        // Filter USDT pairs and create coins
        for (final item in data) {
          final symbol = item['symbol'].toString().replaceAll('USDT', '');
          if (_symbolToName.containsKey(symbol)) {
            final price = double.tryParse(item['lastPrice'] ?? '0') ?? 0;
            final volume = double.tryParse(item['quoteVolume'] ?? '0') ?? 0;
            final marketCap = price * volume;

            coins.add(Coin(
              symbol: symbol,
              name: _symbolToName[symbol]!,
              price: price,
              change24h: double.tryParse(item['priceChangePercent'] ?? '0') ?? 0,
              marketCap: marketCap,
              rank: 0,
            ));
          }
        }

        // Sort by market cap descending
        coins.sort((a, b) => b.marketCap.compareTo(a.marketCap));

        // Assign ranks
        for (int i = 0; i < coins.length; i++) {
          coins[i] = coins[i].copyWith(rank: i + 1);
        }

        return coins;
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error getting initial data: $e');
      rethrow;
    }
  }

  static WebSocketChannel getWebSocket(List<String> symbols) {
    final streams = symbols.map((s) => '${s.toLowerCase()}usdt@ticker').toList();
    return WebSocketChannel.connect(
      Uri.parse('$websocketUrl/stream?streams=${streams.join("/")}'),
    );
  }

  static WebSocketChannel getSingleCoinWebSocket(String symbol) {
    return WebSocketChannel.connect(
      Uri.parse('$websocketUrl/${symbol.toLowerCase()}usdt@ticker'),
    );
  }
}