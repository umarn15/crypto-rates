import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/forex_pair_model.dart';

class ForexService {
  static const String API_KEY = 'HxgjgDgzW7FJasIp8bK7yprHBhnBqynr'; // polygon
  static const String BASE_URL = 'https://api.polygon.io/v2';

  static Future<List<ForexPair>> getInitialData() async {
    // Get yesterday's date
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

        if (data['results'] != null) {
          for (var result in data['results']) {
            final String rawSymbol = result['T'];
            if (rawSymbol.startsWith('C:') && rawSymbol.length == 8) {
              final String baseCurrency = rawSymbol.substring(2, 5);
              final String quoteCurrency = rawSymbol.substring(5);

              pairs.add(ForexPair(
                symbol: '$baseCurrency/$quoteCurrency',
                name: "${_getCurrencyName(baseCurrency)} / ${_getCurrencyName(quoteCurrency)}",
                price: result['c'].toDouble(),
                change24h: ((result['c'] - result['o']) / result['o'] * 100).toDouble(),
                volume: result['v'].toDouble(),
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
              ));
            }
          }
        }

        pairs.sort((a, b) => b.volume.compareTo(a.volume));
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

// class ForexService {
//   static const String API_KEY = 'HxgjgDgzW7FJasIp8bK7yprHBhnBqynr';
//   static const String BASE_URL = 'https://api.polygon.io/v2';
//
//   static Future<List<ForexPair>> getInitialData() async {
//     // Add API key as query parameter instead of header
//     final url = Uri.parse('$BASE_URL/aggs/grouped/locale/global/market/fx/2023-01-09?adjusted=true&apiKey=$API_KEY');
//     print('Fetching Forex data from $url');
//
//     try {
//       final response = await http.get(url);
//       print('Response status: ${response.statusCode}');
//
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final List<ForexPair> pairs = [];
//
//         if (data['results'] != null) {
//           for (var result in data['results']) {
//             // Polygon returns forex symbols in format "C:EURUSD"
//             // Need to convert to "EUR/USD" format
//             final String rawSymbol = result['T'];
//             if (rawSymbol.startsWith('C:') && rawSymbol.length == 8) {
//               final String baseCurrency = rawSymbol.substring(2, 5);
//               final String quoteCurrency = rawSymbol.substring(5);
//               final String formattedSymbol = '$baseCurrency/$quoteCurrency';
//
//               pairs.add(ForexPair(
//                 symbol: formattedSymbol,
//                 name: "${_getCurrencyName(baseCurrency)} / ${_getCurrencyName(quoteCurrency)}",
//                 price: result['c'].toDouble(),
//                 change24h: ((result['c'] - result['o']) / result['o'] * 100).toDouble(),
//                 volume: result['v'].toDouble(),
//                 baseCurrency: baseCurrency,
//                 quoteCurrency: quoteCurrency,
//               ));
//             }
//           }
//         }
//
//         return pairs;
//       } else {
//         print('Failed to load forex data: ${response.statusCode}, Body: ${response.body}');
//         throw Exception('Failed to load forex data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching forex data: $e');
//       return [];
//     }
//   }
//
//   static String _getCurrencyName(String code) {
//     switch (code) {
//       case 'EUR': return 'Euro';
//       case 'USD': return 'US Dollar';
//       case 'GBP': return 'British Pound';
//       case 'JPY': return 'Japanese Yen';
//       case 'CHF': return 'Swiss Franc';
//       case 'AUD': return 'Australian Dollar';
//       case 'CAD': return 'Canadian Dollar';
//       case 'NZD': return 'New Zealand Dollar';
//       default: return code;
//     }
//   }
// }