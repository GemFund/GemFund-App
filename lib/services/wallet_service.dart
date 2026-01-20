import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:hex/hex.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final _storage = const FlutterSecureStorage();
  EthPrivateKey? _credentials;
  String? _mnemonic;
  
 
  static const String _rpcUrl = 'https://sepolia.infura.io/v3/16fc95103fbb4cf28057d7b6302b2ca1';

  
  late Web3Client _web3client;

  // Keys for secure storage
  static const String _mnemonicKey = 'user_mnemonic';
  static const String _privateKeyKey = 'user_private_key';
  static const String _addressKey = 'user_address';
  static const String _isLoggedInKey = 'is_logged_in';

  // Initialize Web3 client
  void _initWeb3Client() {
    _web3client = Web3Client(_rpcUrl, http.Client());
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final isLoggedIn = await _storage.read(key: _isLoggedInKey);
    return isLoggedIn == 'true';
  }

  // Get current wallet address
  Future<String?> getAddress() async {
    if (_credentials != null) {
      final address = await _credentials!.extractAddress();
      return address.hex;
    }
    return await _storage.read(key: _addressKey);
  }

  // Get balance from Sepolia network
  Future<EtherAmount?> getBalance() async {
    try {
      _initWeb3Client();
      
      final address = await getAddress();
      if (address == null) return null;

      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _web3client.getBalance(ethAddress);
      
      return balance;
    } catch (e) {
      print('Error getting balance: $e');
      return null;
    }
  }

  // Get balance in Ether (as double)
  Future<double> getBalanceInEther() async {
    try {
      final balance = await getBalance();
      if (balance == null) return 0.0;
      
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      print('Error getting balance in ether: $e');
      return 0.0;
    }
  }

  // Get current credentials
  EthPrivateKey? getCredentials() => _credentials;

  // Get mnemonic
  String? getMnemonic() => _mnemonic;

  // Generate new wallet
  Future<Map<String, String>> generateNewWallet() async {
    try {
      // Generate mnemonic (12 words)
      final mnemonic = bip39.generateMnemonic();
      
      // Convert mnemonic to seed
      final seed = bip39.mnemonicToSeed(mnemonic);
      
      // Derive private key from seed (using BIP44 path for Ethereum)
      final master = await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
      final privateKey = HEX.encode(master.key);
      
      // Create credentials
      final credentials = EthPrivateKey.fromHex(privateKey);
      final address = await credentials.extractAddress();

      return {
        'mnemonic': mnemonic,
        'privateKey': '0x$privateKey',
        'address': address.hex,
      };
    } catch (e) {
      throw Exception('Failed to generate wallet: $e');
    }
  }

  // Import wallet from mnemonic
  Future<Map<String, String>> importFromMnemonic(String mnemonic) async {
    try {
      // Validate mnemonic
      if (!bip39.validateMnemonic(mnemonic.trim())) {
        throw Exception('Invalid mnemonic phrase');
      }

      // Convert mnemonic to seed
      final seed = bip39.mnemonicToSeed(mnemonic.trim());
      
      // Derive private key from seed
      final master = await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
      final privateKey = HEX.encode(master.key);
      
      // Create credentials
      final credentials = EthPrivateKey.fromHex(privateKey);
      final address = await credentials.extractAddress();

      return {
        'mnemonic': mnemonic.trim(),
        'privateKey': '0x$privateKey',
        'address': address.hex,
      };
    } catch (e) {
      throw Exception('Failed to import from mnemonic: $e');
    }
  }

  // Import wallet from private key
  Future<Map<String, String>> importFromPrivateKey(String privateKey) async {
    try {
      // Clean private key (remove 0x if present)
      String cleanKey = privateKey.trim();
      if (cleanKey.startsWith('0x') || cleanKey.startsWith('0X')) {
        cleanKey = cleanKey.substring(2);
      }

      // Validate private key length (64 characters for hex)
      if (cleanKey.length != 64) {
        throw Exception('Invalid private key length');
      }

      // Create credentials
      final credentials = EthPrivateKey.fromHex(cleanKey);
      final address = await credentials.extractAddress();

      return {
        'privateKey': '0x$cleanKey',
        'address': address.hex,
      };
    } catch (e) {
      throw Exception('Failed to import from private key: $e');
    }
  }

  // Save wallet to secure storage
  Future<void> saveWallet({
    String? mnemonic,
    required String privateKey,
    required String address,
  }) async {
    try {
      if (mnemonic != null) {
        await _storage.write(key: _mnemonicKey, value: mnemonic);
        _mnemonic = mnemonic;
      }
      
      await _storage.write(key: _privateKeyKey, value: privateKey);
      await _storage.write(key: _addressKey, value: address);
      await _storage.write(key: _isLoggedInKey, value: 'true');

      // Set credentials
      String cleanKey = privateKey;
      if (cleanKey.startsWith('0x')) {
        cleanKey = cleanKey.substring(2);
      }
      _credentials = EthPrivateKey.fromHex(cleanKey);
    } catch (e) {
      throw Exception('Failed to save wallet: $e');
    }
  }

  // Load wallet from secure storage
  Future<void> loadWallet() async {
    try {
      final privateKey = await _storage.read(key: _privateKeyKey);
      final mnemonic = await _storage.read(key: _mnemonicKey);

      if (privateKey != null) {
        String cleanKey = privateKey;
        if (cleanKey.startsWith('0x')) {
          cleanKey = cleanKey.substring(2);
        }
        _credentials = EthPrivateKey.fromHex(cleanKey);
        _mnemonic = mnemonic;
      }
    } catch (e) {
      throw Exception('Failed to load wallet: $e');
    }
  }

  // Logout (clear wallet data)
  Future<void> logout() async {
    try {
      await _storage.delete(key: _mnemonicKey);
      await _storage.delete(key: _privateKeyKey);
      await _storage.delete(key: _addressKey);
      await _storage.delete(key: _isLoggedInKey);
      
      _credentials = null;
      _mnemonic = null;
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  // Get private key (for transactions)
  Future<String?> getPrivateKey() async {
    return await _storage.read(key: _privateKeyKey);
  }
  
  // Dispose web3 client
  void dispose() {
    _web3client.dispose();
  }
}