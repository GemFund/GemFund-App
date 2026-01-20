import 'package:flutter/foundation.dart';
import '../models/campaign.dart';
import '../services/web3_services.dart';

class CampaignProvider extends ChangeNotifier {
  final Web3Service _web3Service = Web3Service();
  
  List<Campaign> _campaigns = [];
  bool _isLoading = false;
  String? _error;

  List<Campaign> get campaigns => _campaigns;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all campaigns
  Future<void> loadCampaigns() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isConnected = await _web3Service.checkNetworkStatus();
      if (!isConnected) {
        throw Exception('Unable to connect to blockchain. Check your internet.');
      }

      _campaigns = await _web3Service.getAllCampaigns();
      _error = null;
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      debugPrint('Error loading campaigns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create campaign
  Future<bool> createCampaign({
    required String privateKey,
    required String title,
    required String description,
    required double target,
    required DateTime deadline,
    required String imageUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (title.trim().isEmpty) {
        throw Exception('Campaign title cannot be empty');
      }
      
      if (description.trim().isEmpty) {
        throw Exception('Campaign description cannot be empty');
      }
      
      if (target <= 0) {
        throw Exception('Target amount must be greater than 0');
      }
      
      if (deadline.isBefore(DateTime.now())) {
        throw Exception('Deadline must be in the future');
      }

      final isConnected = await _web3Service.checkNetworkStatus();
      if (!isConnected) {
        throw Exception('Unable to connect to blockchain.');
      }

      await _web3Service.createCampaign(
        privateKey: privateKey,
        title: title,
        description: description,
        targetInEther: target,
        deadline: deadline,
        imageUrl: imageUrl,
      );
      
      await loadCampaigns();
      return true;
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      debugPrint('Error creating campaign: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Donate to campaign
  Future<bool> donate({
    required String privateKey,
    required int campaignId,
    required double amount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (amount <= 0) {
        throw Exception('Donation amount must be greater than 0');
      }
      
      if (amount < 0.0001) {
        throw Exception('Minimum donation is 0.0001 ETH');
      }

      final isConnected = await _web3Service.checkNetworkStatus();
      if (!isConnected) {
        throw Exception('Network connection failed. Check your internet.');
      }

      debugPrint('Starting donation: $campaignId, Amount: $amount ETH');

      await _web3Service.donateToCampaign(
        privateKey: privateKey,
        campaignId: campaignId,
        amountInEther: amount,
        maxRetries: 2,
      );

      debugPrint('Donation successful! Reloading...');
      await loadCampaigns();
      
      _error = null;
      return true;
      
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      debugPrint('Donation error: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get specific campaign
  Future<Campaign?> getCampaign(int id) async {
    try {
      return await _web3Service.getCampaign(id);
    } catch (e) {
      _error = _formatErrorMessage(e.toString());
      return null;
    }
  }

  // Format error messages
  String _formatErrorMessage(String error) {
    String message = error.replaceAll('Exception: ', '');
    
    if (message.contains('insufficient funds') || 
        message.contains('Insufficient')) {
      return 'Insufficient ETH. Please add more ETH to your wallet.';
    }
    
    if (message.contains('timeout') || 
        message.contains('Timeout')) {
      return 'Request timeout. Network may be congested. Try again.';
    }
    
    if (message.contains('nonce')) {
      return 'Transaction error. Wait a moment and try again.';
    }
    
    if (message.contains('gas')) {
      return 'Gas estimation failed. Please try again.';
    }
    
    if (message.contains('network') || 
        message.contains('connection') ||
        message.contains('RPC')) {
      return 'Network connection issue. Check your internet.';
    }
    
    if (message.contains('invalid') && message.contains('key')) {
      return 'Invalid private key. Please check and try again.';
    }

    if (message.contains('revert')) {
      return 'Transaction rejected. Check campaign details.';
    }
    
    return message.length > 100 
      ? '${message.substring(0, 100)}...' 
      : message;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadCampaigns();
  }

  @override
  void dispose() {
    _web3Service.dispose();
    super.dispose();
  }
}