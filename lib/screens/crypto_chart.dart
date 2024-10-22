import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart';
import '../models/rates_api_service.dart';

class CryptoChart extends StatefulWidget {
  @override
  _CryptoChartState createState() => _CryptoChartState();
}

class _CryptoChartState extends State<CryptoChart> {
  Map<String, List<FlSpot>> cryptoHistory = {};
  String selectedCrypto = 'BTC';
  final timePeriod = '24h'; // can be 24h, 7d, 30d, 1y, 5y

  @override
  void initState() {
    super.initState();
    initializeCache();
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

  Future<void> fetchCryptoHistory() async {
    try {
      final url = Uri.parse('https://api.coinranking.com/v2/coins?limit=10&timePeriod=$timePeriod');

      final response = await http.get(
        url,
        headers: {
          'x-access-token': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coins = data['data']['coins'];

        Map<String, List<FlSpot>> history = {};

        for (var coin in coins) {
          String symbol = coin['symbol'];
          List<dynamic> sparkline = coin['sparkline'];

          // Convert timestamp and price data to FlSpot points
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

        // Cache the data
        await prefs.setString(cacheKey, json.encode(history.map((key, value) =>
            MapEntry(key, value.map((spot) =>
            {'x': spot.x, 'y': spot.y}).toList()
            ))
        ));
        await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

        setState(() {
          cryptoHistory = history;
          if (!history.containsKey(selectedCrypto)) {
            selectedCrypto = history.keys.first;
          }
        });

        print('Successfully fetched historical data');
      } else {
        print('Failed to load data: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load crypto history');
      }
    } catch (e) {
      print('Error fetching crypto history: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crypto Rates USD'),
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
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
              dropdownColor: Colors.blueAccent,
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
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
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
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
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
                                  color: Colors.black,
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
                          if (value >= 1000000) {
                            return Text(
                              '\$${(value / 1000000).toStringAsFixed(1)}M',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                              ),
                            );
                          } else if (value >= 1000) {
                            return Text(
                              '\$${(value / 1000).toStringAsFixed(1)}K',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                              ),
                            );
                          }
                          return Text(
                            '\$${value.toStringAsFixed(0)}',
                            style: TextStyle(
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
                  gridData: FlGridData(
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> fetchCryptoRates() async {  // from coin api https://customerportal.coinapi.io/
  //   final cryptoSymbols = ['BTC', 'ETH', 'ADA', 'SOL', 'LTC', 'DOGE', 'XRP', 'LINK', 'BCH', 'BAT'];
  //
  //   try {
// final String coinApiKey = '16EA263D-70FF-46BF-A6D8-43A5A9CECD86'; // https://customerportal.coinapi.io/
  //     final baseUrl = 'https://rest.coinapi.io/v1/exchangerate';
  //     Map<String, double> rates = {};
  //
  //     for (String symbol in cryptoSymbols) {
  //       final url = Uri.parse('$baseUrl/$symbol/USD');
  //
  //       final response = await http.get(
  //         url,
  //         headers: {
  //           'X-CoinAPI-Key': coinApiKey,
  //           'Accept': 'application/json',
  //         },
  //       );
  //
  //       if (response.statusCode == 200) {
  //         final data = jsonDecode(response.body);
  //         rates[symbol] = data['rate'].toDouble();
  //
  //       } else {
  //         print('Failed to load $symbol: ${response.statusCode}');
  //         print('Response body: ${response.body}');
  //       }
  //
  //       // Rate limiting to avoid API throttling
  //       await Future.delayed(Duration(milliseconds: 100));
  //     }
  //
  //     if (rates.isNotEmpty) {
  //       await prefs.setString(cacheKey, json.encode(rates));
  //       await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
  //
  //       setState(() {
  //         cryptoRates = rates;
  //       });
  //     } else {
  //       throw Exception('No rates were fetched successfully');
  //     }
  //
  //   } catch (e) {
  //     print('Error fetching crypto rates: $e');
  //     rethrow;
  //   }
  // }

// Future<void> fetchCryptoRates() async {  // from coin layer api https://coinlayer.com/dashboard
//   try {
// final String apiKey = '3e4d3c79113313b97c37cdadcd6aa468';
//     final url = 'https://api.coinlayer.com/api/live?access_key=$apiKey';
//     final response = await http.get(Uri.parse(url));
//
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       final rates = data['rates'];
//
//       final newRates = {
//         'BTC': rates['BTC'].toDouble(),
//         'ETH': rates['ETH'].toDouble(),
//         'ADA': rates['ADA'].toDouble(),
//         'SOL': rates['SOL'].toDouble(),
//         'LTC': rates['LTC'].toDouble(),
//         'DOGE': rates['DOGE'].toDouble(),
//         'XRP': rates['XRP'].toDouble(),
//         'LINK': rates['LINK'].toDouble(),
//         'BCH': rates['BCH'].toDouble(),
//         'BAT': rates['BAT'].toDouble(),
//       };
//
//
//       await prefs.setString(cacheKey, json.encode(newRates));
//       await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
//
//       setState(() {
//         cryptoRates = newRates;
//       });
//     } else {
//       print('Failed to load data: ${response.statusCode}');
//     }
//   } catch (e) {
//     print('Error fetching crypto rates: $e');
//   }
// }
}