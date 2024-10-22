import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/rates_api_service.dart';

class CryptoChart extends StatefulWidget {
  @override
  _CryptoChartState createState() => _CryptoChartState();
}

class _CryptoChartState extends State<CryptoChart> {
  Map<String, dynamic> cryptoRates = {};
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    initializeCache();
  }

  Future<void> initializeCache() async {
    prefs = await SharedPreferences.getInstance();
    await loadCachedData();
  }

  Future<void> loadCachedData({bool ignoreTimestamp = false}) async {
    final cachedData = prefs.getString(cacheKey);
    final cachedTimestamp = prefs.getInt(timestampKey);

    if (cachedData != null && (ignoreTimestamp || cachedTimestamp != null)) {
      if (ignoreTimestamp || DateTime.now().millisecondsSinceEpoch - cachedTimestamp! < cacheValidDuration.inMilliseconds) {
        setState(() {
          cryptoRates = Map<String, double>.from(
              json.decode(cachedData).map((key, value) =>
                  MapEntry(key, value.toDouble())
              )
          );
        });
        print('got data from cache');
        return;
      }
    }

    try {
      await fetchCryptoRates();
      print('did not get data from cache - fetched new data');
    } catch (e) {
      print('fetch failed, trying to load expired cache');
      if (cachedData != null) {
        await loadCachedData(ignoreTimestamp: true);
      } else {
        print('no cached data available');
        rethrow;
      }
    }
  }

  Future<void> fetchCryptoRates() async {
    try {
      final url = 'https://api.coinlayer.com/api/live?access_key=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'];

        final newRates = {
          'BTC': rates['BTC'].toDouble(),
          'ETH': rates['ETH'].toDouble(),
          'ADA': rates['ADA'].toDouble(),
          'SOL': rates['SOL'].toDouble(),
          'LTC': rates['LTC'].toDouble(),
          'DOGE': rates['DOGE'].toDouble(),
          'XRP': rates['XRP'].toDouble(),
          'LINK': rates['LINK'].toDouble(),
          'BCH': rates['BCH'].toDouble(),
          'BAT': rates['BAT'].toDouble(),
        };


        await prefs.setString(cacheKey, json.encode(newRates));
        await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

        setState(() {
          cryptoRates = newRates;
        });
      } else {
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching crypto rates: $e');
    }
  }

  // Future<void> refreshData() async {
  //   // Only refresh if cache is expired
  //   final cachedTimestamp = prefs.getInt(timestampKey);
  //   if (cachedTimestamp != null) {
  //     final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
  //     if (cacheAge < cacheValidDuration.inMilliseconds) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Using cached data. Next update available in ${((cacheValidDuration.inMilliseconds - cacheAge) / 1000 / 60).toStringAsFixed(1)} minutes'),
  //         ),
  //       );
  //       return;
  //     }
  //   }
  //   await fetchCryptoRates();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crypto Rates (USD)'),
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.refresh),
        //     onPressed: refreshData,
        //   ),
        // ],
      ),
      body: cryptoRates.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: cryptoRates.values.reduce((a, b) => (a as double) > (b as double) ? a : b) * 1.1,
                  barGroups: cryptoRates.entries
                      .map((entry) => BarChartGroupData(
                    x: entry.key.hashCode,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: Colors.lightBlueAccent,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  ))
                      .toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final title = cryptoRates.keys.firstWhere(
                                (key) => key.hashCode == value.toInt(),
                            orElse: () => '',
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value >= 1000
                                ? '\$${(value / 1000).toStringAsFixed(1)}K'
                                : '\$${value.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawHorizontalLine: true,
                    horizontalInterval: 1000,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}