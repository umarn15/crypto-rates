import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/forex_pair_model.dart';
import '../services/forex_service.dart';

class ForexDetailScreen extends StatefulWidget {
  final ForexPair initialPair;

  const ForexDetailScreen({Key? key, required this.initialPair}) : super(key: key);

  @override
  _ForexDetailScreenState createState() => _ForexDetailScreenState();
}

class _ForexDetailScreenState extends State<ForexDetailScreen> {
//  final _alertFormKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
 // String? _selectedCondition = 'above';
  final Color cardColor = Colors.blueGrey.shade800;
  final currentUser = FirebaseAuth.instance.currentUser;

  late Stream<QuerySnapshot> alertsStream;
  late StreamController<ForexPair> _pairController;
  WebSocketChannel? _channel;
  late ForexPair currentPair;

  @override
  void initState() {
    super.initState();
    currentPair = widget.initialPair;
    _pairController = StreamController<ForexPair>.broadcast();
    _initializeStreams();
    _setupWebSocket();
  }

  void _initializeStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      alertsStream = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('forex_alerts')
          .where('pairSymbol', isEqualTo: widget.initialPair.symbol)
          .snapshots();
    }
  }

  void _setupWebSocket() {
    double accumulatedVolume = 0;
    try {

      _channel?.sink.close();

      _channel = WebSocketChannel.connect(
        Uri.parse('wss://socket.polygon.io/forex'),
      );

      _channel!.sink.add(json.encode({
        "action": "auth",
        "params": ForexService.API_KEY
      }));

      _channel!.sink.add(json.encode({
        "action": "subscribe",
        "params": ["C.${widget.initialPair.symbol}"]
      }));

      _channel!.stream.listen(
            (dynamic message) {
          try {
            final data = jsonDecode(message);
            if (data is List && data.isNotEmpty && data[0]['ev'] == 'C') {
              final tickData = data[0];
              final double newPrice = tickData['bp'].toDouble();

              final double previousPrice = currentPair.price;
              final double newChange = previousPrice != 0
                  ? ((newPrice - previousPrice) / previousPrice) * 100
                  : 0.0;

              final double tickVolume = tickData['v']?.toDouble() ?? 0;
              accumulatedVolume += tickVolume;

              if (currentPair.price != newPrice || currentPair.change24h != newChange) {
                final updatedPair = currentPair.copyWith(
                  price: newPrice,
                  change24h: newChange,
                  volume: accumulatedVolume,
                );

                if (mounted) {
                  setState(() {
                    currentPair = updatedPair;
                  });
                  _pairController.add(updatedPair);
                }
              }
            }
          } catch (e) {
            print('Error processing WebSocket message: $e');
          }
        },        onError: (error) {
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

  // Future<void> _setAlert() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         backgroundColor: Colors.red,
  //         content: Text('Error: You need to be logged in to set alerts'),
  //       ),
  //     );
  //     return;
  //   }
  //
  //   if (_alertFormKey.currentState!.validate()) {
  //     try {
  //       final alertRef = FirebaseFirestore.instance
  //           .collection('Users')
  //           .doc(user.uid)
  //           .collection('forex_alerts')
  //           .doc();
  //
  //       final Map<String, dynamic> alertData = {
  //         'id': alertRef.id,
  //         'pairSymbol': currentPair.symbol,
  //         'baseCurrency': currentPair.baseCurrency,
  //         'quoteCurrency': currentPair.quoteCurrency,
  //         'targetPrice': double.parse(_priceController.text),
  //         'condition': _selectedCondition!,
  //         'isEnabled': true,
  //         'currentPrice': currentPair.price,
  //         'createdAt': FieldValue.serverTimestamp(),
  //       };
  //
  //       await alertRef.set(alertData);
  //
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Alert set for ${currentPair.symbol} at \$${_priceController.text}'),
  //         ),
  //       );
  //
  //       _priceController.clear();
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           backgroundColor: Colors.red,
  //           content: Text('Error setting alert: $e'),
  //         ),
  //       );
  //     }
  //   }
  // }

  // Future<void> _toggleAlert(Alert alert) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;
  //
  //   try {
  //     await FirebaseFirestore.instance
  //         .collection('Users')
  //         .doc(user.uid)
  //         .collection('forex_alerts')
  //         .doc(alert.id)
  //         .update({'isEnabled': !alert.isEnabled});
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         backgroundColor: Colors.red,
  //         content: Text('Error toggling alert: $e'),
  //       ),
  //     );
  //   }
  // }
  //
  // Future<void> _deleteAlert(String alertId) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;
  //
  //   try {
  //     await FirebaseFirestore.instance
  //         .collection('Users')
  //         .doc(user.uid)
  //         .collection('forex_alerts')
  //         .doc(alertId)
  //         .delete();
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         backgroundColor: Colors.red,
  //         content: Text('Error deleting alert: $e'),
  //       ),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          '${currentPair.name}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _setupWebSocket,
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
                margin: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      currentPair.price.toStringAsFixed(4),
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
                        color: currentPair.change24h >= 0
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentPair.change24h >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: currentPair.change24h >= 0
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${currentPair.change24h.abs().toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 16,
                              color: currentPair.change24h >= 0
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

              // Info Card
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
                        'Info',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Divider(height: 24, color: Colors.grey.withOpacity(0.2)),
                      _buildStatRow(
                        'Base Currency',
                        currentPair.baseCurrency,
                        Icons.currency_exchange,
                      ),
                      _buildStatRow(
                        'Quote Currency',
                        currentPair.quoteCurrency,
                        Icons.currency_exchange,
                      ),
                      // _buildStatRow(
                      //   'Volume',
                      //   '${(currentPair.volume / 1e6).toStringAsFixed(2)}M',
                      //   Icons.analytics,
                      // ),
                    ],
                  ),
                ),
              ),
              // SizedBox(height: 20),
              // // Alert Form Card
              // Card(
              //   elevation: 0,
              //   color: cardColor.withOpacity(0.5),
              //   shape: RoundedRectangleBorder(
              //     borderRadius: BorderRadius.circular(16),
              //   ),
              //   child: Padding(
              //     padding: EdgeInsets.all(20),
              //     child: Form(
              //       key: _alertFormKey,
              //       child: Column(
              //         crossAxisAlignment: CrossAxisAlignment.start,
              //         children: [
              //           Text(
              //             'Set Price Alert',
              //             style: TextStyle(
              //               fontSize: 20,
              //               fontWeight: FontWeight.bold,
              //             ),
              //           ),
              //           SizedBox(height: 20),
              //           DropdownButtonFormField<String>(
              //             dropdownColor: Colors.blueGrey.shade900,
              //             value: _selectedCondition,
              //             icon: Icon(Icons.arrow_drop_down),
              //             decoration: InputDecoration(
              //               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //               border: OutlineInputBorder(
              //                 borderRadius: BorderRadius.circular(12),
              //                 borderSide: BorderSide.none,
              //               ),
              //               filled: true,
              //               fillColor: Color(0xFF1B2327),
              //               labelText: 'Condition',
              //               labelStyle: TextStyle(color: Colors.grey.shade400),
              //             ),
              //             items: [
              //               DropdownMenuItem(
              //                 value: 'above',
              //                 child: Row(
              //                   children: [
              //                     Icon(Icons.arrow_upward, size: 18, color: Colors.green),
              //                     SizedBox(width: 8),
              //                     Text('Price goes above', style: TextStyle(color: Colors.white)),
              //                   ],
              //                 ),
              //               ),
              //               DropdownMenuItem(
              //                 value: 'below',
              //                 child: Row(
              //                   children: [
              //                     Icon(Icons.arrow_downward, size: 18, color: Colors.red),
              //                     SizedBox(width: 8),
              //                     Text('Price goes below', style: TextStyle(color: Colors.white)),
              //                   ],
              //                 ),
              //               ),
              //             ],
              //             onChanged: (value) {
              //               setState(() {
              //                 _selectedCondition = value;
              //               });
              //             },
              //           ),
              //           SizedBox(height: 16),
              //           TextFormField(
              //             controller: _priceController,
              //             style: TextStyle(color: Colors.white),
              //             decoration: InputDecoration(
              //               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //               border: OutlineInputBorder(
              //                 borderRadius: BorderRadius.circular(12),
              //                 borderSide: BorderSide.none,
              //               ),
              //               filled: true,
              //               fillColor: Color(0xFF1B2327),
              //               labelText: 'Price in USD',
              //               labelStyle: TextStyle(color: Colors.grey.shade400),
              //               prefixIcon: Icon(Icons.attach_money, size: 20),
              //             ),
              //             keyboardType: TextInputType.numberWithOptions(decimal: true),
              //             validator: (value) {
              //               if (value == null || value.isEmpty) {
              //                 return 'Please enter a price';
              //               }
              //               final double? price = double.tryParse(value);
              //               if (price == null) {
              //                 return 'Please enter a valid number';
              //               }
              //               if (_selectedCondition == 'below' && price >= widget.initialPair.price) {
              //                 return 'Alert price must be below current price';
              //               }
              //               if (_selectedCondition == 'above' && price <= widget.initialPair.price) {
              //                 return 'Alert price must be above current price';
              //               }
              //               return null;
              //             },
              //           ),
              //           // SizedBox(height: 20),
              //           // SizedBox(
              //           //   width: double.infinity,
              //           //   child: ElevatedButton(
              //           //     style: ElevatedButton.styleFrom(
              //           //       padding: EdgeInsets.symmetric(vertical: 16),
              //           //       backgroundColor: Theme.of(context).primaryColor,
              //           //       shape: RoundedRectangleBorder(
              //           //         borderRadius: BorderRadius.circular(12),
              //           //       ),
              //           //       elevation: 0,
              //           //     ),
              //           //     onPressed: () async {
              //           //       if (currentUser == null) {
              //           //         ScaffoldMessenger.of(context).showSnackBar(
              //           //           SnackBar(
              //           //             content: Row(
              //           //               children: [
              //           //                 Icon(Icons.error_outline, color: Colors.white),
              //           //                 SizedBox(width: 8),
              //           //                 Text('Please login to set alerts'),
              //           //               ],
              //           //             ),
              //           //             action: SnackBarAction(
              //           //               label: 'Login',
              //           //               textColor: Colors.white,
              //           //               onPressed: () {
              //           //                 Navigator.push(
              //           //                   context,
              //           //                   MaterialPageRoute(builder: (context) => const LoginScreen()),
              //           //                 );
              //           //               },
              //           //             ),
              //           //             backgroundColor: Colors.red,
              //           //             behavior: SnackBarBehavior.floating,
              //           //             shape: RoundedRectangleBorder(
              //           //               borderRadius: BorderRadius.circular(10),
              //           //             ),
              //           //           ),
              //           //         );
              //           //         return;
              //           //       }
              //           //       if (_alertFormKey.currentState!.validate()) {
              //           //         await _setAlert();
              //           //       }
              //           //     },
              //           //     child: Text(
              //           //       'Set Alert',
              //           //       style: TextStyle(
              //           //           fontSize: 16,
              //           //           fontWeight: FontWeight.bold,
              //           //           color: Colors.white
              //           //       ),
              //           //     ),
              //           //   ),
              //           // ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              // SizedBox(height: 20),
              //
              // // Saved Alerts Card
              // Card(
              //   elevation: 0,
              //   color: cardColor.withOpacity(0.5),
              //   shape: RoundedRectangleBorder(
              //     borderRadius: BorderRadius.circular(16),
              //   ),
              //   child: Padding(
              //     padding: EdgeInsets.all(20),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Row(
              //           children: [
              //             Icon(Icons.notifications_active, color: Colors.white,),
              //             SizedBox(width: 8),
              //             Text(
              //               'Saved Alerts',
              //               style: TextStyle(
              //                 fontSize: 20,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //           ],
              //         ),
              //         // SizedBox(height: 16),
              //         // StreamBuilder<QuerySnapshot>(
              //         //   stream: currentUser != null ? alertsStream : null,
              //         //   builder: (context, snapshot) {
              //         //     if (currentUser == null) {
              //         //       return _buildEmptyState(
              //         //         showLoginButton: currentUser == null,
              //         //         icon: Icons.lock,
              //         //         message: 'Login to see your alerts',
              //         //       );
              //         //     }
              //         //
              //         //     if (snapshot.hasError) {
              //         //       return _buildEmptyState(
              //         //         showLoginButton: currentUser == null,
              //         //         icon: Icons.error_outline,
              //         //         message: 'Error loading alerts',
              //         //       );
              //         //     }
              //         //
              //         //     if (snapshot.connectionState == ConnectionState.waiting) {
              //         //       return Center(
              //         //         child: CircularProgressIndicator(strokeWidth: 2),
              //         //       );
              //         //     }
              //         //
              //         //     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              //         //       return _buildEmptyState(
              //         //         showLoginButton: currentUser == null,
              //         //         icon: Icons.notifications_off,
              //         //         message: 'No active alerts',
              //         //       );
              //         //     }
              //         //
              //         //     return Column(
              //         //       children: snapshot.data!.docs.map((doc) {
              //         //         final alert = Alert.fromMap(doc.data() as Map<String, dynamic>);
              //         //         return _buildAlertItem(alert);
              //         //       }).toList(),
              //         //     );
              //         //   },
              //         // ),
              //       ],
              //     ),
              //   ),
              // ),
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

  // Widget _buildAlertItem(Alert alert) {
  //   return Container(
  //     margin: EdgeInsets.only(bottom: 12),
  //     padding: EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.blueGrey.shade900,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: alert.isEnabled
  //             ? Colors.blueGrey.shade700
  //             : Colors.grey.shade800,
  //         width: 1,
  //       ),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(
  //           alert.condition == 'above'
  //               ? Icons.arrow_upward
  //               : Icons.arrow_downward,
  //           color: alert.condition == 'above'
  //               ? Colors.green
  //               : Colors.red,
  //           size: 20,
  //         ),
  //         SizedBox(width: 12),
  //         Expanded(
  //           child: Text(
  //             '\$${alert.targetPrice.toStringAsFixed(2)}',
  //             style: TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.w500,
  //               color: alert.isEnabled ? Colors.white : Colors.grey,
  //             ),
  //           ),
  //         ),
  //         Switch(
  //           value: alert.isEnabled,
  //           onChanged: (_) => _toggleAlert(alert),
  //         ),
  //         IconButton(
  //           icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
  //           onPressed: () => _showDeleteDialog(alert),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildEmptyState({
  //   required IconData icon,
  //   required String message,
  //   required bool showLoginButton,
  // }) {
  //   return Container(
  //     padding: EdgeInsets.symmetric(vertical: 18),
  //     width: double.infinity,
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(icon, size: 42, color: Colors.grey),
  //         SizedBox(height: 16),
  //         Text(
  //           message,
  //           style: TextStyle(
  //             color: Colors.grey,
  //             fontSize: 16,
  //           ),
  //         ),
  //         if (showLoginButton) ...[
  //           SizedBox(height: 20),
  //           ElevatedButton(
  //             onPressed: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(builder: (context) => const LoginScreen()),
  //               );
  //             },
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.blue,
  //               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //             ),
  //             child: Text(
  //               'Login',
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  // void _showDeleteDialog(Alert alert) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         backgroundColor: Colors.blueGrey.shade900,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         title: Text(
  //           'Delete Alert',
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         content: Text(
  //           'Are you sure you want to delete this price alert for ${alert.coinSymbol}?',
  //           style: TextStyle(color: Colors.grey.shade300),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: Text(
  //               'Cancel',
  //               style: TextStyle(color: Colors.grey),
  //             ),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               await _deleteAlert(alert.id);
  //               if (context.mounted) Navigator.pop(context);
  //             },
  //             child: Text(
  //               'Delete',
  //               style: TextStyle(color: Colors.red),
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  void dispose() {
    _channel?.sink.close();
    _pairController.close();
    _priceController.dispose();
    super.dispose();
  }
}