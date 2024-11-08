import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart';
import '../models/api_key_manager.dart';
import '../models/rates_api_service.dart';

class CryptoChart extends StatefulWidget {
  @override
  _CryptoChartState createState() => _CryptoChartState();
}

class _CryptoChartState extends State<CryptoChart> {
  Map<String, List<FlSpot>> cryptoHistory = {};
  String selectedCrypto = 'BTC';
  final timePeriod = '24h';

  @override
  void initState() {
    super.initState();
    initializeCache();
  }


  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Crypto Rates USD'),
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigoAccent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButton<String>(
              value: selectedCrypto,
              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              iconSize: 24,
              elevation: 16,
              dropdownColor: Colors.indigoAccent,
              style: TextStyle(color: Colors.white, fontSize: 16),
              underline: SizedBox(),
              items: cryptoHistory.keys.map((String symbol) {
                return DropdownMenuItem<String>(
                  value: symbol,
                  child: Text(symbol, style: TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedCrypto = newValue;
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: cryptoHistory.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  width: size.width - 32,
                  child: LineChart(
                    LineChartData(
                      minY: (cryptoHistory[selectedCrypto]?.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) ?? 0) * 0.99,
                      maxY: (cryptoHistory[selectedCrypto]?.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) ?? 0) * 1.01,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              String formattedValue;
                              if (spot.y >= 1000000) {
                                formattedValue = '${(spot.y / 1000000).toStringAsFixed(2)}M';
                              } else if (spot.y >= 1000) {
                                formattedValue = '${(spot.y / 1000).toStringAsFixed(2)}K';
                              } else {
                                formattedValue = spot.y.toStringAsFixed(2);
                              }

                              return LineTooltipItem(
                                '\$$formattedValue',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: cryptoHistory[selectedCrypto] ?? [],
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.red.withOpacity(0.2),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value % 6 == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '${value.toInt()}h',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 80,
                            interval: 200,
                            getTitlesWidget: (value, meta) {

                      //     if (selectedCrypto == 'BTC' && value == meta.max) return const SizedBox.shrink();

                              if (value >= 1000000) {
                                return Text(
                                  '\$${(value / 1000000).toStringAsFixed(1)}M',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                );
                              } else if (value >= 1000) {
                                return Text(
                                  '\$${(value / 1000).toStringAsFixed(1)}K',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return Text(
                                '\$${value.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Colors.white,
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
                      gridData: FlGridData(
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> initializeCache() async {
    await loadCachedData();
  }

  Future<void> loadCachedData({bool ignoreTimestamp = false}) async {
    final cachedData = prefs.getString(cacheKey);
    final cachedTimestamp = prefs.getInt(timestampKey);

    if (cachedData != null && (ignoreTimestamp || cachedTimestamp != null)) {
      if (ignoreTimestamp || DateTime.now().millisecondsSinceEpoch - cachedTimestamp! < cacheValidDuration.inMilliseconds) {
        setState(() {
          cryptoHistory = Map<String, List<FlSpot>>.from(
            json.decode(cachedData).map((key, value) => MapEntry(
              key,
              (value as List).map((point) => FlSpot(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              )).toList(),
            )),
          );
        });
        print('got data from cache');
        return;
      }
    }

    try {
      await fetchCryptoHistory();
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

  Future<void> fetchCryptoHistory() async {
    await ApiKeyManager.resetCountsIfMonthChanged();
    String currentApiKey = await ApiKeyManager.getCurrentKey();
    bool success = false;

    for (int i = 0; i < 4; i++) {
      try {
        final url = Uri.parse('https://api.coinranking.com/v2/coins?limit=20&timePeriod=$timePeriod');

        final response = await http.get(
          url,
          headers: {
            'x-access-token': currentApiKey,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final coins = data['data']['coins'];

          Map<String, List<FlSpot>> history = {};

          for (var coin in coins) {
            String symbol = coin['symbol'];
            List<dynamic> sparkline = coin['sparkline'];

            List<FlSpot> points = [];
            for (int i = 0; i < sparkline.length; i++) {
              if (sparkline[i] != null) {
                points.add(FlSpot(
                  i.toDouble(),
                  double.parse(sparkline[i]),
                ));
              }
            }

            history[symbol] = points;
          }

          await prefs.setString(cacheKey, json.encode(history.map((key, value) =>
              MapEntry(key, value.map((spot) =>
              {'x': spot.x, 'y': spot.y}).toList()
              ))
          ));
          await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

          await ApiKeyManager.incrementApiCalls();

          setState(() {
            cryptoHistory = history;
            if (!history.containsKey(selectedCrypto)) {
              selectedCrypto = history.keys.first;
            }
          });

          success = true;
          print('Successfully fetched historical data using API key ${i + 1}');
          break;
        } else if (response.statusCode == 429) { // Too Many Requests
          print('API key ${i + 1} limit reached, trying next key');
          currentApiKey = await ApiKeyManager.getNextViableKey();
          continue;
        } else {
          throw Exception('Failed to load data: ${response.statusCode}');
        }
      } catch (e) {
        print('Error with API key ${i + 1}: $e');
        currentApiKey = await ApiKeyManager.getNextViableKey();
      }
    }

    if (!success) {
      print('All API keys exhausted');
    }
  }
}