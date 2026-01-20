import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_theme.dart';
import '../providers/campaign_provider.dart';
import '../services/wallet_service.dart';

// ============= TRANSACTION HISTORY MODELS =============
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
      amount: (json['amount'] as num).toDouble(),
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

      if (history.length > 100) {
        history.removeRange(100, history.length);
      }

      final encoded = jsonEncode(history.map((tx) => tx.toJson()).toList());
      await _storage.write(key: '${_historyKey}_$address', value: encoded);
    } catch (e) {
      print('Error saving transaction: $e');
    }
  }
}

// ============= PROFILE SCREEN =============
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  EtherAmount? _balance;
  bool _isLoadingBalance = true;
  Timer? _balanceTimer;
  List<TransactionHistory> _transactionHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _loadBalance();
    _loadTransactionHistory();
    
    _balanceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadBalance(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _balanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBalance({bool showLoading = true}) async {
    try {
      if (showLoading && mounted) {
        setState(() {
          _isLoadingBalance = true;
        });
      }
      
      final balance = await WalletService().getBalance();
      if (mounted) {
        setState(() {
          _balance = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  Future<void> _loadTransactionHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final address = await WalletService().getAddress();
      if (address == null) return;

      final history = await TransactionHistoryService().getTransactionHistory(address);
      
      if (mounted) {
        setState(() {
          _transactionHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('Error loading transaction history: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadBalance(),
      _loadTransactionHistory(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.05),
              AppTheme.accentColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<String?>(
            future: WalletService().getAddress(),
            builder: (context, snapshot) {
              final address = snapshot.data ?? '0x0000...0000';
              final shortAddress = address.length > 10
                  ? '${address.substring(0, 6)}...${address.substring(address.length - 4)}'
                  : address;
              
              return RefreshIndicator(
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildModernHeader(address, shortAddress),
                      _buildQuickActions(),
                      _buildTransactionHistory(),
                      _buildMenuSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(String address, String shortAddress) {
    return FadeIn(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            FadeInDown(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3 + (_pulseController.value * 0.3)),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 45,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Wallet Balance',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Live',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isLoadingBalance
                      ? const SizedBox(
                          height: 40,
                          width: 40,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _balance != null
                                  ? _balance!.getValueInUnit(EtherUnit.ether).toStringAsFixed(4)
                                  : '0.0000',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'SepoliaETH',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: address));
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Address copied to clipboard!'),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: AppTheme.successColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        shortAddress,
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.content_copy_rounded,
                        size: 16,
                        color: Colors.white,
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

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                color: AppTheme.primaryColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _refreshAll();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history_rounded,
                label: 'History',
                color: AppTheme.accentColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showTransactionHistoryDialog(context);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.share_rounded,
                label: 'Share',
                color: AppTheme.successColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showComingSoon(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInLeft(
            delay: const Duration(milliseconds: 350),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: AppTheme.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_transactionHistory.isNotEmpty)
                  TextButton(
                    onPressed: () => _showTransactionHistoryDialog(context),
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _isLoadingHistory
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _transactionHistory.isEmpty
                  ? _buildEmptyHistory()
                  : _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return FadeIn(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your donation history will appear here',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final recentTransactions = _transactionHistory.take(3).toList();
    
    return Column(
      children: recentTransactions.map((tx) {
        return FadeInLeft(
          delay: Duration(milliseconds: 400 + (recentTransactions.indexOf(tx) * 50)),
          child: _TransactionItem(transaction: tx),
        );
      }).toList(),
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInLeft(
            delay: const Duration(milliseconds: 600),
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                'Settings',
                style: AppTheme.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          FadeInLeft(
            delay: const Duration(milliseconds: 650),
            child: _ModernMenuItem(
              icon: Icons.settings_rounded,
              title: 'Preferences',
              subtitle: 'App settings & configurations',
              color: AppTheme.primaryColor,
              onTap: () {
                HapticFeedback.selectionClick();
                _showComingSoon(context);
              },
            ),
          ),
          FadeInLeft(
            delay: const Duration(milliseconds: 700),
            child: _ModernMenuItem(
              icon: Icons.security_rounded,
              title: 'Security',
              subtitle: 'Privacy & security settings',
              color: Colors.orange,
              onTap: () {
                HapticFeedback.selectionClick();
                _showComingSoon(context);
              },
            ),
          ),
          FadeInLeft(
            delay: const Duration(milliseconds: 750),
            child: _ModernMenuItem(
              icon: Icons.notifications_active_rounded,
              title: 'Notifications',
              subtitle: 'Manage your alerts',
              color: Colors.purple,
              onTap: () {
                HapticFeedback.selectionClick();
                _showComingSoon(context);
              },
            ),
          ),
          FadeInLeft(
            delay: const Duration(milliseconds: 800),
            child: _ModernMenuItem(
              icon: Icons.help_rounded,
              title: 'Help Center',
              subtitle: 'FAQs & support',
              color: Colors.blue,
              onTap: () {
                HapticFeedback.selectionClick();
                _showComingSoon(context);
              },
            ),
          ),
          FadeInLeft(
            delay: const Duration(milliseconds: 850),
            child: _ModernMenuItem(
              icon: Icons.info_rounded,
              title: 'About',
              subtitle: 'Version & information',
              color: Colors.teal,
              onTap: () {
                HapticFeedback.selectionClick();
                _showAboutDialog(context);
              },
            ),
          ),
          const SizedBox(height: 20),
          
          FadeInUp(
            delay: const Duration(milliseconds: 900),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showLogoutDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.power_settings_new_rounded, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Disconnect Wallet',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          FadeIn(
            delay: const Duration(milliseconds: 950),
            child: Center(
              child: Text(
                'GemFund v1.0.0 • Sepolia Testnet',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionHistoryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction History',
                      style: AppTheme.heading2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadTransactionHistory();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _transactionHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _transactionHistory.length,
                        itemBuilder: (context, index) {
                          return _TransactionItem(
                            transaction: _transactionHistory[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Coming Soon',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
        content: Text(
          'This feature is under development and will be available in the next update!',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Got it!', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.info_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Text('About GemFund'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GemFund is a decentralized crowdfunding platform built on blockchain technology.',
              style: AppTheme.bodyMedium.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            const _AboutItem(label: 'Version', value: '1.0.0', icon: Icons.verified_rounded),
            const _AboutItem(label: 'Network', value: 'Ethereum Sepolia', icon: Icons.cloud_rounded),
            const _AboutItem(label: 'Built with', value: 'Flutter & Web3dart', icon: Icons.code_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Close', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppTheme.errorColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Disconnect Wallet?'),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disconnect? Make sure you have backed up your recovery phrase.',
          style: AppTheme.bodyMedium.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              await WalletService().logout();
              
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/welcome',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Disconnect', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ============= QUICK ACTION CARD =============
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= TRANSACTION ITEM =============
class _TransactionItem extends StatelessWidget {
  final TransactionHistory transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTransactionDetail(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: transaction.isSuccess
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    transaction.type == TransactionType.donate
                        ? Icons.favorite_rounded
                        : Icons.campaign_rounded,
                    color: transaction.isSuccess
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.formattedDate,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.amount.toStringAsFixed(4)} ETH',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: transaction.isSuccess
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: transaction.isSuccess
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        transaction.isSuccess ? 'Success' : 'Failed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: transaction.isSuccess
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    transaction.type == TransactionType.donate
                        ? Icons.favorite_rounded
                        : Icons.campaign_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Transaction Details',
                    style: AppTheme.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DetailRow(label: 'Type', value: transaction.typeText),
            _DetailRow(label: 'Campaign', value: transaction.title),
            _DetailRow(label: 'Amount', value: '${transaction.amount.toStringAsFixed(4)} ETH'),
            _DetailRow(label: 'Date', value: transaction.formattedDate),
            _DetailRow(label: 'Status', value: transaction.isSuccess ? 'Success' : 'Failed'),
            _DetailRow(label: 'Tx Hash', value: transaction.shortHash, copyable: true, fullValue: transaction.hash),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ============= DETAIL ROW =============
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final String? fullValue;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.fullValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: fullValue ?? value));
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.content_copy_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============= MODERN MENU ITEM =============
class _ModernMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModernMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============= ABOUT ITEM =============
class _AboutItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AboutItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}