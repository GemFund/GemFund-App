/// Model for Deep Investigation API Response (Tier 2)
/// 
/// Represents the result of deep charity investigation

class InvestigationResult {
  final bool success;
  final String interactionId;
  final String status;
  final InvestigationData? data;
  final String? rawOutput;
  final String? message;

  InvestigationResult({
    required this.success,
    required this.interactionId,
    required this.status,
    this.data,
    this.rawOutput,
    this.message,
  });

  factory InvestigationResult.fromJson(Map<String, dynamic> json) {
    return InvestigationResult(
      success: json['success'] ?? false,
      interactionId: json['interaction_id'] ?? '',
      status: json['status'] ?? 'unknown',
      data: json['data'] != null ? InvestigationData.fromJson(json['data']) : null,
      rawOutput: json['raw_output'],
      message: json['message'],
    );
  }

  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

class InvestigationData {
  final String charityName;
  final RegistrationStatus? registrationStatus;
  final FraudIndicators? fraudIndicators;
  final FinancialTransparency? financialTransparency;
  final CostAnalysis? costAnalysis;
  final String overallRiskLevel;
  final String recommendation;
  final List<SourceReference> sources;

  InvestigationData({
    required this.charityName,
    this.registrationStatus,
    this.fraudIndicators,
    this.financialTransparency,
    this.costAnalysis,
    required this.overallRiskLevel,
    required this.recommendation,
    required this.sources,
  });

  factory InvestigationData.fromJson(Map<String, dynamic> json) {
    return InvestigationData(
      charityName: json['charity_name'] ?? '',
      registrationStatus: json['registration_status'] != null 
          ? RegistrationStatus.fromJson(json['registration_status']) 
          : null,
      fraudIndicators: json['fraud_indicators'] != null 
          ? FraudIndicators.fromJson(json['fraud_indicators']) 
          : null,
      financialTransparency: json['financial_transparency'] != null 
          ? FinancialTransparency.fromJson(json['financial_transparency']) 
          : null,
      costAnalysis: json['cost_analysis'] != null 
          ? CostAnalysis.fromJson(json['cost_analysis']) 
          : null,
      overallRiskLevel: json['overall_risk_level'] ?? 'UNKNOWN',
      recommendation: json['recommendation'] ?? '',
      sources: (json['sources'] as List<dynamic>?)
          ?.map((e) => SourceReference.fromJson(e))
          .toList() ?? [],
    );
  }

  /// Get risk level color
  int get riskLevelColor {
    switch (overallRiskLevel.toUpperCase()) {
      case 'LOW':
        return 0xFF22C55E; // Green
      case 'MEDIUM':
        return 0xFFF59E0B; // Amber
      case 'HIGH':
        return 0xFFEF4444; // Red
      default:
        return 0xFF6B7280; // Gray
    }
  }
}

class RegistrationStatus {
  final bool isRegistered;
  final String? registryName;
  final String? registrationNumber;

  RegistrationStatus({
    required this.isRegistered,
    this.registryName,
    this.registrationNumber,
  });

  factory RegistrationStatus.fromJson(Map<String, dynamic> json) {
    return RegistrationStatus(
      isRegistered: json['is_registered'] ?? false,
      registryName: json['registry_name'],
      registrationNumber: json['registration_number'],
    );
  }
}

class FraudIndicators {
  final bool scamReportsFound;
  final List<String> negativeMentions;
  final List<String> warningSigns;

  FraudIndicators({
    required this.scamReportsFound,
    required this.negativeMentions,
    required this.warningSigns,
  });

  factory FraudIndicators.fromJson(Map<String, dynamic> json) {
    return FraudIndicators(
      scamReportsFound: json['scam_reports_found'] ?? false,
      negativeMentions: List<String>.from(json['negative_mentions'] ?? []),
      warningSigns: List<String>.from(json['warning_signs'] ?? []),
    );
  }
}

class FinancialTransparency {
  final bool hasPublicReports;
  final int? lastReportYear;
  final String? notes;

  FinancialTransparency({
    required this.hasPublicReports,
    this.lastReportYear,
    this.notes,
  });

  factory FinancialTransparency.fromJson(Map<String, dynamic> json) {
    return FinancialTransparency(
      hasPublicReports: json['has_public_reports'] ?? false,
      lastReportYear: json['last_report_year'],
      notes: json['notes'],
    );
  }
}

class CostAnalysis {
  final bool claimedAmountReasonable;
  final String? marketRateComparison;

  CostAnalysis({
    required this.claimedAmountReasonable,
    this.marketRateComparison,
  });

  factory CostAnalysis.fromJson(Map<String, dynamic> json) {
    return CostAnalysis(
      claimedAmountReasonable: json['claimed_amount_reasonable'] ?? false,
      marketRateComparison: json['market_rate_comparison'],
    );
  }
}

class SourceReference {
  final String title;
  final String url;
  final String? relevance;

  SourceReference({
    required this.title,
    required this.url,
    this.relevance,
  });

  factory SourceReference.fromJson(Map<String, dynamic> json) {
    return SourceReference(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      relevance: json['relevance'],
    );
  }
}
