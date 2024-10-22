import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/rates_api_service.dart';

class CryptoChart extends StatefulWidget {
  @override
  _CryptoChartState createState() => _CryptoChartState();
}

class _CryptoChartState extends State<CryptoChart> {
  Map<String, double> cryptoRates = {};

  @override
  void initState() {
    super.initState();
    fetchCryptoRates();
  }

  Future<void> fetchCryptoRates() async {
    final url = 'https://api.coinlayer.com/api/live?access_key=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rates = data['rates'];

      setState(() {
        cryptoRates = {
          'BTC': rates['BTC'],
          'ETH': rates['ETH'],
          'ADA': rates['ADA'],
          'SOL': rates['SOL'],
          'LTC': rates['LTC'],
          'DOGE': rates['DOGE'],
          'XRP': rates['XRP'],
          'LINK': rates['LINK'],
          'BCH': rates['BCH'],
          'BAT': rates['BAT'],
        };
      });
    } else {
      print('Failed to load data: ${response.statusCode}');
    }
  }

  // Future<void> fetchCryptoRates() async {
  //   final cryptoSymbols = ['BTC', 'ETH', 'ADA', 'SOL', 'LTC', 'DOGE', 'XRP', 'LINK', 'BCH', 'BAT'];
  //
  //   try {
  //     final baseUrl = 'https://rest.coinapi.io/v1/exchangerate';
  //
  //     Map<String, double> rates = {};
  //
  //     for (String symbol in cryptoSymbols) {
  //       final url = Uri.parse('$baseUrl/$symbol/USD');
  //
  //       final response = await http.get(
  //         url,
  //         headers: {
  //           'X-CoinAPI-Key': apiKey,
  //           'Accept': 'application/json',
  //         },
  //       );
  //
  //       if (response.statusCode == 200) {
  //         final data = jsonDecode(response.body);
  //         rates[symbol] = data['rate'];
  //       } else {
  //         print('Failed to load $symbol: ${response.statusCode}');
  //         print('Response body: ${response.body}');
  //       }
  //
  //       await Future.delayed(Duration(milliseconds: 100));
  //     }
  //
  //     setState(() {
  //       cryptoRates = rates;
  //     });
  //   } catch (e) {
  //     print('Error fetching crypto rates: $e');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crypto Rates (USD)'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchCryptoRates,
          ),
        ],
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
                  maxY: cryptoRates.values.reduce((a, b) => a > b ? a : b) * 1.1,
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