import 'dart:async';
import 'dart:convert';
import 'package:crypto_rates/models/price_chart.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/coin_model.dart';
import '../services/binance_service.dart';

class PriceChartScreen extends StatefulWidget {
  final Coin initialCoin;
  const PriceChartScreen({super.key, required this.initialCoin});

  @override
  State<PriceChartScreen> createState() => _PriceChartScreenState();
}

class _PriceChartScreenState extends State<PriceChartScreen> {
  late StreamController<Coin> _coinController;
  late Coin currentCoin;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    currentCoin = widget.initialCoin;
    _coinController = StreamController<Coin>.broadcast();
    _setupWebSocket();
  }

  @override
  void dispose() {
    _coinController.close();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: PriceChart(
            coinStream: _coinController.stream,
            initialCoin: widget.initialCoin
        ),
      ),
    );
  }

  void _setupWebSocket() {
    try {
      _channel?.sink.close();

      _channel = BinanceService.getSingleCoinWebSocket(widget.initialCoin.symbol);

      _channel!.stream.listen(
            (dynamic message) {
          try {
            final data = jsonDecode(message);

            final double newPrice = double.parse(data['c']);
            final double newChange = double.parse(data['P']);

            if (currentCoin.price != newPrice || currentCoin.change24h != newChange) {
              final updatedCoin = currentCoin.copyWith(
                price: newPrice,
                change24h: newChange,
                marketCap: double.parse(data['q']) * newPrice,
              );

              if (mounted) {
                setState(() {
                  currentCoin = updatedCoin;
                });
                _coinController.add(updatedCoin);
              }
            }
          } catch (e) {
            print('Error processing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket Error: $error');
          Future.delayed(Duration(seconds: 5), _setupWebSocket);
        },
        onDone: () {
          print('WebSocket connection closed');
          Future.delayed(Duration(seconds: 5), _setupWebSocket);
        },
      );
    } catch (e) {
      print('Error setting up WebSocket: $e');
      Future.delayed(Duration(seconds: 5), _setupWebSocket);
    }
  }

}
