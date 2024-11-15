import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/api_key_manager.dart';

class CryptoHomeWidget {
  static const String appGroupId = 'com.example.crypto_rates';
  static const String androidWidgetName = 'CryptoPriceWidget';
  static const String iOSWidgetName = 'CryptoPriceWidget';

  // Initialize the widget
  static Future<void> initPlatformState() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  // Update widget data
  static Future<void> updatePriceData() async {
    try {
      prefs = await SharedPreferences.getInstance();

      await ApiKeyManager.resetCountsIfMonthChanged();
      String currentApiKey = await ApiKeyManager.getCurrentKey();
      bool success = false;

      for (int i = 0; i < ApiKeyManager.apiKeys.length; i++) {
        try {
          final url = Uri.parse('https://api.coinranking.com/v2/coins?limit=3');
          final response = await http.get(
            url,
            headers: {
              'x-access-token': currentApiKey,
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final coinsData = data['data']['coins'] as List;

            List<Map<String, dynamic>> widgetData = coinsData.take(3).map((coin) {
              return {
                'symbol': coin['symbol'],
                'price': double.parse(coin['price']).toStringAsFixed(2),
                'change': double.parse(coin['change']).toStringAsFixed(2),
              };
            }).toList();

            final String encodedData = json.encode(widgetData);
            print('Saving widget data: $encodedData');

            // Save to both HomeWidget and SharedPreferences
            await HomeWidget.saveWidgetData<String>('crypto_data', encodedData);
            await prefs.setString('crypto_data', encodedData);

            await HomeWidget.updateWidget(
              androidName: androidWidgetName,
              iOSName: iOSWidgetName,
            );

            print('Widget data saved and update triggered');
            await ApiKeyManager.incrementApiCalls();
            success = true;
            break;
          } else if (response.statusCode == 429) {
            currentApiKey = await ApiKeyManager.getNextViableKey();
            continue;
          }
        } catch (e) {
          print('Error in API call: $e');
          currentApiKey = await ApiKeyManager.getNextViableKey();
        }
      }

      if (!success) {
        print('Failed to update widget: All API keys exhausted');
      }
    } catch (e) {
      print('Error updating widget: $e');
    }
  }
}