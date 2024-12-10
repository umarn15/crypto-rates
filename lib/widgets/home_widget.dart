import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class CryptoHomeWidget {
  static const String appGroupId = 'com.example.crypto_rates';
  static const String androidWidgetName = 'CryptoPriceWidget';
  static const String iOSWidgetName = 'CryptoPriceWidget';
  static const List<String> TOP_COINS = ['BTC', 'ETH', 'BNB'];

  static final _httpClient = http.Client(); // Reuse HTTP client
  static bool _isUpdating = false; // Prevent concurrent updates
  static DateTime? _lastUpdateTime;
  static const Duration _minUpdateInterval = Duration(minutes: 5);

  // Initialize the widget
  static Future<void> initPlatformState() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);

      HomeWidget.registerInteractivityCallback((Uri? uri) async {
        if (uri?.host == 'REFRESH_DATA') {
          await updatePriceData(isRefresh: true);
        }
      });
    } catch (e) {
      print('Widget initialization error: $e');
    }
  }

  static Future<void> updatePriceData({bool isRefresh = false}) async {
    // Prevent updates too close together unless forced refresh
    if (!isRefresh && _lastUpdateTime != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceLastUpdate < _minUpdateInterval) {
        print('Skipping update: Too soon since last update');
        return;
      }
    }

    if (_isUpdating) {
      print('Update already in progress, skipping');
      return;
    }

    _isUpdating = true;

    try {
      prefs = await SharedPreferences.getInstance();

      final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
      final response = await _httpClient.get(url).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('API request timed out');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> tickers = jsonDecode(response.body);
        List<Map<String, dynamic>> widgetData = [];

        for (String symbol in TOP_COINS) {
          final ticker = tickers.firstWhere(
                (t) => t['symbol'] == '${symbol}USDT',
            orElse: () => null,
          );

          if (ticker != null) {
            try {
              final price = double.parse(ticker['lastPrice']);
              final change = double.parse(ticker['priceChangePercent']);

              widgetData.add({
                'symbol': symbol,
                'price': price.toStringAsFixed(2),
                'change': change.toStringAsFixed(2),
              });
            } catch (e) {
              print('Error processing data for $symbol: $e');
              // Add placeholder data if parsing fails
              widgetData.add({
                'symbol': symbol,
                'price': '0.00',
                'change': '0.00',
              });
            }
          }
        }

        if (widgetData.isNotEmpty) {
          final String encodedData = json.encode(widgetData);
          final String currentTime = DateTime.now().toLocal().toString();

          // Batch save operations
          try {
            await Future.wait([
              HomeWidget.saveWidgetData<String>('crypto_data', encodedData),
              HomeWidget.saveWidgetData<String>('last_updated', currentTime),
              prefs.setString('crypto_data', encodedData),
              prefs.setString('last_updated', currentTime),
            ]);

            _lastUpdateTime = DateTime.now();

            if (isRefresh) {
              await HomeWidget.updateWidget(
                androidName: androidWidgetName,
                iOSName: iOSWidgetName,
              );
            }
          } catch (e) {
            print('Error saving widget data: $e');
            // Attempt to save to SharedPreferences only as fallback
            await prefs.setString('crypto_data', encodedData);
            await prefs.setString('last_updated', currentTime);
          }
        } else {
          print('No valid data to update widget');
        }
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating widget: $e');
      // Try to recover last known good data from SharedPreferences
      await _recoverLastKnownData(isRefresh);
    } finally {
      _isUpdating = false;
    }
  }

  // Add this new method to handle refresh
  static Future<void> handleRefresh() async {
    await updatePriceData(isRefresh: true);
  }

  // Helper method to recover last known good data
  static Future<void> _recoverLastKnownData(bool isRefresh) async {
    try {
      final lastData = prefs.getString('crypto_data');
      final lastUpdate = prefs.getString('last_updated');

      if (lastData != null && lastUpdate != null) {
        await HomeWidget.saveWidgetData<String>('crypto_data', lastData);
        await HomeWidget.saveWidgetData<String>('last_updated', lastUpdate);

        if (isRefresh) {
          await HomeWidget.updateWidget(
            androidName: androidWidgetName,
            iOSName: iOSWidgetName,
          );
        }
      }
    } catch (e) {
      print('Error recovering last known data: $e');
    }
  }

  // Cleanup method to be called when the app is terminated
  static void dispose() {
    _httpClient.close();
  }

  // Helper method to get WebSocket for real-time updates
  static Uri getWebSocketUrl() {
    final symbols = TOP_COINS.map((symbol) =>
    '${symbol.toLowerCase()}usdt@ticker'
    ).join('/');
    return Uri.parse('wss://stream.binance.com:9443/ws/$symbols');
  }
}

// import 'package:home_widget/home_widget.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../main.dart';
//

// class CryptoHomeWidget {
//   static const String appGroupId = 'com.example.crypto_rates';
//   static const String androidWidgetName = 'CryptoPriceWidget';
//   static const String iOSWidgetName = 'CryptoPriceWidget';
//
//   // Top cryptocurrencies to display
//   static const List<String> TOP_COINS = ['BTC', 'ETH', 'BNB'];
//
//   // Initialize the widget
//   static Future<void> initPlatformState() async {
//     await HomeWidget.setAppGroupId(appGroupId);
//
//     HomeWidget.registerInteractivityCallback((Uri? uri) async {
//       if (uri?.host == 'REFRESH_DATA') {
//         await updatePriceData(isRefresh: true);
//       }
//     });
//   }
//
//   static Future<void> updatePriceData({bool isRefresh = false}) async {
//     try {
//       prefs = await SharedPreferences.getInstance();
//
//       final String? cachedData = prefs.getString('crypto_data');
//       final DateTime? lastUpdateTime = DateTime.tryParse(prefs.getString('last_updated') ?? '');
//
//       // Check if the cached data is recent enough to use
//       if (cachedData != null && lastUpdateTime != null && DateTime.now().difference(lastUpdateTime) < Duration(hours: 1)) {
//         print('Using cached data');
//         return;
//       }
//
//       // Fetch ticker data from Binance
//       final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
//       final response = await http.get(url);
//
//       if (response.statusCode == 200) {
//         final List<dynamic> tickers = jsonDecode(response.body);
//         List<Map<String, dynamic>> widgetData = [];
//
//         for (String symbol in TOP_COINS) {
//           final ticker = tickers.firstWhere(
//                 (t) => t['symbol'] == '${symbol}USDT',
//             orElse: () => null,
//           );
//
//           if (ticker != null) {
//             final price = double.parse(ticker['lastPrice']);
//             final change = double.parse(ticker['priceChangePercent']);
//
//             widgetData.add({
//               'symbol': symbol,
//               'price': price.toStringAsFixed(2),
//               'change': change.toStringAsFixed(2),
//             });
//           }
//         }
//
//         if (widgetData.isNotEmpty) {
//           final String encodedData = json.encode(widgetData);
//           final String currentTime = DateTime.now().toLocal().toString();
//
//           await prefs.setString('crypto_data', encodedData);
//           await prefs.setString('last_updated', currentTime);
//
//           if (isRefresh) {
//             await HomeWidget.updateWidget(
//               androidName: androidWidgetName,
//               iOSName: iOSWidgetName,
//             );
//           }
//         }
//       } else {
//         throw Exception('Failed to fetch data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error updating widget: $e');
//     }
//   }
//
//   // static Future<void> updatePriceData({bool isRefresh = false}) async {
//   //   try {
//   //     prefs = await SharedPreferences.getInstance();
//   //
//   //     // Fetch ticker data from Binance
//   //     final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
//   //     final response = await http.get(url);
//   //
//   //     if (response.statusCode == 200) {
//   //       final List<dynamic> tickers = jsonDecode(response.body);
//   //       List<Map<String, dynamic>> widgetData = [];
//   //
//   //       // Process data for each top coin
//   //       for (String symbol in TOP_COINS) {
//   //         final ticker = tickers.firstWhere(
//   //               (t) => t['symbol'] == '${symbol}USDT',
//   //           orElse: () => null,
//   //         );
//   //
//   //         if (ticker != null) {
//   //           try {
//   //             final price = double.parse(ticker['lastPrice']);
//   //             final change = double.parse(ticker['priceChangePercent']);
//   //
//   //             widgetData.add({
//   //               'symbol': symbol,
//   //               'price': price.toStringAsFixed(2),
//   //               'change': change.toStringAsFixed(2),
//   //             });
//   //
//   //             print('Processed ${symbol}: Price: $price, Change: $change');
//   //           } catch (e) {
//   //             print('Error processing data for $symbol: $e');
//   //           }
//   //         }
//   //       }
//   //
//   //       if (widgetData.isNotEmpty) {
//   //         final String encodedData = json.encode(widgetData);
//   //         final String currentTime = DateTime.now().toLocal().toString();
//   //
//   //         // Save to both HomeWidget and SharedPreferences
//   //         await HomeWidget.saveWidgetData<String>('crypto_data', encodedData);
//   //         await HomeWidget.saveWidgetData<String>('last_updated', currentTime);
//   //         await prefs.setString('crypto_data', encodedData);
//   //         await prefs.setString('last_updated', currentTime);
//   //
//   //         // Force update the widget
//   //         if (isRefresh) {
//   //           await HomeWidget.updateWidget(
//   //             androidName: androidWidgetName,
//   //             iOSName: iOSWidgetName,
//   //           );
//   //         }
//   //
//   //         print('Widget data saved and update triggered');
//   //       } else {
//   //         print('No valid data to update widget');
//   //       }
//   //     } else {
//   //       throw Exception('Failed to fetch data: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     print('Error updating widget: $e');
//   //   }
//   // }
//
//   // Add this new method to handle refresh
//   static Future<void> handleRefresh() async {
//     await updatePriceData(isRefresh: true);
//   }
//
//   // Helper method to get WebSocket for real-time updates
//   static Uri getWebSocketUrl() {
//     final symbols = TOP_COINS.map((symbol) =>
//     '${symbol.toLowerCase()}usdt@ticker'
//     ).join('/');
//     return Uri.parse('wss://stream.binance.com:9443/ws/$symbols');
//   }
// }