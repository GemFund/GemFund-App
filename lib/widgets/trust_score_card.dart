import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../models/forensic_result.dart';
import '../models/investigation_result.dart';
import '../services/forensic_service.dart';

/// Trust Score Card Widget with Local Caching
///
/// Calls API only once, then caches the result locally
/// Provides manual refresh option to re-fetch data

class TrustScoreCard extends StatefulWidget {
  final String campaignTitle;
  final String campaignDescription;
  final String? imageUrl;
  final String? creatorWalletAddress;
  final List<String>? donorAddresses;
  final String? creatorFullName;
  final String? creatorUsername;
  final String? creatorEmail;

  const TrustScoreCard({
    super.key,
    required this.campaignTitle,
    required this.campaignDescription,
    this.imageUrl,
    this.creatorWalletAddress,
    this.donorAddresses,
    this.creatorFullName,
    this.creatorUsername,
    this.creatorEmail,
  });

  @override
  State<TrustScoreCard> createState() => _TrustScoreCardState();
}

class _TrustScoreCardState extends State<TrustScoreCard> {
  final ForensicService _forensicService = ForensicService();

  bool _isLoading = true;
  bool _isFromCache = false;
  ForensicResult? _result;
  String? _error;

  // Deep Investigation state
  bool _isInvestigating = false;
  InvestigationResult? _investigationResult;
  String? _investigationError;

  @override
  void initState() {
    super.initState();
    _loadTrustScore();
  }

  /// Generate unique cache key for this campaign
  String _getCacheKey() {
    // Use campaign description hash as unique identifier
    return 'trust_score_${widget.campaignDescription.hashCode}';
  }

  /// Load trust score from cache or fetch from API
  Future<void> _loadTrustScore() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _isFromCache = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        // Load from cache
        print('📦 Loading Trust Score from cache');
        final json = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            _result = ForensicResult.fromJson(json);
            _isFromCache = true;
            _isLoading = false;
          });
        }
      } else {
        // Fetch from API
        await _fetchFromAPI();
      }
    } catch (e) {
      print('🔴 Cache Load Error: $e');
      // If cache fails, try fetching from API
      await _fetchFromAPI();
    }
  }

  /// Fetch trust score from API and save to cache
  Future<void> _fetchFromAPI() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _isFromCache = false;
      });

      print('🌐 Fetching Trust Score from API');

      // Build creator info if available
      CreatorInfo? creatorInfo;
      if (widget.creatorFullName != null &&
          widget.creatorUsername != null &&
          widget.creatorEmail != null) {
        creatorInfo = CreatorInfo(
          fullName: widget.creatorFullName!,
          username: widget.creatorUsername!,
          email: widget.creatorEmail!,
        );
      }

      final result = await _forensicService.assessCampaign(
        text: widget.campaignDescription,
        mediaUrls: widget.imageUrl != null ? [widget.imageUrl!] : null,
        creatorAddress: widget.creatorWalletAddress,
        donors: widget.donorAddresses,
        creator: creatorInfo,
      );

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final json = {
        'success': result.success,
        'data': {
          'score': result.data.score,
          'verdict': result.data.verdict,
          'summary': result.data.summary,
          'flags': result.data.flags,
          'evidence_match': {
            'location_verified': result.data.evidenceMatch.locationVerified,
            'visuals_match_text': result.data.evidenceMatch.visualsMatchText,
            'search_corroboration': result.data.evidenceMatch.searchCorroboration,
            'metadata_consistent': result.data.evidenceMatch.metadataConsistent,
          },
        },
        'forensics': {
          'blockchain': result.forensics.blockchain != null ? {
            'nonce': result.forensics.blockchain!.nonce,
            'ageHours': result.forensics.blockchain!.ageHours,
            'washTradingScore': result.forensics.blockchain!.washTradingScore,
            'isBurnerWallet': result.forensics.blockchain!.isBurnerWallet,
          } : null,
          'exif': {
            'hasGps': result.forensics.exif.hasGps,
            'hasEdits': result.forensics.exif.hasEdits,
            'dateMismatch': result.forensics.exif.dateMismatch,
            'warnings': result.forensics.exif.warnings,
          },
          'reverseImage': {
            'duplicatesFound': result.forensics.reverseImage.duplicatesFound,
            'isStockPhoto': result.forensics.reverseImage.isStockPhoto,
            'sources': result.forensics.reverseImage.sources.map((s) => {
              'title': s.title,
              'link': s.link,
              'source': s.source,
            }).toList(),
          },
          'identity': result.forensics.identity != null ? {
            'platformsFound': result.forensics.identity!.platformsFound,
            'scamReportsFound': result.forensics.identity!.scamReportsFound,
            'isDisposableEmail': result.forensics.identity!.isDisposableEmail,
            'identityConsistent': result.forensics.identity!.identityConsistent,
            'accountAge': result.forensics.identity!.accountAge,
            'trustScore': result.forensics.identity!.trustScore,
            'redFlags': result.forensics.identity!.redFlags,
            'greenFlags': result.forensics.identity!.greenFlags,
            'summary': result.forensics.identity!.summary,
          } : null,
        },
      };

      await prefs.setString(cacheKey, jsonEncode(json));
      print('💾 Trust Score saved to cache');

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
          _isFromCache = false;
        });
      }
    } catch (e) {
      print('🔴 Forensic API Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Manual refresh - clear cache and fetch new data
  Future<void> _refreshTrustScore() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey();
    await prefs.remove(cacheKey);
    await _fetchFromAPI();
  }

  Future<void> _startDeepInvestigation() async {
    if (_isInvestigating) return;

    setState(() {
      _isInvestigating = true;
      _investigationError = null;
      _investigationResult = null;
    });

    try {
      // Start investigation
      final interactionId = await _forensicService.startInvestigation(
        charityName: widget.campaignTitle,
        claimContext: widget.campaignDescription,
      );

      // Poll for results
      final result = await _forensicService.pollInvestigation(interactionId);

      if (mounted) {
        setState(() {
          _investigationResult = result;
          _isInvestigating = false;
        });

        // Show results dialog
        _showInvestigationResultsDialog();
      }
    } catch (e) {
      print('🔴 Investigation Error: $e');
      if (mounted) {
        setState(() {
          _investigationError = e.toString();
          _isInvestigating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Investigation failed: ${e.toString().split(':').last}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInvestigationResultsDialog() {
    final result = _investigationResult;
    if (result == null || result.data == null) return;

    final data = result.data!;
    final riskColor = Color(data.riskLevelColor);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deep Investigation Complete',
                          style: GoogleFonts.urbanist(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data.charityName,
                          style: GoogleFonts.urbanist(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: riskColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${data.overallRiskLevel} RISK',
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recommendation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: riskColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            data.overallRiskLevel == 'LOW'
                                ? Icons.verified_rounded
                                : Icons.warning_rounded,
                            color: riskColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data.recommendation,
                              style: GoogleFonts.urbanist(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Registration Status
                    if (data.registrationStatus != null) ...[
                      _buildSectionTitle('Registration Status'),
                      _buildInfoCard(
                        icon: data.registrationStatus!.isRegistered
                            ? Icons.verified_outlined
                            : Icons.cancel_outlined,
                        iconColor: data.registrationStatus!.isRegistered
                            ? Colors.green
                            : Colors.red,
                        title: data.registrationStatus!.isRegistered
                            ? 'Registered Organization'
                            : 'Not Registered',
                        subtitle: data.registrationStatus!.registryName ??
                            'No registry information',
                        detail: data.registrationStatus!.registrationNumber,
                      ),
                    ],

                    // Fraud Indicators
                    if (data.fraudIndicators != null) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle('Fraud Indicators'),
                      _buildInfoCard(
                        icon: data.fraudIndicators!.scamReportsFound
                            ? Icons.dangerous_rounded
                            : Icons.shield_rounded,
                        iconColor: data.fraudIndicators!.scamReportsFound
                            ? Colors.red
                            : Colors.green,
                        title: data.fraudIndicators!.scamReportsFound
                            ? 'Scam Reports Found!'
                            : 'No Scam Reports',
                        subtitle: data.fraudIndicators!.warningSigns.isNotEmpty
                            ? data.fraudIndicators!.warningSigns.join(', ')
                            : 'No warning signs detected',
                      ),
                    ],

                    // Financial Transparency
                    if (data.financialTransparency != null) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle('Financial Transparency'),
                      _buildInfoCard(
                        icon: data.financialTransparency!.hasPublicReports
                            ? Icons.article_outlined
                            : Icons.visibility_off_outlined,
                        iconColor: data.financialTransparency!.hasPublicReports
                            ? Colors.green
                            : Colors.orange,
                        title: data.financialTransparency!.hasPublicReports
                            ? 'Public Reports Available'
                            : 'No Public Reports',
                        subtitle: data.financialTransparency!.notes ??
                            'No additional notes',
                        detail: data.financialTransparency!.lastReportYear != null
                            ? 'Last report: ${data.financialTransparency!.lastReportYear}'
                            : null,
                      ),
                    ],

                    // Cost Analysis
                    if (data.costAnalysis != null) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle('Cost Analysis'),
                      _buildInfoCard(
                        icon: data.costAnalysis!.claimedAmountReasonable
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        iconColor: data.costAnalysis!.claimedAmountReasonable
                            ? Colors.green
                            : Colors.orange,
                        title: data.costAnalysis!.claimedAmountReasonable
                            ? 'Reasonable Amount'
                            : 'Amount Needs Review',
                        subtitle: data.costAnalysis!.marketRateComparison ??
                            'No market comparison available',
                      ),
                    ],

                    // Sources
                    if (data.sources.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle('Sources'),
                      ...data.sources.map((source) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () async {
                            final uri = Uri.parse(source.url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.link, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        source.title,
                                        style: GoogleFonts.urbanist(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2196F3),
                                        ),
                                      ),
                                      if (source.relevance != null)
                                        Text(
                                          source.relevance!,
                                          style: GoogleFonts.urbanist(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.open_in_new, size: 16, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      )),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.urbanist(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: GoogleFonts.urbanist(
                      fontSize: 11,
                      color: Colors.grey[500],
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

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
            ? _buildErrorState()
            : _buildResultState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2196F3).withOpacity(0.1),
                  const Color(0xFF1976D2).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Trust Analysis',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Analyzing campaign authenticity...',
                  style: GoogleFonts.urbanist(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Trust Analysis',
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unable to analyze',
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _refreshTrustScore,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    final data = _result!.data;
    final verdictColor = Color(ForensicResult.getVerdictColor(data.verdict));

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score - LAYOUT DIPERBAIKI
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score Circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      verdictColor.withOpacity(0.15),
                      verdictColor.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: verdictColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${data.score}',
                        style: GoogleFonts.urbanist(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: verdictColor,
                        ),
                      ),
                      Text(
                        '/100',
                        style: GoogleFonts.urbanist(
                          fontSize: 10,
                          color: verdictColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, verdict, and badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title dengan refresh button
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 16,
                          color: Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'AI Trust Score',
                            style: GoogleFonts.urbanist(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Refresh button dengan teks
                        GestureDetector(
                          onTap: _refreshTrustScore,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.refresh_rounded,
                                  size: 13,
                                  color: Color(0xFF2196F3),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Refresh',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2196F3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Verdict badge dan Gemini AI badge - SEJAJAR
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Verdict badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: verdictColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: verdictColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getVerdictIcon(data.verdict),
                                size: 13,
                                color: verdictColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data.verdict,
                                style: GoogleFonts.urbanist(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: verdictColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Gemini AI badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Gemini AI',
                                style: GoogleFonts.urbanist(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary
          Text(
            data.summary,
            style: GoogleFonts.urbanist(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Evidence indicators
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEvidenceChip(
                'Location',
                data.evidenceMatch.locationVerified,
                Icons.location_on_outlined,
              ),
              _buildEvidenceChip(
                'Visuals',
                data.evidenceMatch.visualsMatchText,
                Icons.image_outlined,
              ),
              _buildEvidenceChip(
                'Metadata',
                data.evidenceMatch.metadataConsistent,
                Icons.data_object,
              ),
            ],
          ),

          // Forensics Details Section
          const SizedBox(height: 20),
          _buildForensicsSection(_result!.forensics),

          // Deep investigation section - show for suspicious/fraudulent verdicts
          if (_result!.data.verdict != 'CREDIBLE' || _investigationResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _investigationResult != null
                    ? Colors.green.withOpacity(0.1)
                    : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _investigationResult != null
                      ? Colors.green.withOpacity(0.3)
                      : Colors.amber.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _investigationResult != null
                            ? Icons.fact_check_rounded
                            : Icons.info_outline,
                        size: 18,
                        color: _investigationResult != null
                            ? Colors.green
                            : Colors.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _investigationResult != null
                              ? 'Deep investigation completed'
                              : 'Deep investigation recommended',
                          style: GoogleFonts.urbanist(
                            fontSize: 12,
                            color: _investigationResult != null
                                ? Colors.green[800]
                                : Colors.amber[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isInvestigating
                          ? null
                          : (_investigationResult != null
                          ? _showInvestigationResultsDialog
                          : _startDeepInvestigation),
                      icon: _isInvestigating
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Icon(
                        _investigationResult != null
                            ? Icons.visibility_outlined
                            : Icons.search_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _isInvestigating
                            ? 'Investigating...'
                            : (_investigationResult != null
                            ? 'View Results'
                            : 'Start Investigation'),
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _investigationResult != null
                            ? Colors.green
                            : const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceChip(String label, bool verified, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: verified
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: verified ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: verified ? Colors.green[700] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            verified ? Icons.check_circle : Icons.remove_circle_outline,
            size: 12,
            color: verified ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildForensicsSection(Forensics forensics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Forensic Analysis',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Blockchain Forensics
          if (forensics.blockchain != null) ...[
            _buildForensicItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Blockchain Analysis',
              items: [
                _ForensicDetail(
                  'Wallet Age',
                  '${forensics.blockchain!.ageDays.toStringAsFixed(1)} days',
                  forensics.blockchain!.ageDays > 7,
                ),
                _ForensicDetail(
                  'Transactions',
                  '${forensics.blockchain!.nonce} txns',
                  forensics.blockchain!.nonce > 10,
                ),
                _ForensicDetail(
                  'Wash Trading',
                  '${forensics.blockchain!.washTradingScore.toStringAsFixed(1)}%',
                  forensics.blockchain!.washTradingScore < 10,
                ),
                _ForensicDetail(
                  'Burner Wallet',
                  forensics.blockchain!.isBurnerWallet ? 'Yes ⚠️' : 'No',
                  !forensics.blockchain!.isBurnerWallet,
                ),
              ],
              isGood: !forensics.blockchain!.isSuspicious,
            ),
            const SizedBox(height: 12),
          ],

          // EXIF Analysis
          _buildForensicItem(
            icon: Icons.photo_camera_outlined,
            title: 'Image Metadata (EXIF)',
            items: [
              _ForensicDetail('Has GPS', forensics.exif.hasGps ? 'Yes' : 'No', forensics.exif.hasGps),
              _ForensicDetail('Edited', forensics.exif.hasEdits ? 'Yes ⚠️' : 'No', !forensics.exif.hasEdits),
              _ForensicDetail('Date Mismatch', forensics.exif.dateMismatch ? 'Yes ⚠️' : 'No', !forensics.exif.dateMismatch),
            ],
            isGood: !forensics.exif.hasIssues,
            warnings: forensics.exif.warnings,
          ),
          const SizedBox(height: 12),

          // Reverse Image
          _buildForensicItem(
            icon: Icons.image_search_outlined,
            title: 'Reverse Image Search',
            items: [
              _ForensicDetail(
                'Duplicates Found',
                '${forensics.reverseImage.duplicatesFound}',
                forensics.reverseImage.duplicatesFound == 0,
              ),
              _ForensicDetail(
                'Stock Photo',
                forensics.reverseImage.isStockPhoto ? 'Yes ⚠️' : 'No',
                !forensics.reverseImage.isStockPhoto,
              ),
            ],
            isGood: !forensics.reverseImage.hasIssues,
          ),

          // Identity OSINT
          if (forensics.identity != null) ...[
            const SizedBox(height: 12),
            _buildForensicItem(
              icon: Icons.person_search_outlined,
              title: 'Identity Verification',
              items: [
                _ForensicDetail(
                  'Platforms Found',
                  '${forensics.identity!.platformsFound}',
                  forensics.identity!.platformsFound >= 3,
                ),
                _ForensicDetail(
                  'Account Age',
                  forensics.identity!.accountAge,
                  forensics.identity!.isEstablished,
                ),
                _ForensicDetail(
                  'Scam Reports',
                  forensics.identity!.scamReportsFound ? 'Found ⚠️' : 'None',
                  !forensics.identity!.scamReportsFound,
                ),
                _ForensicDetail(
                  'Disposable Email',
                  forensics.identity!.isDisposableEmail ? 'Yes ⚠️' : 'No',
                  !forensics.identity!.isDisposableEmail,
                ),
                _ForensicDetail(
                  'Identity Score',
                  '${forensics.identity!.trustScore}/100',
                  forensics.identity!.trustScore >= 60,
                ),
              ],
              isGood: !forensics.identity!.hasIssues,
              greenFlags: forensics.identity!.greenFlags,
              redFlags: forensics.identity!.redFlags,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForensicItem({
    required IconData icon,
    required String title,
    required List<_ForensicDetail> items,
    required bool isGood,
    List<String>? warnings,
    List<String>? greenFlags,
    List<String>? redFlags,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGood ? Colors.green.withAlpha(77) : Colors.orange.withAlpha(77),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: isGood ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.urbanist(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isGood ? Colors.green[700] : Colors.orange[700],
                ),
              ),
              const Spacer(),
              Icon(
                isGood ? Icons.check_circle : Icons.warning_amber,
                size: 16,
                color: isGood ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: items.map((item) => _buildDetailChip(item)).toList(),
          ),
          // Warnings
          if (warnings != null && warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.orange[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w,
                      style: GoogleFonts.urbanist(fontSize: 11, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            )),
          ],
          // Green flags
          if (greenFlags != null && greenFlags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: greenFlags.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '✓ $f',
                  style: GoogleFonts.urbanist(fontSize: 10, color: Colors.green[700]),
                ),
              )).toList(),
            ),
          ],
          // Red flags
          if (redFlags != null && redFlags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: redFlags.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚠ $f',
                  style: GoogleFonts.urbanist(fontSize: 10, color: Colors.red[700]),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(_ForensicDetail detail) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: detail.isGood ? Colors.green.withAlpha(26) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${detail.label}: ',
            style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey[600]),
          ),
          Text(
            detail.value,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: detail.isGood ? Colors.green[700] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getVerdictIcon(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'CREDIBLE':
        return Icons.verified_rounded;
      case 'SUSPICIOUS':
        return Icons.warning_amber_rounded;
      case 'FRAUDULENT':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline;
    }
  }
}

/// Helper class for forensic detail display
class _ForensicDetail {
  final String label;
  final String value;
  final bool isGood;

  _ForensicDetail(this.label, this.value, this.isGood);
}