import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'coin_model.dart';

class PriceChartData {
  final double price;
  final DateTime timestamp;

  PriceChartData(this.price, this.timestamp);
}

class PriceChart extends StatefulWidget {
  final Stream<Coin> coinStream;
  final Coin initialCoin;

  const PriceChart({
    Key? key,
    required this.coinStream,
    required this.initialCoin,
  }) : super(key: key);

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  final List<PriceChartData> pricePoints = [];
  double minY = 0;
  double maxY = 0;

  @override
  void initState() {
    super.initState();
    _initializeHistoricalData();

    widget.coinStream.listen((coin) {
      _addPricePoint(coin.price);
    });
  }

  Future<void> _initializeHistoricalData() async {
    try {
      final now = DateTime.now();
      _addPricePoint(widget.initialCoin.price);

      final response = await http.get(
        Uri.parse(
            'https://api.binance.com/api/v3/klines?symbol=${widget.initialCoin.symbol}USDT&interval=1h&limit=24'
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        for (var item in data) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(item[0]);
          final price = double.parse(item[4]);

          if (timestamp.isAfter(now.subtract(const Duration(hours: 24)))) {
            _addHistoricalPrice(price, timestamp);
          }
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error fetching historical data: $e');
    }
  }

  void _addHistoricalPrice(double price, DateTime timestamp) {
    pricePoints.add(PriceChartData(price, timestamp));
    _updateMinMax();
  }

  void _addPricePoint(double price) {
    if (!mounted) return;

    final now = DateTime.now();

    setState(() {
      pricePoints.add(PriceChartData(price, now));
      pricePoints.removeWhere(
              (point) => point.timestamp.isBefore(now.subtract(const Duration(hours: 24)))
      );
      _updateMinMax();
    });
  }

  void _updateMinMax() {
    if (pricePoints.isNotEmpty) {
      minY = pricePoints.map((point) => point.price).reduce(min);
      maxY = pricePoints.map((point) => point.price).reduce(max);
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}k';
    }
    return '${price.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {

    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade800.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '24h Price Chart',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm:ss').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: pricePoints.length < 2
                  ? const Center(child: CircularProgressIndicator())
                  : LineChart(
                LineChartData(
                  minY: minY * 0.999,
                  maxY: maxY * 1.001,
                  clipData: FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    horizontalInterval: (maxY - minY) / 4,
                    verticalInterval: Duration(hours: 6).inMilliseconds.toDouble(),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: Duration(hours: 6).inMilliseconds.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                DateFormat('HH:mm').format(date),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        interval: (maxY - minY) / 4,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              _formatPrice(value),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                 lineBarsData: [
                    LineChartBarData(
                      spots: pricePoints.map((point) => FlSpot(
                        point.timestamp.millisecondsSinceEpoch.toDouble(),
                        point.price,
                      )).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                 ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                          return LineTooltipItem(
                            '${DateFormat('MM/dd HH:mm').format(date)}\n${_formatPrice(spot.y)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                      tooltipMargin: 8,
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
}