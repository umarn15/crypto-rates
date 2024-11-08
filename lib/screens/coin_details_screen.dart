import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/alert_model.dart';
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
  String? _selectedCondition = 'above';
  final Color cardColor = Colors.blueGrey.shade700;
  final currentUser = FirebaseAuth.instance.currentUser;

  late Stream<QuerySnapshot> alertsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      alertsStream = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('alerts')
          .where('coinSymbol', isEqualTo: widget.coin.symbol)
          .snapshots();
    }
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
          'coinId': widget.coin.symbol,
          'coinSymbol': widget.coin.symbol,
          'targetPrice': double.parse(_priceController.text),
          'condition': _selectedCondition!,
          'isEnabled': true,
          'currentPrice': widget.coin.price,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await alertRef.set(alertData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Alert set for ${widget.coin.symbol} at \$${_priceController.text}'
            ),
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
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
              padding: EdgeInsets.all(12),
              child: Card(
                color: cardColor,
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(12),
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

            Padding(
              padding: EdgeInsets.all(12),
              child: Card(
                color: cardColor,
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(12),
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
                        SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.blueGrey.shade600,
                          value: _selectedCondition,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white,),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8)),
                            fillColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            filled: true,
                            labelText: 'Condition',
                            labelStyle: TextStyle(
                                color: Colors.grey.shade400
                            ),
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
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _priceController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8)
                            ),
                            errorStyle: TextStyle(
                              color: Colors.red,
                              fontSize: 14
                            ),
                            fillColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            filled: true,
                            labelText: 'Price in USD',
                            labelStyle: TextStyle(
                                color: Colors.grey.shade400
                            ),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: Colors.grey.shade400),
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

                            if (_selectedCondition == 'below' && price >= widget.coin.price) {
                              return 'Alert price must be below current price (${widget.coin.price.toStringAsFixed(2)})';
                            }

                            if (_selectedCondition == 'above' && price <= widget.coin.price) {
                              return 'Alert price must be above current price (${widget.coin.price.toStringAsFixed(2)})';
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
                              backgroundColor: Colors.blueGrey.shade900,
                            ),
                            onPressed: () async {
                              if(currentUser == null){
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text(
                                        'Error, You need to be logged in to set alerts'
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
            ),

            Padding(
              padding: EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                child: Card(
                  color: cardColor,
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Alerts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: currentUser != null ? alertsStream : null,
                          builder: (context, snapshot) {
                            if (currentUser == null) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Login to see your alerts',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No active alerts',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return Column(
                              children: snapshot.data!.docs.map((doc) {
                                final alert = Alert.fromMap(doc.data() as Map<String, dynamic>);
                                return _buildAlertItem(
                                  '${alert.condition.capitalize()} \$${alert.targetPrice.toStringAsFixed(2)}',
                                  alert.isEnabled,
                                  onDelete: () {
                                    showDialog(context: context, builder: (context){
                                      return AlertDialog(
                                        title: Text('Are you sure you want to delete this alert?',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),),
                                        actions: [
                                          TextButton(onPressed: (){
                                            Navigator.pop(context);
                                          }, child: Text('Cancel')),
                                          TextButton(onPressed: () async {
                                            await _deleteAlert(alert.id);
                                            Navigator.pop(context);
                                          }, child: Text('Yes'))
                                        ],
                                      );
                                    });
                                  },
                                  onToggle: () => _toggleAlert(alert),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
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



  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
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

  Widget _buildAlertItem(
      String condition,
      bool isEnabled, {
        required VoidCallback onDelete,
        required VoidCallback onToggle,
      }) {
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
                onChanged: (_) => onToggle(),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}