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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crypto Rates')),
      body: cryptoRates.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: BarChart(
          BarChartData(
            barGroups: cryptoRates.entries
                .map((entry) => BarChartGroupData(
              x: entry.key.hashCode, // Use a unique value as x
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  color: Colors.lightBlueAccent,
                  width: 20,
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
                    return Text(
                      title,
                      style: const TextStyle(color: Colors.black, fontSize: 10),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.black, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }
}