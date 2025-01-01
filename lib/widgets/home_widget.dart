import 'dart:async';
import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

class CryptoHomeWidget {
  static const String appGroupId = 'com.example.crypto_rates';
  static const String androidWidgetName = 'CryptoPriceWidget';
  static const String iOSWidgetName = 'CryptoPriceWidget';
  static const List<String> TOP_COINS = ['BTC', 'ETH', 'BNB'];

  static final http.Client _httpClient = http.Client();
  static final _lock = Lock();
  static DateTime? _lastUpdateTime;
  static const Duration _minUpdateInterval = Duration(minutes: 5);
  static bool _initialized = false;

  static Future<void> initPlatformState() async {
    if (_initialized) return;

    try {
      await HomeWidget.setAppGroupId(appGroupId);

      HomeWidget.registerInteractivityCallback((Uri? uri) async {
        if (uri?.host == 'REFRESH_DATA') {
          await updatePriceData(isRefresh: true);
        }
      });

      _initialized = true;
    } catch (e) {
      print('Widget initialization error: $e');
      _initialized = false;
    }
  }

  static Future<void> handleRefresh() async {
    return _lock.synchronized(() async {
      try {
        await updatePriceData(isRefresh: true);
      } catch (e) {
        print('Refresh error: $e');
        rethrow;
      }
    });
  }

  static Future<void> updatePriceData({bool isRefresh = false}) async {
    return _lock.synchronized(() async {
      if (!isRefresh && _lastUpdateTime != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceLastUpdate < _minUpdateInterval) {
          print('Skipping update: Too soon since last update');
          return;
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');

        final response = await _httpClient.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('API request timed out');
          },
        );

        if (response.statusCode != 200) {
          throw HttpException('Failed to fetch data: ${response.statusCode}');
        }

        final List<dynamic> tickers = jsonDecode(response.body);
        final widgetData = _processTickerData(tickers);

        if (widgetData.isNotEmpty) {
          await _saveWidgetData(widgetData, prefs, isRefresh);
        }
      } catch (e) {
        print('Error updating widget: $e');
        await _recoverLastKnownData(isRefresh);
      }
    });
  }

  static List<Map<String, dynamic>> _processTickerData(List<dynamic> tickers) {
    return TOP_COINS.map((symbol) {
      final ticker = tickers.firstWhere(
            (t) => t['symbol'] == '${symbol}USDT',
        orElse: () => null,
      );

      if (ticker == null) return null;

      try {
        final price = double.parse(ticker['lastPrice']);
        final change = double.parse(ticker['priceChangePercent']);

        return {
          'symbol': symbol,
          'price': price.toStringAsFixed(2),
          'change': change.toStringAsFixed(2),
        };
      } catch (e) {
        print('Error processing data for $symbol: $e');
        return null;
      }
    }).whereType<Map<String, dynamic>>().toList();
  }

  static Future<void> _saveWidgetData(
      List<Map<String, dynamic>> widgetData,
      SharedPreferences prefs,
      bool isRefresh,
      ) async {
    final String encodedData = json.encode(widgetData);
    final String currentTime = DateTime.now().toLocal().toString();

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
      await prefs.setString('crypto_data', encodedData);
      await prefs.setString('last_updated', currentTime);
    }
  }

  static Future<void> _recoverLastKnownData(bool isRefresh) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastData = prefs.getString('crypto_data');
      final lastUpdate = prefs.getString('last_updated');

      if (lastData != null && lastUpdate != null) {
        await Future.wait([
          HomeWidget.saveWidgetData<String>('crypto_data', lastData),
          HomeWidget.saveWidgetData<String>('last_updated', lastUpdate),
        ]);

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

  static void dispose() {
    _httpClient.close();
    _initialized = false;
  }
}

// class CryptoHomeWidget {
//   static const String appGroupId = 'com.example.crypto_rates';
//   static const String androidWidgetName = 'CryptoPriceWidget';
//   static const String iOSWidgetName = 'CryptoPriceWidget';
//   static const List<String> TOP_COINS = ['BTC', 'ETH', 'BNB'];
//
//   static final _httpClient = http.Client();
//   static bool _isUpdating = false;
//   static DateTime? _lastUpdateTime;
//   static const Duration _minUpdateInterval = Duration(minutes: 5);
//
//   static Future<void> initPlatformState() async {
//     try {
//       await HomeWidget.setAppGroupId(appGroupId);
//
//       HomeWidget.registerInteractivityCallback((Uri? uri) async {
//         if (uri?.host == 'REFRESH_DATA') {
//           await updatePriceData(isRefresh: true);
//         }
//       });
//     } catch (e) {
//       print('Widget initialization error: $e');
//     }
//   }
//
//   static Future<void> updatePriceData({bool isRefresh = false}) async {
//     if (!isRefresh && _lastUpdateTime != null) {
//       final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
//       if (timeSinceLastUpdate < _minUpdateInterval) {
//         print('Skipping update: Too soon since last update');
//         return;
//       }
//     }
//
//     if (_isUpdating) {
//       print('Update already in progress, skipping');
//       return;
//     }
//
//     _isUpdating = true;
//
//     try {
//       prefs = await SharedPreferences.getInstance();
//
//       final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
//       final response = await _httpClient.get(url).timeout(
//         Duration(seconds: 10),
//         onTimeout: () {
//           throw TimeoutException('API request timed out');
//         },
//       );
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
//             try {
//               final price = double.parse(ticker['lastPrice']);
//               final change = double.parse(ticker['priceChangePercent']);
//
//               widgetData.add({
//                 'symbol': symbol,
//                 'price': price.toStringAsFixed(2),
//                 'change': change.toStringAsFixed(2),
//               });
//             } catch (e) {
//               print('Error processing data for $symbol: $e');
//               widgetData.add({
//                 'symbol': symbol,
//                 'price': '0.00',
//                 'change': '0.00',
//               });
//             }
//           }
//         }
//
//         if (widgetData.isNotEmpty) {
//           final String encodedData = json.encode(widgetData);
//           final String currentTime = DateTime.now().toLocal().toString();
//
//           try {
//             await Future.wait([
//               HomeWidget.saveWidgetData<String>('crypto_data', encodedData),
//               HomeWidget.saveWidgetData<String>('last_updated', currentTime),
//               prefs.setString('crypto_data', encodedData),
//               prefs.setString('last_updated', currentTime),
//             ]);
//
//             _lastUpdateTime = DateTime.now();
//
//             if (isRefresh) {
//               await HomeWidget.updateWidget(
//                 androidName: androidWidgetName,
//                 iOSName: iOSWidgetName,
//               );
//             }
//           } catch (e) {
//             print('Error saving widget data: $e');
//             await prefs.setString('crypto_data', encodedData);
//             await prefs.setString('last_updated', currentTime);
//           }
//         } else {
//           print('No valid data to update widget');
//         }
//       } else {
//         throw Exception('Failed to fetch data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error updating widget: $e');
//       await _recoverLastKnownData(isRefresh);
//     } finally {
//       _isUpdating = false;
//     }
//   }
//
//   static Future<void> handleRefresh() async {
//     await updatePriceData(isRefresh: true);
//   }
//
//   static Future<void> _recoverLastKnownData(bool isRefresh) async {
//     try {
//       final lastData = prefs.getString('crypto_data');
//       final lastUpdate = prefs.getString('last_updated');
//
//       if (lastData != null && lastUpdate != null) {
//         await HomeWidget.saveWidgetData<String>('crypto_data', lastData);
//         await HomeWidget.saveWidgetData<String>('last_updated', lastUpdate);
//
//         if (isRefresh) {
//           await HomeWidget.updateWidget(
//             androidName: androidWidgetName,
//             iOSName: iOSWidgetName,
//           );
//         }
//       }
//     } catch (e) {
//       print('Error recovering last known data: $e');
//     }
//   }
//
//   static void dispose() {
//     _httpClient.close();
//   }
//
//   static Uri getWebSocketUrl() {
//     final symbols = TOP_COINS.map((symbol) =>
//     '${symbol.toLowerCase()}usdt@ticker'
//     ).join('/');
//     return Uri.parse('wss://stream.binance.com:9443/ws/$symbols');
//   }
// }