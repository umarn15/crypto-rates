import 'package:cloud_firestore/cloud_firestore.dart';

class Alert {
  final String id;
  final String coinId;
  final String coinSymbol;
  final double targetPrice;
  final String condition;
  final bool isEnabled;
  final double currentPrice;
  final Timestamp? createdAt;

  Alert({
    required this.id,
    required this.coinId,
    required this.coinSymbol,
    required this.targetPrice,
    required this.condition,
    required this.isEnabled,
    required this.currentPrice,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coinId': coinId,
      'coinSymbol': coinSymbol,
      'targetPrice': targetPrice,
      'condition': condition,
      'isEnabled': isEnabled,
      'currentPrice': currentPrice,
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'] ?? '',
      coinId: map['coinId'] ?? '',
      coinSymbol: map['coinSymbol'] ?? '',
      targetPrice: map['targetPrice'] ?? 0.0,
      condition: map['condition'] ?? '',
      isEnabled: map['isEnabled'] ?? false,
      currentPrice: map['currentPrice'] ?? 0.0,
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt'] : Timestamp.now(),
    );
  }
}