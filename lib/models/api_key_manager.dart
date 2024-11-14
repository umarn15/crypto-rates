import 'package:crypto_rates/models/rates_api_service.dart';
import '../main.dart';

class ApiKeyManager {
  static List<String> apiKeys = [apiKey, apiKey2, apiKey3, apiKey4, apiKey5, apiKey6, apiKey7, apiKey8, apiKey9];
  static int _currentKeyIndex = 0;
  static const String _lastUsedKeyIndexKey = 'last_used_key_index';
  static const String _apiCallsCountKey = 'api_calls_count';
  static const int maxCallsPerKey = 5000;

  static Future<String> getCurrentKey() async {
    _currentKeyIndex = prefs.getInt(_lastUsedKeyIndexKey) ?? 0;
    String countKey = '${_apiCallsCountKey}_$_currentKeyIndex';
    int currentCount = prefs.getInt(countKey) ?? 0;

    if (currentCount >= maxCallsPerKey) {
      return getNextViableKey();
    }
    return apiKeys[_currentKeyIndex];
  }

  static Future<void> incrementApiCalls() async {
    String countKey = '${_apiCallsCountKey}_$_currentKeyIndex';
    int currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);
  }

  static Future<String> getNextViableKey() async {
    int startIndex = _currentKeyIndex;
    int nextIndex = (_currentKeyIndex + 1) % apiKeys.length;

    // Try each key until we find one that hasn't reached the limit
    while (nextIndex != startIndex) {
      String countKey = '${_apiCallsCountKey}_$nextIndex';
      int count = prefs.getInt(countKey) ?? 0;

      if (count < maxCallsPerKey) {
        _currentKeyIndex = nextIndex;
        await prefs.setInt(_lastUsedKeyIndexKey, _currentKeyIndex);
        return apiKeys[_currentKeyIndex];
      }

      nextIndex = (nextIndex + 1) % apiKeys.length;
    }

    // If we've checked all keys and they're all exhausted, reset counts and start over
    await resetAllCounts();
    _currentKeyIndex = 0;
    await prefs.setInt(_lastUsedKeyIndexKey, _currentKeyIndex);
    return apiKeys[_currentKeyIndex];
  }

  static Future<void> resetAllCounts() async {
    for (int i = 0; i < apiKeys.length; i++) {
      await prefs.setInt('${_apiCallsCountKey}_$i', 0);
    }
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
      await resetAllCounts();
      await prefs.setInt('last_reset_date', currentDate.millisecondsSinceEpoch);
    }
  }
}