import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// User Profile Model
class UserProfile {
  final String walletAddress;
  final String? fullName;
  final String? username;
  final String? email;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.walletAddress,
    this.fullName,
    this.username,
    this.email,
    this.emailVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      walletAddress: json['wallet_address'] ?? '',
      fullName: json['full_name'],
      username: json['username'],
      email: json['email'],
      emailVerified: json['email_verified'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_address': walletAddress,
      'full_name': fullName,
      'username': username,
      'email': email,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? username,
    String? email,
    bool? emailVerified,
  }) {
    return UserProfile(
      walletAddress: walletAddress,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get display name (fullName > username > short address)
  String getDisplayName() {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    if (username != null && username!.isNotEmpty) {
      return '@$username';
    }
    return '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}';
  }

  bool get hasProfile => 
      (fullName != null && fullName!.isNotEmpty) ||
      (username != null && username!.isNotEmpty) ||
      (email != null && email!.isNotEmpty);
}

/// Service for managing user profiles in Supabase
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const String _tableName = 'user_profiles';
  static const String _cacheKey = 'cached_user_profile';

  final SupabaseService _supabaseService = SupabaseService();
  SupabaseClient? _client;

  Future<SupabaseClient> _getClient() async {
    if (_client == null) {
      await _supabaseService.initialize();
      _client = Supabase.instance.client;
    }
    return _client!;
  }

  /// Get user profile by wallet address
  Future<UserProfile?> getProfile(String walletAddress) async {
    try {
      final client = await _getClient();
      
      final response = await client
          .from(_tableName)
          .select()
          .eq('wallet_address', walletAddress.toLowerCase())
          .maybeSingle();

      if (response != null) {
        final profile = UserProfile.fromJson(response);
        // Cache profile locally
        await _cacheProfile(profile);
        return profile;
      }

      return null;
    } catch (e) {
      print('🔴 Error getting profile: $e');
      // Try to get from cache
      return await _getCachedProfile(walletAddress);
    }
  }

  /// Update or create user profile
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final client = await _getClient();
      
      final data = profile.toJson();
      data['wallet_address'] = profile.walletAddress.toLowerCase();
      
      await client
          .from(_tableName)
          .upsert(data, onConflict: 'wallet_address');

      print('✅ Profile updated successfully');
      
      // Cache profile locally
      await _cacheProfile(profile);
      
      return profile;
    } catch (e) {
      print('🔴 Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username, String currentWallet) async {
    try {
      final client = await _getClient();
      
      final response = await client
          .from(_tableName)
          .select('wallet_address')
          .eq('username', username.toLowerCase())
          .neq('wallet_address', currentWallet.toLowerCase())
          .maybeSingle();

      return response == null;
    } catch (e) {
      print('🔴 Error checking username: $e');
      return true; // Assume available on error
    }
  }

  /// Cache profile locally
  Future<void> _cacheProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_cacheKey}_${profile.walletAddress.toLowerCase()}',
        jsonEncode(profile.toJson()),
      );
    } catch (e) {
      print('🔴 Error caching profile: $e');
    }
  }

  /// Get cached profile
  Future<UserProfile?> _getCachedProfile(String walletAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('${_cacheKey}_${walletAddress.toLowerCase()}');
      
      if (cached != null) {
        return UserProfile.fromJson(jsonDecode(cached));
      }
      return null;
    } catch (e) {
      print('🔴 Error getting cached profile: $e');
      return null;
    }
  }

  /// Clear cached profile
  Future<void> clearCache(String walletAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_cacheKey}_${walletAddress.toLowerCase()}');
    } catch (e) {
      print('🔴 Error clearing cache: $e');
    }
  }

  /// Save campaign creator profile when creating a new campaign
  Future<void> saveCampaignCreator({
    required String campaignId,
    required String walletAddress,
    String? fullName,
    String? username,
    String? email,
  }) async {
    try {
      final client = await _getClient();
      
      await client.from('campaign_creators').insert({
        'campaign_id': campaignId,
        'wallet_address': walletAddress.toLowerCase(),
        'full_name': fullName,
        'username': username,
        'email': email,
      });

      print('✅ Campaign creator saved successfully');
    } catch (e) {
      print('🔴 Error saving campaign creator: $e');
      // Don't throw - this is optional enhancement
    }
  }

  /// Get campaign creator profile
  Future<Map<String, dynamic>?> getCampaignCreator(String campaignId) async {
    try {
      final client = await _getClient();
      
      final response = await client
          .from('campaign_creators')
          .select()
          .eq('campaign_id', campaignId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('🔴 Error getting campaign creator: $e');
      return null;
    }
  }

  /// Get campaign creator by wallet address
  Future<Map<String, dynamic>?> getCampaignCreatorByWallet(String walletAddress) async {
    try {
      final client = await _getClient();
      
      final response = await client
          .from('campaign_creators')
          .select()
          .eq('wallet_address', walletAddress.toLowerCase())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('🔴 Error getting campaign creator by wallet: $e');
      return null;
    }
  }

  /// Request email OTP verification
  Future<Map<String, dynamic>> requestEmailOTP({
    required String email,
    required String walletAddress,
  }) async {
    try {
      final client = await _getClient();
      
      final response = await client.functions.invoke(
        'send-otp',
        body: {
          'email': email,
          'walletAddress': walletAddress,
          'action': 'request',
        },
      );

      if (response.status != 200) {
        final errorData = response.data;
        throw Exception(errorData['message'] ?? 'Failed to send OTP');
      }

      print('✅ OTP sent to $email');
      return {'success': true, 'message': 'OTP sent to your email'};
    } catch (e) {
      print('🔴 Error requesting OTP: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  /// Verify email OTP
  Future<Map<String, dynamic>> verifyEmailOTP({
    required String walletAddress,
    required String otp,
  }) async {
    try {
      final client = await _getClient();
      
      // Get stored OTP from database directly
      final response = await client
          .from(_tableName)
          .select('otp_code, otp_expires_at')
          .eq('wallet_address', walletAddress.toLowerCase())
          .maybeSingle();

      if (response == null) {
        return {'success': false, 'message': 'Profile not found'};
      }

      final storedOtp = response['otp_code'];
      final expiresAt = response['otp_expires_at'];

      // Check if OTP expired
      if (expiresAt != null && DateTime.parse(expiresAt).isBefore(DateTime.now())) {
        return {'success': false, 'message': 'OTP has expired. Please request a new one.'};
      }

      // Verify OTP
      if (storedOtp != otp) {
        return {'success': false, 'message': 'Invalid OTP code'};
      }

      // Mark email as verified
      await client
          .from(_tableName)
          .update({
            'email_verified': true,
            'otp_code': null,
            'otp_expires_at': null,
          })
          .eq('wallet_address', walletAddress.toLowerCase());

      // Clear cache to force refresh
      await clearCache(walletAddress);

      print('✅ Email verified successfully');
      return {'success': true, 'message': 'Email verified successfully'};
    } catch (e) {
      print('🔴 Error verifying OTP: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }
}
