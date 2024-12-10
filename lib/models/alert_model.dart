import 'package:cloud_firestore/cloud_firestore.dart';

class Alert {
  final String id;
  final String coinSymbol;      // For crypto
  final String? pairSymbol;     // For forex
  final String? baseCurrency;   // For forex
  final String? quoteCurrency;  // For forex
  final String condition;
  final double targetPrice;
  final bool isEnabled;
  final double currentPrice;
  final Timestamp? createdAt;

  Alert({
    required this.id,
    required this.coinSymbol,
    this.pairSymbol,
    this.baseCurrency,
    this.quoteCurrency,
    required this.condition,
    required this.targetPrice,
    required this.isEnabled,
    required this.currentPrice,
    this.createdAt,
  });

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'],
      coinSymbol: map['coinSymbol'] ?? '',
      pairSymbol: map['pairSymbol'],
      baseCurrency: map['baseCurrency'],
      quoteCurrency: map['quoteCurrency'],
      condition: map['condition'],
      targetPrice: map['targetPrice'].toDouble(),
      isEnabled: map['isEnabled'],
      currentPrice: map['currentPrice'].toDouble(),
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coinSymbol': coinSymbol,
      'pairSymbol': pairSymbol,
      'baseCurrency': baseCurrency,
      'quoteCurrency': quoteCurrency,
      'condition': condition,
      'targetPrice': targetPrice,
      'isEnabled': isEnabled,
      'currentPrice': currentPrice,
      'createdAt': createdAt,
    };
  }
}