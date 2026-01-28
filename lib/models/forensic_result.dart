/// Model for Forensic Engine API Response
/// 
/// Represents the result of AI-powered fraud detection analysis

class ForensicResult {
  final bool success;
  final ForensicData data;
  final Forensics forensics;

  ForensicResult({
    required this.success,
    required this.data,
    required this.forensics,
  });

  factory ForensicResult.fromJson(Map<String, dynamic> json) {
    return ForensicResult(
      success: json['success'] ?? false,
      data: ForensicData.fromJson(json['data'] ?? {}),
      forensics: Forensics.fromJson(json['forensics'] ?? {}),
    );
  }

  /// Returns color based on verdict
  static int getVerdictColor(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'CREDIBLE':
        return 0xFF22C55E; // Green
      case 'SUSPICIOUS':
        return 0xFFF59E0B; // Amber
      case 'FRAUDULENT':
        return 0xFFEF4444; // Red
      default:
        return 0xFF6B7280; // Gray
    }
  }
}

class ForensicData {
  final int score;
  final String verdict;
  final String summary;
  final List<String> flags;
  final EvidenceMatch evidenceMatch;

  ForensicData({
    required this.score,
    required this.verdict,
    required this.summary,
    required this.flags,
    required this.evidenceMatch,
  });

  factory ForensicData.fromJson(Map<String, dynamic> json) {
    return ForensicData(
      score: json['score'] ?? 0,
      verdict: json['verdict'] ?? 'UNKNOWN',
      summary: json['summary'] ?? '',
      flags: List<String>.from(json['flags'] ?? []),
      evidenceMatch: EvidenceMatch.fromJson(json['evidence_match'] ?? {}),
    );
  }
}

class EvidenceMatch {
  final bool locationVerified;
  final bool visualsMatchText;
  final bool searchCorroboration;
  final bool metadataConsistent;

  EvidenceMatch({
    required this.locationVerified,
    required this.visualsMatchText,
    required this.searchCorroboration,
    required this.metadataConsistent,
  });

  factory EvidenceMatch.fromJson(Map<String, dynamic> json) {
    return EvidenceMatch(
      locationVerified: json['location_verified'] ?? false,
      visualsMatchText: json['visuals_match_text'] ?? false,
      searchCorroboration: json['search_corroboration'] ?? false,
      metadataConsistent: json['metadata_consistent'] ?? false,
    );
  }

  /// Count of verified items
  int get verifiedCount {
    int count = 0;
    if (locationVerified) count++;
    if (visualsMatchText) count++;
    if (searchCorroboration) count++;
    if (metadataConsistent) count++;
    return count;
  }
}

/// Comprehensive forensic analysis from all sources
class Forensics {
  final BlockchainForensics? blockchain;
  final ExifForensics exif;
  final ReverseImageForensics reverseImage;
  final IdentityForensics? identity;

  Forensics({
    this.blockchain,
    required this.exif,
    required this.reverseImage,
    this.identity,
  });

  factory Forensics.fromJson(Map<String, dynamic> json) {
    return Forensics(
      blockchain: json['blockchain'] != null 
          ? BlockchainForensics.fromJson(json['blockchain']) 
          : null,
      exif: ExifForensics.fromJson(json['exif'] ?? {}),
      reverseImage: ReverseImageForensics.fromJson(json['reverseImage'] ?? {}),
      identity: json['identity'] != null 
          ? IdentityForensics.fromJson(json['identity']) 
          : null,
    );
  }
}

/// Blockchain analysis results
class BlockchainForensics {
  final int nonce;
  final double ageHours;
  final double washTradingScore;
  final bool isBurnerWallet;

  BlockchainForensics({
    required this.nonce,
    required this.ageHours,
    required this.washTradingScore,
    required this.isBurnerWallet,
  });

  factory BlockchainForensics.fromJson(Map<String, dynamic> json) {
    return BlockchainForensics(
      nonce: json['nonce'] ?? 0,
      ageHours: (json['ageHours'] ?? 0).toDouble(),
      washTradingScore: (json['washTradingScore'] ?? 0).toDouble(),
      isBurnerWallet: json['isBurnerWallet'] ?? false,
    );
  }
  
  /// Get wallet age in days
  double get ageDays => ageHours / 24;
  
  /// Is wallet suspicious (low age or high wash trading)
  bool get isSuspicious => isBurnerWallet || washTradingScore > 10;
}

/// EXIF metadata analysis
class ExifForensics {
  final bool hasGps;
  final bool hasEdits;
  final bool dateMismatch;
  final List<String> warnings;

  ExifForensics({
    required this.hasGps,
    required this.hasEdits,
    required this.dateMismatch,
    required this.warnings,
  });

  factory ExifForensics.fromJson(Map<String, dynamic> json) {
    return ExifForensics(
      hasGps: json['hasGps'] ?? false,
      hasEdits: json['hasEdits'] ?? false,
      dateMismatch: json['dateMismatch'] ?? false,
      warnings: List<String>.from(json['warnings'] ?? []),
    );
  }
  
  bool get hasIssues => hasEdits || dateMismatch || warnings.isNotEmpty;
}

/// Reverse image search results
class ReverseImageForensics {
  final int duplicatesFound;
  final bool isStockPhoto;
  final List<ImageSource> sources;

  ReverseImageForensics({
    required this.duplicatesFound,
    required this.isStockPhoto,
    required this.sources,
  });

  factory ReverseImageForensics.fromJson(Map<String, dynamic> json) {
    return ReverseImageForensics(
      duplicatesFound: json['duplicatesFound'] ?? 0,
      isStockPhoto: json['isStockPhoto'] ?? false,
      sources: (json['sources'] as List?)
          ?.map((s) => ImageSource.fromJson(s))
          .toList() ?? [],
    );
  }
  
  bool get hasIssues => isStockPhoto || duplicatesFound > 0;
}

class ImageSource {
  final String title;
  final String link;
  final String source;

  ImageSource({
    required this.title,
    required this.link,
    required this.source,
  });

  factory ImageSource.fromJson(Map<String, dynamic> json) {
    return ImageSource(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      source: json['source'] ?? '',
    );
  }
}

/// Identity OSINT verification results
class IdentityForensics {
  final int platformsFound;
  final bool scamReportsFound;
  final bool isDisposableEmail;
  final bool identityConsistent;
  final String accountAge;
  final int trustScore;
  final List<String> redFlags;
  final List<String> greenFlags;
  final String summary;

  IdentityForensics({
    required this.platformsFound,
    required this.scamReportsFound,
    required this.isDisposableEmail,
    required this.identityConsistent,
    required this.accountAge,
    required this.trustScore,
    required this.redFlags,
    required this.greenFlags,
    required this.summary,
  });

  factory IdentityForensics.fromJson(Map<String, dynamic> json) {
    return IdentityForensics(
      platformsFound: json['platformsFound'] ?? 0,
      scamReportsFound: json['scamReportsFound'] ?? false,
      isDisposableEmail: json['isDisposableEmail'] ?? false,
      identityConsistent: json['identityConsistent'] ?? false,
      accountAge: json['accountAge'] ?? 'unknown',
      trustScore: json['trustScore'] ?? 0,
      redFlags: List<String>.from(json['redFlags'] ?? []),
      greenFlags: List<String>.from(json['greenFlags'] ?? []),
      summary: json['summary'] ?? '',
    );
  }
  
  bool get isEstablished => accountAge == 'established';
  bool get hasIssues => scamReportsFound || isDisposableEmail || !identityConsistent || redFlags.isNotEmpty;
}
