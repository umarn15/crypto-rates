import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class CryptoHomeWidget {
  static const String appGroupId = 'com.example.crypto_rates';
  static const String androidWidgetName = 'CryptoPriceWidget';
  static const String iOSWidgetName = 'CryptoPriceWidget';

  // Top cryptocurrencies to display
  static const List<String> TOP_COINS = ['BTC', 'ETH', 'BNB'];

  // Initialize the widget
  static Future<void> initPlatformState() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  // Update widget data
  static Future<void> updatePriceData() async {
    try {
      prefs = await SharedPreferences.getInstance();

      // Fetch ticker data from Binance
      final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> tickers = jsonDecode(response.body);
        List<Map<String, dynamic>> widgetData = [];

        // Process data for each top coin
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

              print('Processed ${symbol}: Price: $price, Change: $change');
            } catch (e) {
              print('Error processing data for $symbol: $e');
            }
          }
        }

        if (widgetData.isNotEmpty) {
          final String encodedData = json.encode(widgetData);
          print('Saving widget data: $encodedData');

          // Save to both HomeWidget and SharedPreferences
          await HomeWidget.saveWidgetData<String>('crypto_data', encodedData);
          await prefs.setString('crypto_data', encodedData);

          // Update the widget
          await HomeWidget.updateWidget(
            androidName: androidWidgetName,
            iOSName: iOSWidgetName,
          );

          print('Widget data saved and update triggered');
        } else {
          print('No valid data to update widget');
        }
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  // Helper method to get WebSocket for real-time updates
  static Uri getWebSocketUrl() {
    final symbols = TOP_COINS.map((symbol) =>
    '${symbol.toLowerCase()}usdt@ticker'
    ).join('/');
    return Uri.parse('wss://stream.binance.com:9443/ws/$symbols');
  }
}