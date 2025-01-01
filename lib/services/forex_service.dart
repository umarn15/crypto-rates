import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/forex_pair_model.dart';

class ForexService {
  static const String API_KEY = 'HxgjgDgzW7FJasIp8bK7yprHBhnBqynr'; // polygon
  static const String BASE_URL = 'https://api.polygon.io/v2';

  static const List<String> MAJOR_PAIRS = [
    'EUR/USD', 'GBP/USD', 'USD/JPY', 'USD/CHF',
    'AUD/USD', 'USD/CAD', 'NZD/USD', 'EUR/GBP',
    'EUR/JPY', 'GBP/JPY'
  ];

  static Future<List<ForexPair>> getInitialData() async {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    final date = yesterday.toIso8601String().split('T')[0];

    final url = Uri.parse('$BASE_URL/aggs/grouped/locale/global/market/fx/$date?adjusted=true&apiKey=$API_KEY');
    print('Fetching Forex data from $url');

    try {
      final response = await http.get(url);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<ForexPair> pairs = [];
        final Map<String, dynamic> volumeData = {};

        if (data['results'] != null) {
          for (var result in data['results']) {
            final String rawSymbol = result['T'];
            if (rawSymbol.startsWith('C:') && rawSymbol.length == 8) {
              final String baseCurrency = rawSymbol.substring(2, 5);
              final String quoteCurrency = rawSymbol.substring(5);
              final String symbol = '$baseCurrency/$quoteCurrency';

              if (MAJOR_PAIRS.contains(symbol)) {
                volumeData[symbol] = {
                  'volume': result['v']?.toDouble() ?? 0.0,
                  'close': result['c']?.toDouble() ?? 0.0,
                  'open': result['o']?.toDouble() ?? 0.0,
                };
              }
            }
          }
        }

        for (String pairSymbol in MAJOR_PAIRS) {
          final baseCurrency = pairSymbol.substring(0, 3);
          final quoteCurrency = pairSymbol.substring(4);

          final pairData = volumeData[pairSymbol] ?? {
            'volume': 0.0,
            'close': 0.0,
            'open': 0.0,
          };

          pairs.add(ForexPair(
            symbol: pairSymbol,
            name: "${_getCurrencyName(baseCurrency)} / ${_getCurrencyName(quoteCurrency)}",
            price: pairData['close'],
            change24h: pairData['open'] != 0
                ? ((pairData['close'] - pairData['open']) / pairData['open'] * 100)
                : 0.0,
            volume: pairData['volume'],
            baseCurrency: baseCurrency,
            quoteCurrency: quoteCurrency,
          ));
        }

        pairs.sort((a, b) {
          if (a.volume == 0 && b.volume == 0) {
            return a.symbol.compareTo(b.symbol);
          }
          if (a.volume == 0) return 1;
          if (b.volume == 0) return -1;
          return b.volume.compareTo(a.volume);
        });

        return pairs;
      } else {
        print('Failed to load forex data: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load forex data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching forex data: $e');
      return [];
    }
  }

  static String _getCurrencyName(String code) {
    switch (code) {
      case 'EUR': return 'Euro';
      case 'USD': return 'US Dollar';
      case 'GBP': return 'British Pound';
      case 'JPY': return 'Japanese Yen';
      case 'CHF': return 'Swiss Franc';
      case 'AUD': return 'Australian Dollar';
      case 'CAD': return 'Canadian Dollar';
      case 'NZD': return 'New Zealand Dollar';
      default: return code;
    }
  }
}