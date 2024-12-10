import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/forex_pair_model.dart';

class ForexService {
  static const String API_KEY = 'HxgjgDgzW7FJasIp8bK7yprHBhnBqynr'; // polygon logged in with github
  static const String BASE_URL = 'https://api.polygon.io/v2';

  static Future<List<ForexPair>> getInitialData() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/snapshot/locale/global/markets/forex/tickers'),
        headers: {'Authorization': 'Bearer $API_KEY'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<ForexPair> pairs = [];

        for (var ticker in data['tickers']) {
          final String symbol = ticker['ticker'];
          final currencies = symbol.split('/');

          pairs.add(ForexPair(
            symbol: symbol,
            name: '${currencies[0]}/${currencies[1]}',
            price: ticker['day']['c'].toDouble(),
            change24h: ticker['todaysChange'].toDouble(),
            volume: ticker['day']['v'].toDouble(),
            baseCurrency: currencies[0],
            quoteCurrency: currencies[1],
          ));
        }

        // Sort by volume
        pairs.sort((a, b) => b.volume.compareTo(a.volume));
        return pairs;
      } else {
        throw Exception('Failed to load forex data');
      }
    } catch (e) {
      print('Error fetching forex data: $e');
      return [];
    }
  }
}