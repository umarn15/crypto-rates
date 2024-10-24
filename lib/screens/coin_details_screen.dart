import 'package:flutter/material.dart';

import '../models/coin_model.dart';

class CoinDetailScreen extends StatefulWidget {
  final Coin coin;

  CoinDetailScreen({required this.coin});

  @override
  _CoinDetailScreenState createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  final _alertFormKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  String? _selectedCondition = 'above'; // 'above' or 'below'

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.coin.name} (${widget.coin.symbol})'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '\$${widget.coin.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.coin.change24h >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: widget.coin.change24h >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      Text(
                        '${widget.coin.change24h.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 18,
                          color: widget.coin.change24h >= 0
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stats Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
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
                      Divider(),
                      _buildStatRow('Rank', '#${widget.coin.rank}'),
                      _buildStatRow(
                          'Market Cap',
                          '\$${(widget.coin.marketCap / 1e9).toStringAsFixed(2)}B'
                      ),
                      // Add more stats as needed
                    ],
                  ),
                ),
              ),
            ),

            // Price Alert Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
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
                        Divider(),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCondition,
                          decoration: InputDecoration(
                            labelText: 'Condition',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'above',
                              child: Text('Price goes above'),
                            ),
                            DropdownMenuItem(
                              value: 'below',
                              child: Text('Price goes below'),
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
                          decoration: InputDecoration(
                            labelText: 'Price in USD',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: () {
                              if (_alertFormKey.currentState!.validate()) {
                                // TODO: Implement alert functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Alert set for ${widget.coin.symbol} at \$${_priceController.text}'
                                    ),
                                  ),
                                );
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
            ),

            // Existing Alerts Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Alerts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(),
                      // Example alert items
                      _buildAlertItem(
                        'Above \$70,000',
                        true,
                        onDelete: () {
                          // TODO: Implement delete functionality
                        },
                      ),
                      _buildAlertItem(
                        'Below \$60,000',
                        false,
                        onDelete: () {
                          // TODO: Implement delete functionality
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
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

  Widget _buildAlertItem(String condition, bool isEnabled, {required VoidCallback onDelete}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            condition,
            style: TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Switch(
                value: isEnabled,
                onChanged: (value) {
                  // TODO: Implement enable/disable functionality
                },
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}