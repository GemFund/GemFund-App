import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import '../services/wallet_service.dart';

class BalanceNotifier extends ChangeNotifier {
  EtherAmount? _balance;
  bool _isLoading = false;
  Timer? _timer;
  String? _lastAddress;

  EtherAmount? get balance => _balance;
  bool get isLoading => _isLoading;

  // Initialize and start auto-refresh
  void startAutoRefresh({Duration interval = const Duration(seconds: 10)}) {
    _timer?.cancel();
    loadBalance();
    _timer = Timer.periodic(interval, (timer) {
      loadBalance(silent: true);
    });
  }

  // Stop auto-refresh
  void stopAutoRefresh() {
    _timer?.cancel();
  }

  // Load balance
  Future<void> loadBalance({bool silent = false}) async {
    try {
      final address = await WalletService().getAddress();

      // Check if address changed (user switched wallet)
      if (_lastAddress != null && _lastAddress != address) {
        _balance = null;
      }
      _lastAddress = address;

      if (!silent) {
        _isLoading = true;
        notifyListeners();
      }

      final balance = await WalletService().getBalance();

      // Only notify if balance changed or first load
      if (_balance == null || _balance!.getInWei != balance?.getInWei) {
        _balance = balance;
        _isLoading = false;
        notifyListeners();
      } else if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading balance: $e');
      _isLoading = false;
      if (!silent) {
        notifyListeners();
      }
    }
  }

  // Manual refresh
  Future<void> refresh() async {
    await loadBalance();
  }

  double get balanceInEther {
    if (_balance == null) return 0.0;
    return _balance!.getValueInUnit(EtherUnit.ether);
  }

 
  String get formattedBalance {
    if (_balance == null) return '0.0000';
    return _balance!.getValueInUnit(EtherUnit.ether).toStringAsFixed(4);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
