import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import '../models/campaign.dart';
import '../models/transaction_history.dart';
import '../services/wallet_service.dart';

class Web3Service {
  late Web3Client _client;
  late DeployedContract _contract;
  late ContractFunction _getCampaigns;
  late ContractFunction _getCampaign;
  late ContractFunction _createCampaign;
  late ContractFunction _donateToCampaign;
  late ContractFunction _numberOfCampaigns;

  // Multiple RPC URLs untuk fallback
  final List<String> rpcUrls = [
    'https://sepolia.infura.io/v3/16fc95103fbb4cf28057d7b6302b2ca1',
    'https://rpc.sepolia.org',
    'https://eth-sepolia.public.blastapi.io',
    'https://rpc2.sepolia.org',
  ];
  
  final String contractAddress = '0x5c78fF5D2C3e9d783e720A59AbEe81ABC017f626';
  bool _isInitialized = false;
  int _currentRpcIndex = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Try to connect to working RPC
    _client = await _getWorkingClient();

    // Load ABI
    final abiString = await rootBundle.loadString('assets/contract_abi.json');
    final abi = jsonDecode(abiString);

    _contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'GemFund'),
      EthereumAddress.fromHex(contractAddress),
    );

    // Initialize functions
    _getCampaigns = _contract.function('getCampaigns');
    _getCampaign = _contract.function('getCampaign');
    _createCampaign = _contract.function('createCampaign');
    _donateToCampaign = _contract.function('donateToCampaign');
    _numberOfCampaigns = _contract.function('numberOfCampaigns');

    _isInitialized = true;
  }

  // Get working RPC client
  Future<Web3Client> _getWorkingClient() async {
    for (int i = 0; i < rpcUrls.length; i++) {
      try {
        final client = Web3Client(rpcUrls[i], Client());
        
        await client.getNetworkId().timeout(
          const Duration(seconds: 5),
        );
        
        _currentRpcIndex = i;
        print('Connected to RPC: ${rpcUrls[i]}');
        return client;
      } catch (e) {
        print('RPC ${rpcUrls[i]} failed: $e');
        if (i == rpcUrls.length - 1) {
          throw Exception('All RPC endpoints failed. Please check your internet connection.');
        }
        continue;
      }
    }
    throw Exception('Failed to connect to any RPC endpoint');
  }

  // Check network status
  Future<bool> checkNetworkStatus() async {
    try {
      await initialize();
      await _client.getNetworkId().timeout(
        const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      print('Network check failed: $e');
      return false;
    }
  }

  // Get current gas price with 1.5x multiplier for faster confirmation
  Future<EtherAmount> getGasPrice() async {
    try {
      await initialize();
      final gasPrice = await _client.getGasPrice();
      // Multiply by 1.5 for faster confirmation on testnet
      final boostedGas = gasPrice.getInWei * BigInt.from(15) ~/ BigInt.from(10);
      print('Original gas: ${gasPrice.getValueInUnit(EtherUnit.gwei)} Gwei, Boosted: ${EtherAmount.inWei(boostedGas).getValueInUnit(EtherUnit.gwei)} Gwei');
      return EtherAmount.inWei(boostedGas);
    } catch (e) {
      return EtherAmount.fromUnitAndValue(EtherUnit.gwei, 30);
    }
  }

  // Get all campaigns
  Future<List<Campaign>> getAllCampaigns() async {
    await initialize();

    try {
      final result = await _client.call(
        contract: _contract,
        function: _getCampaigns,
        params: [],
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please try again.');
        },
      );

      final campaigns = <Campaign>[];
      final campaignsList = result[0] as List;

      for (int i = 0; i < campaignsList.length; i++) {
        campaigns.add(Campaign.fromContract(BigInt.from(i), campaignsList[i]));
      }

      return campaigns;
    } catch (e) {
      throw Exception('Failed to load campaigns: ${e.toString()}');
    }
  }

  // Get single campaign
  Future<Campaign> getCampaign(int id) async {
    await initialize();

    try {
      final result = await _client.call(
        contract: _contract,
        function: _getCampaign,
        params: [BigInt.from(id)],
      ).timeout(
        const Duration(seconds: 15),
      );

      return Campaign.fromContract(BigInt.from(id), result[0]);
    } catch (e) {
      throw Exception('Failed to load campaign: ${e.toString()}');
    }
  }

  // Create campaign
  Future<String> createCampaign({
    required String privateKey,
    required String title,
    required String description,
    required double targetInEther,
    required DateTime deadline,
    required String imageUrl,
  }) async {
    await initialize();

    try {
      String cleanKey = privateKey.trim();
      if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
        cleanKey = cleanKey.substring(2);
      }

      final credentials = EthPrivateKey.fromHex(cleanKey);
      final address = await credentials.extractAddress();
      final gasPrice = await getGasPrice();
      
      // Debug logging to identify transaction failure causes
      final deadlineTimestamp = deadline.millisecondsSinceEpoch ~/ 1000;
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      print('=== Campaign Creation Debug ===');
      print('Owner address: $address');
      print('Title: "$title" (length: ${title.length})');
      print('Description length: ${description.length}');
      print('Target: $targetInEther ETH (wei: ${BigInt.from(targetInEther * 1e18)})');
      print('Deadline: $deadline');
      print('Deadline timestamp: $deadlineTimestamp');
      print('Current timestamp: $currentTimestamp');
      print('Deadline valid (future): ${deadlineTimestamp > currentTimestamp}');
      print('Image URL: "$imageUrl" (length: ${imageUrl.length})');
      print('Gas price: ${gasPrice.getValueInUnit(EtherUnit.gwei)} Gwei');
      print('================================');
      
      // Validate deadline is in the future
      if (deadlineTimestamp <= currentTimestamp) {
        throw Exception('Campaign deadline must be in the future. Current: ${DateTime.now()}, Deadline: $deadline');
      }

      final transaction = Transaction.callContract(
        contract: _contract,
        function: _createCampaign,
        parameters: [
          address,
          title,
          description,
          BigInt.from(targetInEther * 1e18),
          BigInt.from(deadline.millisecondsSinceEpoch ~/ 1000),
          imageUrl,
        ],
        gasPrice: gasPrice,
        maxGas: 2000000, // Increased for storing long strings (title, description, image URL)
      );

      final txHash = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: 11155111,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw Exception('Transaction timeout. Please try again.');
        },
      );

      print('Transaction hash: $txHash');
      print('View on Etherscan: https://sepolia.etherscan.io/tx/$txHash');

      await _waitForTransaction(txHash);

      // Save to transaction history
      final userAddress = await WalletService().getAddress();
      if (userAddress != null) {
        await TransactionHistoryService().addTransaction(
          address: userAddress,
          hash: txHash,
          type: TransactionType.create,
          title: title,
          amount: 0.0,
          isSuccess: true,
        );
      }

      return txHash;
    } catch (e) {
      // Save failed transaction
      final userAddress = await WalletService().getAddress();
      if (userAddress != null) {
        await TransactionHistoryService().addTransaction(
          address: userAddress,
          hash: 'failed_${DateTime.now().millisecondsSinceEpoch}',
          type: TransactionType.create,
          title: title,
          amount: 0.0,
          isSuccess: false,
        );
      }

      if (e.toString().contains('insufficient funds')) {
        throw Exception('Insufficient ETH for gas fees.');
      }
      throw Exception('Failed to create campaign: ${e.toString()}');
    }
  }

  // Donate to campaign
  Future<String> donateToCampaign({
    required String privateKey,
    required int campaignId,
    required double amountInEther,
    String? campaignTitle,
    int maxRetries = 2,
  }) async {
    await initialize();

    int retryCount = 0;
    
    while (retryCount <= maxRetries) {
      try {
        String cleanKey = privateKey.trim();
        if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
          cleanKey = cleanKey.substring(2);
        }

        final credentials = EthPrivateKey.fromHex(cleanKey);
        final senderAddress = await credentials.extractAddress();

        final balance = await _client.getBalance(senderAddress);
        final requiredAmount = BigInt.from(amountInEther * 1e18);
        
        if (balance.getInWei < requiredAmount) {
          throw Exception('Insufficient balance. You need at least $amountInEther ETH plus gas fees.');
        }

        final gasPrice = await getGasPrice();
        print('Gas price: ${gasPrice.getValueInUnit(EtherUnit.gwei)} Gwei');

        final transaction = Transaction.callContract(
          contract: _contract,
          function: _donateToCampaign,
          parameters: [BigInt.from(campaignId)],
          value: EtherAmount.fromUnitAndValue(
            EtherUnit.wei,
            requiredAmount,
          ),
          gasPrice: gasPrice,
          maxGas: 300000,
        );

        print('Sending transaction...');
        
        final txHash = await _client.sendTransaction(
          credentials,
          transaction,
          chainId: 11155111,
        ).timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            throw Exception('Transaction timeout');
          },
        );

        print('Transaction sent: $txHash');
        await _waitForTransaction(txHash, timeout: const Duration(seconds: 120));
        print('Transaction confirmed!');

        // Save successful transaction to history
        final userAddress = await WalletService().getAddress();
        if (userAddress != null) {
          await TransactionHistoryService().addTransaction(
            address: userAddress,
            hash: txHash,
            type: TransactionType.donate,
            title: campaignTitle ?? 'Campaign #$campaignId',
            amount: amountInEther,
            isSuccess: true,
            campaignId: campaignId,
          );
        }

        return txHash;
        
      } catch (e) {
        retryCount++;
        print('Attempt $retryCount failed: $e');
        
        if (retryCount > maxRetries) {
          // Save failed transaction to history
          final userAddress = await WalletService().getAddress();
          if (userAddress != null) {
            await TransactionHistoryService().addTransaction(
              address: userAddress,
              hash: 'failed_${DateTime.now().millisecondsSinceEpoch}',
              type: TransactionType.donate,
              title: campaignTitle ?? 'Campaign #$campaignId',
              amount: amountInEther,
              isSuccess: false,
              campaignId: campaignId,
            );
          }

          if (e.toString().contains('insufficient funds')) {
            throw Exception('Insufficient ETH. Need $amountInEther ETH + gas (≈0.001 ETH)');
          } else if (e.toString().contains('timeout')) {
            throw Exception('Network timeout. Testnet may be congested. Try again later.');
          }
          throw Exception('Donation failed: ${e.toString()}');
        }
        
        await Future.delayed(Duration(seconds: 3 * retryCount));
      }
    }
    
    throw Exception('Failed after $maxRetries attempts');
  }

  // Wait for transaction confirmation with longer timeout for testnet
  Future<void> _waitForTransaction(
    String txHash, {
    Duration timeout = const Duration(seconds: 180),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final receipt = await _client.getTransactionReceipt(txHash);
        
        if (receipt != null) {
          if (receipt.status == true) {
            print('Transaction confirmed');
            return;
          } else {
            throw Exception('Transaction failed on blockchain');
          }
        }
        
        await Future.delayed(pollInterval);
        print('Waiting for confirmation...');
        
      } catch (e) {
        if (e.toString().contains('Transaction failed')) {
          rethrow;
        }
        await Future.delayed(pollInterval);
      }
    }
    
    throw Exception('Transaction confirmation timeout');
  }

  void dispose() {
    _client.dispose();
  }
}