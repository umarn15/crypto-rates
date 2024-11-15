import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class SavedAlerts extends StatelessWidget {
  const SavedAlerts({Key? key}) : super(key: key);

  Future<void> _toggleAlert(String userId, Alert alert) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('alerts')
          .doc(alert.id)
          .update({'isEnabled': !alert.isEnabled});
    } catch (e) {
      print('Error toggling alert: $e');
    }
  }

  Future<void> _deleteAlert(BuildContext context, String userId, Alert alert) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('alerts')
          .doc(alert.id)
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

  Widget _buildAlertItem(BuildContext context, Alert alert, String userId) {
    final Color cardColor = Colors.blueGrey.shade700;
    final TextStyle titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    final TextStyle subtitleStyle = TextStyle(
      fontSize: 16,
      color: Colors.grey[300],
    );

    return Card(
      color: cardColor,
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alert.coinSymbol,
                  style: titleStyle,
                ),
                Row(
                  children: [
                    Switch(
                      value: alert.isEnabled,
                      onChanged: (_) => _toggleAlert(userId, alert),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(
                                'Are you sure you want to delete this alert?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await _deleteAlert(context, userId, alert);
                                    Navigator.pop(context);
                                  },
                                  child: Text('Yes'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Target: \$${alert.targetPrice.toStringAsFixed(2)} (${alert.condition.capitalize()})',
              style: subtitleStyle,
            ),
            // SizedBox(height: 4),
            // Text(
            //   'Current: \$${alert.currentPrice.toStringAsFixed(2)}',
            //   style: subtitleStyle,
            // ),
            // if (alert.triggeredAt != null) ...[
            //   SizedBox(height: 4),
            //   Text(
            //     'Triggered at: ${alert.triggeredAt!.toDate().toString()}',
            //     style: TextStyle(
            //       fontSize: 14,
            //       color: Colors.grey[400],
            //       fontStyle: FontStyle.italic,
            //     ),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('All Saved Alerts'),
      ),
      body: user == null
          ? Center(
        child: Text(
          'Please login to see your alerts',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('alerts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No alerts set',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final alert = Alert.fromMap(doc.data() as Map<String, dynamic>);
              return _buildAlertItem(context, alert, user.uid);
            },
          );
        },
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}