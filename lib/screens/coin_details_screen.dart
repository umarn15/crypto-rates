import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../Auth/login_screen.dart';
import '../models/alert_model.dart';
import '../models/coin_model.dart';
import '../models/price_chart.dart';
import '../services/binance_service.dart';

class CoinDetailScreen extends StatefulWidget {
  final Coin initialCoin;

  CoinDetailScreen({required this.initialCoin});

  @override
  _CoinDetailScreenState createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  final _alertFormKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  String? _selectedCondition = 'above';
  final Color cardColor = Colors.blueGrey.shade800;
  final currentUser = FirebaseAuth.instance.currentUser;
  final bool noUser = FirebaseAuth.instance.currentUser == null;

  late Stream<QuerySnapshot> alertsStream;
  late StreamController<Coin> _coinController;
  WebSocketChannel? _channel;
  late Coin currentCoin;

  @override
  void initState() {
    super.initState();
    currentCoin = widget.initialCoin;
    _coinController = StreamController<Coin>.broadcast();
    _initializeStreams();
    _setupWebSocket();
  }

  void _initializeStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      alertsStream = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('alerts')
          .where('coinSymbol', isEqualTo: widget.initialCoin.symbol)
          .snapshots();
    }
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

  @override
  void dispose() {
    _channel?.sink.close();
    _coinController.close();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _setAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: You need to be logged in to set alerts'),
        ),
      );
      return;
    }

    if (_alertFormKey.currentState!.validate()) {
      try {
        final alertRef = FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('alerts')
            .doc();

        final Map<String, dynamic> alertData = {
          'id': alertRef.id,
          'coinId': currentCoin.symbol,
          'coinSymbol': currentCoin.symbol,
          'targetPrice': double.parse(_priceController.text),
          'condition': _selectedCondition!,
          'isEnabled': true,
          'currentPrice': currentCoin.price,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await alertRef.set(alertData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert set for ${currentCoin.symbol} at \$${_priceController.text}'),
          ),
        );

        _priceController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error setting alert: $e'),
          ),
        );
      }
    }
  }

  Future<void> _toggleAlert(Alert alert) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('alerts')
          .doc(alert.id)
          .update({'isEnabled': !alert.isEnabled});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error toggling alert: $e'),
        ),
      );
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('alerts')
          .doc(alertId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error deleting alert: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          '${currentCoin.name} (${currentCoin.symbol})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _setupWebSocket,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price Header Section
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Text(
                      '\$${currentCoin.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentCoin.change24h >= 0
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentCoin.change24h >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: currentCoin.change24h >= 0
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${currentCoin.change24h.abs().toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 16,
                              color: currentCoin.change24h >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Statistics Card
              Card(
                elevation: 0,
                color: cardColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Divider(height: 24, color: Colors.grey.withOpacity(0.2)),
                      _buildStatRow(
                        'Market Rank',
                        '#${currentCoin.rank}',
                        Icons.leaderboard,
                      ),
                      _buildStatRow(
                        'Market Cap',
                        '\$${(currentCoin.marketCap / 1e9).toStringAsFixed(2)}B',
                        Icons.analytics,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6,),
              // Alert Form Card
              Card(
                elevation: 0,
                color: cardColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Form(
                    key: _alertFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Price Alert',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.blueGrey.shade900,
                          value: _selectedCondition,
                          icon: Icon(Icons.arrow_drop_down),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Color(0xFF1B2327),
                            labelText: 'Condition',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'above',
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_upward, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Price goes above', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'below',
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_downward, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Price goes below', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCondition = value;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Color(0xFF1B2327),
                            labelText: 'Price in USD',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: Icon(Icons.attach_money, size: 20),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price';
                            }
                            final double? price = double.tryParse(value);
                            if (price == null) {
                              return 'Please enter a valid number';
                            }
                            if (_selectedCondition == 'below' && price >= currentCoin.price) {
                              return 'Alert price must be below current price';
                            }
                            if (_selectedCondition == 'above' && price <= currentCoin.price) {
                              return 'Alert price must be above current price';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Please login to set alerts'),
                                      ],
                                    ),
                                    action: SnackBarAction(
                                      label: 'Login',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                                        );
                                      },
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (_alertFormKey.currentState!.validate()) {
                                await _setAlert();
                              }
                            },
                            child: Text(
                              'Set Alert',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6),
              PriceChart(
                coinStream: _coinController.stream,
                initialCoin: currentCoin,
              ),
              SizedBox(height: 12),
              // Saved Alerts Card
              Card(
                elevation: 0,
                color: cardColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.white,),
                          SizedBox(width: 8),
                          Text(
                            'Saved Alerts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: currentUser != null ? alertsStream : null,
                        builder: (context, snapshot) {
                          if (currentUser == null) {
                            return _buildEmptyState(
                              showLoginButton: currentUser == null,
                              icon: Icons.lock,
                              message: 'Login to see your alerts',
                            );
                          }

                          if (snapshot.hasError) {
                            return _buildEmptyState(
                              showLoginButton: currentUser == null,
                              icon: Icons.error_outline,
                              message: 'Error loading alerts',
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return _buildEmptyState(
                              showLoginButton: currentUser == null,
                              icon: Icons.notifications_off,
                              message: 'No active alerts',
                            );
                          }

                          return Column(
                            children: snapshot.data!.docs.map((doc) {
                              final alert = Alert.fromMap(doc.data() as Map<String, dynamic>);
                              return _buildAlertItem(alert);
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.white,),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Alert alert) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isEnabled
              ? Colors.blueGrey.shade700
              : Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.condition == 'above'
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: alert.condition == 'above'
                ? Colors.green
                : Colors.red,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '\$${alert.targetPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: alert.isEnabled ? Colors.white : Colors.grey,
              ),
            ),
          ),
          Switch(
            value: alert.isEnabled,
            onChanged: (_) => _toggleAlert(alert),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            onPressed: () => _showDeleteDialog(alert),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required bool showLoginButton,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          if (showLoginButton) ...[
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(Alert alert) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Alert',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this price alert for ${alert.coinSymbol}?',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _deleteAlert(alert.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}