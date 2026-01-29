import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../providers/campaign_provider.dart';
import '../services/wallet_service.dart';
import '../services/user_profile_service.dart';
import 'edit_profile_screen.dart';

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

class _ProfileScreenState extends State<ProfileScreen> {
  EtherAmount? _balance;
  bool _isLoadingBalance = true;
  Timer? _balanceTimer;
  List<TransactionHistory> _transactionHistory = [];
  bool _isLoadingHistory = false;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadTransactionHistory();
    _loadUserProfile();

    _balanceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadBalance(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
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
      _loadUserProfile(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    try {
      final address = await WalletService().getAddress();
      if (address == null) return;

      final profile = await UserProfileService().getProfile(address);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true) {
      _loadUserProfile();
    }
  }

  String _getProfileInitials() {
    if (_userProfile == null) return 'GF';
    final name = _userProfile!.fullName;
    if (name != null && name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
    }
    final username = _userProfile!.username;
    if (username != null && username.isNotEmpty) {
      return username.substring(0, username.length.clamp(1, 2)).toUpperCase();
    }
    return 'GF';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                    _buildHeader(address, shortAddress),
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
    );
  }

  Widget _buildHeader(String address, String shortAddress) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64B5F6).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1976D2), width: 3),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: _userProfile?.hasProfile == true
                  ? Text(
                _getProfileInitials(),
                style: GoogleFonts.urbanist(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1976D2),
                ),
              )
                  : const Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // User name display
          if (_userProfile?.hasProfile == true)
            Column(
              children: [
                Text(
                  _userProfile!.getDisplayName(),
                  style: GoogleFonts.urbanist(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_userProfile!.email != null && _userProfile!.email!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _userProfile!.email!,
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),

          Column(
            children: [
              Text(
                'Wallet Balance',
                style: GoogleFonts.urbanist(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: _isLoadingBalance
                    ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1976D2),
                      strokeWidth: 2.5,
                    ),
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
                      style: GoogleFonts.urbanist(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1976D2),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'ETH',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'Address copied to clipboard!',
                        style: GoogleFonts.urbanist(),
                      ),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0xFF43A047),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64B5F6).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 14,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    shortAddress,
                    style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.content_copy_rounded,
                    size: 16,
                    color: Color(0xFF1976D2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionCard(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
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
              onTap: () {
                HapticFeedback.lightImpact();
                _showTransactionHistoryDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_transactionHistory.isNotEmpty)
                TextButton(
                  onPressed: () => _showTransactionHistoryDialog(context),
                  child: Text(
                    'View All',
                    style: GoogleFonts.urbanist(
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingHistory
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: Color(0xFF1976D2),
              ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64B5F6).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Color(0xFF64B5F6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions yet',
            style: GoogleFonts.urbanist(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your donation history will appear here',
            style: GoogleFonts.urbanist(
              fontSize: 13,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final recentTransactions = _transactionHistory.take(3).toList();

    return Column(
      children: recentTransactions.map((tx) {
        return _TransactionItem(transaction: tx);
      }).toList(),
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Settings',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          _ModernMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            subtitle: _userProfile?.hasProfile == true
                ? _userProfile!.getDisplayName()
                : 'Set your name & username',
            onTap: () {
              HapticFeedback.selectionClick();
              _navigateToEditProfile();
            },
          ),
          const SizedBox(height: 12),
          _ModernMenuItem(
            icon: Icons.info_rounded,
            title: 'About',
            subtitle: 'Version & information',
            onTap: () {
              HapticFeedback.selectionClick();
              _showAboutDialog(context);
            },
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF5350).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showLogoutDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.power_settings_new_rounded, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Disconnect Wallet',
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'GemFund v1.0.0 • Sepolia Testnet',
              style: GoogleFonts.urbanist(
                fontSize: 12,
                color: Colors.black54,
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      style: GoogleFonts.urbanist(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadTransactionHistory();
                      },
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1976D2)),
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE3F2FD),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 56,
                          color: Color(0xFF64B5F6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          color: Colors.black54,
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF42A5F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/images/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'About GemFund',
                      style: GoogleFonts.urbanist(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'AI-powered decentralized crowdfunding platform with fraud detection.',
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Gemini AI Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF1976D2),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Powered by Google Gemini AI',
                            style: GoogleFonts.urbanist(
                              fontSize: 13,
                              color: const Color(0xFF1976D2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info items
                    _buildSimpleInfoRow(
                      icon: Icons.verified_rounded,
                      label: 'Version',
                      value: '1.0.0',
                    ),
                    const SizedBox(height: 12),
                    _buildSimpleInfoRow(
                      icon: Icons.cloud_rounded,
                      label: 'Network',
                      value: 'Sepolia Testnet',
                    ),
                    const SizedBox(height: 12),
                    _buildSimpleInfoRow(
                      icon: Icons.code_rounded,
                      label: 'Built with',
                      value: 'Flutter & Solidity',
                    ),
                    const SizedBox(height: 24),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.urbanist(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Color(0xFFEF5350),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Disconnect Wallet?',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disconnect? Make sure you have backed up your recovery phrase.',
          style: GoogleFonts.urbanist(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.urbanist(
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1976D2)),
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
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Disconnect',
              style: GoogleFonts.urbanist(
                fontSize: 15,
              ),
            ),
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
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64B5F6).withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1976D2), size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
            color: const Color(0xFF64B5F6).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    transaction.type == TransactionType.donate
                        ? Icons.favorite_rounded
                        : Icons.campaign_rounded,
                    color: transaction.isSuccess
                        ? const Color(0xFF43A047)
                        : const Color(0xFFEF5350),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: GoogleFonts.urbanist(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.formattedDate,
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          color: Colors.black54,
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
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: transaction.isSuccess
                            ? const Color(0xFF43A047)
                            : const Color(0xFFEF5350),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: transaction.isSuccess
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        transaction.isSuccess ? 'Success' : 'Failed',
                        style: GoogleFonts.urbanist(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: transaction.isSuccess
                              ? const Color(0xFF43A047)
                              : const Color(0xFFEF5350),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(
                    transaction.type == TransactionType.donate
                        ? Icons.favorite_rounded
                        : Icons.campaign_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Transaction Details',
                    style: GoogleFonts.urbanist(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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
                          content: Text(
                            'Copied to clipboard!',
                            style: GoogleFonts.urbanist(),
                          ),
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
                      color: Color(0xFF1976D2),
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
  final VoidCallback onTap;

  const _ModernMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64B5F6).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(icon, color: const Color(0xFF1976D2), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.urbanist(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}