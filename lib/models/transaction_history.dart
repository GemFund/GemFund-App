import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum TransactionType { donate, create }

class TransactionHistory {
  final String hash;
  final TransactionType type;
  final String title;
  final double amount;
  final DateTime timestamp;
  final bool isSuccess;
  final int? campaignId;

  TransactionHistory({
    required this.hash,
    required this.type,
    required this.title,
    required this.amount,
    required this.timestamp,
    required this.isSuccess,
    this.campaignId,
  });

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String get shortHash {
    if (hash.length > 10) {
      return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
    }
    return hash;
  }

  String get typeText {
    return type == TransactionType.donate ? 'Donation' : 'Campaign Created';
  }

  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'type': type.toString(),
      'title': title,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'isSuccess': isSuccess,
      'campaignId': campaignId,
    };
  }

  factory TransactionHistory.fromJson(Map<String, dynamic> json) {
    return TransactionHistory(
      hash: json['hash'],
      type: json['type'] == 'TransactionType.donate'
          ? TransactionType.donate
          : TransactionType.create,
      title: json['title'],
      amount: json['amount'],
      timestamp: DateTime.parse(json['timestamp']),
      isSuccess: json['isSuccess'],
      campaignId: json['campaignId'],
    );
  }
}

class TransactionHistoryService {
  static final TransactionHistoryService _instance =
      TransactionHistoryService._internal();
  factory TransactionHistoryService() => _instance;
  TransactionHistoryService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _historyKey = 'transaction_history';

  Future<List<TransactionHistory>> getTransactionHistory(String address) async {
    try {
      final historyJson = await _storage.read(key: '${_historyKey}_$address');
      if (historyJson == null) return [];

      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded
          .map((json) => TransactionHistory.fromJson(json))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      print('Error loading transaction history: $e');
      return [];
    }
  }

  Future<void> addTransaction({
    required String address,
    required String hash,
    required TransactionType type,
    required String title,
    required double amount,
    required bool isSuccess,
    int? campaignId,
  }) async {
    try {
      final history = await getTransactionHistory(address);
      
      final newTransaction = TransactionHistory(
        hash: hash,
        type: type,
        title: title,
        amount: amount,
        timestamp: DateTime.now(),
        isSuccess: isSuccess,
        campaignId: campaignId,
      );

      history.insert(0, newTransaction);

      // Keep only last 100 transactions
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }

      final encoded = jsonEncode(history.map((tx) => tx.toJson()).toList());
      await _storage.write(key: '${_historyKey}_$address', value: encoded);
    } catch (e) {
      print('Error saving transaction: $e');
    }
  }

  Future<void> clearHistory(String address) async {
    try {
      await _storage.delete(key: '${_historyKey}_$address');
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}