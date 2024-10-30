
import 'package:crypto_rates/models/rates_api_service.dart';

import '../main.dart';

class ApiKeyManager {
  static List<String> _apiKeys = [apiKey, apiKey2, apiKey3, apiKey4];
  static int _currentKeyIndex = 0;
  static const String _lastUsedKeyIndexKey = 'last_used_key_index';
  static const String _apiCallsCountKey = 'api_calls_count';
  static const int maxCallsPerKey = 5000;

  static Future<String> getCurrentKey() async {
    _currentKeyIndex = prefs.getInt(_lastUsedKeyIndexKey) ?? 0;
    return _apiKeys[_currentKeyIndex];
  }

  static Future<void> incrementApiCalls() async {
    String countKey = '${_apiCallsCountKey}_$_currentKeyIndex';
    int currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);
  }

  static Future<String> getNextViableKey() async {
    String countKey = '${_apiCallsCountKey}_$_currentKeyIndex';
    int currentCount = prefs.getInt(countKey) ?? 0;

    if (currentCount >= maxCallsPerKey) {
      _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
      await prefs.setInt(_lastUsedKeyIndexKey, _currentKeyIndex);

      if (_currentKeyIndex == 0) {
        for (int i = 0; i < _apiKeys.length; i++) {
          await prefs.setInt('${_apiCallsCountKey}_$i', 0);
        }
      }
    }

    return _apiKeys[_currentKeyIndex];
  }

  static Future<void> resetCountsIfMonthChanged() async {
    final lastResetDate = prefs.getInt('last_reset_date');
    final currentDate = DateTime.now();

    if (lastResetDate == null) {
      await prefs.setInt('last_reset_date', currentDate.millisecondsSinceEpoch);
      return;
    }

    final lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetDate);
    if (lastReset.month != currentDate.month || lastReset.year != currentDate.year) {
      for (int i = 0; i < _apiKeys.length; i++) {
        await prefs.setInt('${_apiCallsCountKey}_$i', 0);
      }
      await prefs.setInt('last_reset_date', currentDate.millisecondsSinceEpoch);
    }
  }
}