import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/forensic_result.dart';
import '../models/investigation_result.dart';

/// Service for GemFund Forensic Engine API
/// 
/// AI-powered charity fraud detection service using Gemini AI
/// with blockchain forensics, EXIF analysis, and reverse image search.

class ForensicService {
  static const String _baseUrl = 'https://gemfund.apir.live';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvaXR4cGFxbmt4ZnhtZ3N0Zm14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MzM1MjksImV4cCI6MjA4MDMwOTUyOX0.Kor1vYvoLbp0gTTwEeCF0L2QCE99xAdvWrZdzE5FQhk';
  static const Duration _timeout = Duration(seconds: 60);

  /// Assess a campaign for fraud indicators
  /// 
  /// [text] - Campaign description/text to analyze (min 10 chars)
  /// [mediaUrls] - Optional list of media URLs (full Supabase Storage URLs)
  /// [creatorAddress] - Optional Ethereum wallet address for blockchain forensics
  /// [donors] - Optional list of donor wallet addresses for wash trading detection
  /// [creator] - Optional creator info for identity OSINT
  /// 
  /// Returns [ForensicResult] with trust score, verdict, and forensics
  Future<ForensicResult> assessCampaign({
    required String text,
    List<String>? mediaUrls,
    String? creatorAddress,
    List<String>? donors,
    CreatorInfo? creator,
  }) async {
    try {
      // Build media array - extract storage path from full URL
      final List<Map<String, String>> media = [];
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        for (final url in mediaUrls) {
          final path = _extractStoragePath(url);
          if (path != null) {
            // Determine type based on extension
            final isVideo = path.endsWith('.mp4') || 
                           path.endsWith('.webm') || 
                           path.endsWith('.mov');
            media.add({
              'path': path,
              'type': isVideo ? 'video' : 'image',
            });
          }
        }
      }

      // Build request body
      final Map<String, dynamic> body = {
        'text': text,
        'media': media,
      };
      
      // Add optional blockchain forensics params
      if (creatorAddress != null && creatorAddress.isNotEmpty) {
        body['creatorAddress'] = creatorAddress;
      }
      
      if (donors != null && donors.isNotEmpty) {
        body['donors'] = donors.take(50).toList(); // Max 50 donors
      }
      
      // Add creator info for identity OSINT
      if (creator != null) {
        body['creator'] = {
          'fullName': creator.fullName,
          'username': creator.username,
          'email': creator.email,
        };
      }

      print('🔍 Calling Forensic API: $_baseUrl/api/v1/assess');
      print('🔍 Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/assess'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode(body),
      ).timeout(_timeout);

      print('🔍 Forensic API Status: ${response.statusCode}');
      print('🔍 Forensic API Body: ${response.body.substring(0, response.body.length.clamp(0, 500))}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ForensicResult.fromJson(data);
      } else {
        throw ForensicException(
          'Failed to assess campaign: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      print('🔴 Forensic API Exception: $e');
      if (e is ForensicException) rethrow;
      throw ForensicException('Network error: ${e.toString()}', 0);
    }
  }

  /// Extract storage path from full Supabase URL
  /// 
  /// Example: https://xyz.supabase.co/storage/v1/object/public/gemfund/campaigns/123/image.jpg
  /// Returns: campaigns/123/image.jpg
  String? _extractStoragePath(String url) {
    try {
      // Pattern: /storage/v1/object/public/{bucket}/{path}
      final regex = RegExp(r'/storage/v1/object/public/gemfund/(.+)$');
      final match = regex.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
      
      // Fallback: try to get path after last bucket segment
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final gemfundIndex = segments.indexOf('gemfund');
      if (gemfundIndex != -1 && gemfundIndex < segments.length - 1) {
        return segments.sublist(gemfundIndex + 1).join('/');
      }
      
      return null;
    } catch (e) {
      print('🔴 Failed to extract storage path from URL: $url');
      return null;
    }
  }


  /// Start a deep investigation on a charity (Tier 2)
  /// 
  /// [charityName] - Name of the charity to investigate
  /// [claimContext] - Context of the fundraising claim
  /// 
  /// Returns interaction_id for polling status
  Future<String> startInvestigation({
    required String charityName,
    required String claimContext,
  }) async {
    try {
      print('🔍 Starting deep investigation for: $charityName');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/investigate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode({
          'charity_name': charityName,
          'claim_context': claimContext,
        }),
      ).timeout(const Duration(seconds: 60));

      print('🔍 Investigate API Status: ${response.statusCode}');
      print('🔍 Investigate API Body: ${response.body}');

      if (response.statusCode == 202) {
        final data = jsonDecode(response.body);
        return data['interaction_id'] ?? '';
      } else {
        throw ForensicException(
          'Failed to start investigation: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      print('🔴 Investigate API Exception: $e');
      if (e is ForensicException) rethrow;
      throw ForensicException('Network error: ${e.toString()}', 0);
    }
  }

  /// Check investigation status and get results
  /// 
  /// [interactionId] - ID from startInvestigation
  /// Returns InvestigationResult with status and data when complete
  Future<InvestigationResult> checkInvestigationStatus(String interactionId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/investigate/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode({
          'interaction_id': interactionId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('🔍 Status API: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 200))}...');

      if (response.statusCode == 200 || response.statusCode == 202) {
        return InvestigationResult.fromJson(jsonDecode(response.body));
      } else {
        throw ForensicException(
          'Failed to check status: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      print('🔴 Status check error: $e');
      if (e is ForensicException) rethrow;
      throw ForensicException('Network error: ${e.toString()}', 0);
    }
  }

  /// Poll investigation until complete or timeout
  /// 
  /// [interactionId] - ID from startInvestigation
  /// [maxPolls] - Maximum number of polls before timeout
  /// [pollInterval] - Duration between polls
  Future<InvestigationResult> pollInvestigation(
    String interactionId, {
    int maxPolls = 24,
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    for (int i = 0; i < maxPolls; i++) {
      final result = await checkInvestigationStatus(interactionId);
      
      if (result.isCompleted || result.isFailed) {
        return result;
      }
      
      print('🔄 Poll ${i + 1}/$maxPolls - Status: ${result.status}');
      await Future.delayed(pollInterval);
    }
    
    throw ForensicException('Investigation timeout after ${maxPolls * pollInterval.inSeconds} seconds', 0);
  }
}

/// Creator info for OSINT investigation
class CreatorInfo {
  final String fullName;
  final String username;
  final String email;

  CreatorInfo({
    required this.fullName,
    required this.username,
    required this.email,
  });
}

/// Custom exception for Forensic API errors
class ForensicException implements Exception {
  final String message;
  final int statusCode;

  ForensicException(this.message, this.statusCode);

  @override
  String toString() => 'ForensicException: $message (status: $statusCode)';
}
