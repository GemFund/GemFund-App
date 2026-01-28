import 'package:web3dart/web3dart.dart';

/// Campaign categories for filtering
enum CampaignCategory {
  medical,
  education,
  disaster,
  community,
  technology,
  environment,
  other,
}

extension CampaignCategoryExtension on CampaignCategory {
  String get displayName {
    switch (this) {
      case CampaignCategory.medical:
        return 'Medical';
      case CampaignCategory.education:
        return 'Education';
      case CampaignCategory.disaster:
        return 'Disaster Relief';
      case CampaignCategory.community:
        return 'Community';
      case CampaignCategory.technology:
        return 'Technology';
      case CampaignCategory.environment:
        return 'Environment';
      case CampaignCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case CampaignCategory.medical:
        return '🏥';
      case CampaignCategory.education:
        return '📚';
      case CampaignCategory.disaster:
        return '🆘';
      case CampaignCategory.community:
        return '🤝';
      case CampaignCategory.technology:
        return '💻';
      case CampaignCategory.environment:
        return '🌱';
      case CampaignCategory.other:
        return '📦';
    }
  }
}

class Campaign {
  final BigInt id;
  final EthereumAddress owner;
  final String title;
  final String description;
  final BigInt target;
  final DateTime deadline;
  final BigInt amountCollected;
  final String image;
  final List<EthereumAddress> donators;
  final List<BigInt> donations;


  Campaign({
    required this.id,
    required this.owner,
    required this.title,
    required this.description,
    required this.target,
    required this.deadline,
    required this.amountCollected,
    required this.image,
    required this.donators,
    required this.donations,
  });

  factory Campaign.fromContract(BigInt id, List<dynamic> data) {
    return Campaign(
      id: id,
      owner: data[0] as EthereumAddress,
      title: data[1] as String,
      description: data[2] as String,
      target: data[3] as BigInt,
      deadline: DateTime.fromMillisecondsSinceEpoch(
        (data[4] as BigInt).toInt() * 1000,
      ),
      amountCollected: data[5] as BigInt,
      image: data[6] as String,
      donators: (data[7] as List).cast<EthereumAddress>(),
      donations: (data[8] as List).cast<BigInt>(),
    );
  }

  // Convert Wei to Ether with proper precision
  double get targetInEther {
    try {
      // Use double division for better precision
      return target.toInt() / 1e18;
    } catch (e) {
      return 0.0;
    }
  }

  double get collectedInEther {
    try {
      // Use double division for better precision
      return amountCollected.toInt() / 1e18;
    } catch (e) {
      return 0.0;
    }
  }

  // Calculate percentage with proper handling and precision
  double get progressPercentage {
    try {
      // Check if target is zero to avoid division by zero
      if (targetInEther <= 0) return 0.0;
      
      // Calculate percentage with full precision
      final percentage = (collectedInEther / targetInEther) * 100.0;
      
      // Clamp between 0 and 100
      final clampedPercentage = percentage.clamp(0.0, 100.0);
      
      // Return with appropriate precision
      // Don't round too early - let the UI decide formatting
      return clampedPercentage;
    } catch (e) {
      return 0.0;
    }
  }

  // Get progress percentage as string with smart formatting
  String get progressPercentageFormatted {
    if (progressPercentage < 0.01 && progressPercentage > 0) {
      return '<0.01%';
    } else if (progressPercentage < 1) {
      return '${progressPercentage.toStringAsFixed(2)}%';
    } else if (progressPercentage < 10) {
      return '${progressPercentage.toStringAsFixed(1)}%';
    } else {
      return '${progressPercentage.toStringAsFixed(0)}%';
    }
  }

  /// Auto-detect category from title and description
  CampaignCategory get category {
    final text = '$title $description'.toLowerCase();
    
    // Medical keywords
    if (text.contains('hospital') || text.contains('medical') || 
        text.contains('health') || text.contains('surgery') ||
        text.contains('cancer') || text.contains('treatment') ||
        text.contains('doctor') || text.contains('medicine') ||
        text.contains('sick') || text.contains('disease')) {
      return CampaignCategory.medical;
    }
    
    // Education keywords
    if (text.contains('school') || text.contains('education') ||
        text.contains('student') || text.contains('university') ||
        text.contains('scholarship') || text.contains('learning') ||
        text.contains('tuition') || text.contains('college')) {
      return CampaignCategory.education;
    }
    
    // Disaster keywords
    if (text.contains('flood') || text.contains('earthquake') ||
        text.contains('disaster') || text.contains('emergency') ||
        text.contains('refugee') || text.contains('relief') ||
        text.contains('hurricane') || text.contains('fire')) {
      return CampaignCategory.disaster;
    }
    
    // Technology keywords
    if (text.contains('tech') || text.contains('software') ||
        text.contains('app') || text.contains('startup') ||
        text.contains('innovation') || text.contains('digital')) {
      return CampaignCategory.technology;
    }
    
    // Environment keywords
    if (text.contains('environment') || text.contains('climate') ||
        text.contains('green') || text.contains('sustainable') ||
        text.contains('nature') || text.contains('conservation')) {
      return CampaignCategory.environment;
    }
    
    // Community keywords
    if (text.contains('community') || text.contains('local') ||
        text.contains('neighborhood') || text.contains('village') ||
        text.contains('charity') || text.contains('nonprofit')) {
      return CampaignCategory.community;
    }
    
    return CampaignCategory.other;
  }

  bool get isExpired => DateTime.now().isAfter(deadline);

  // Helper to check if campaign has any donations
  bool get hasDonations => donators.isNotEmpty && collectedInEther > 0;

  // Get total number of backers
  int get totalBackers => donators.length;

  // Get days remaining (can be negative if expired)
  int get daysRemaining => deadline.difference(DateTime.now()).inDays;

  // Get human-readable deadline status with countdown
  String get deadlineStatus {
    if (isExpired) return 'Ended';
    
    final duration = deadline.difference(DateTime.now());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    
    if (days == 0 && hours == 0) return 'Ending soon';
    if (days == 0) return '$hours hours left';
    if (days == 1 && hours > 0) return '1 day $hours hrs left';
    if (days == 1) return '1 day left';
    if (days < 7) return '$days days left';
    if (days < 30) return '${(days / 7).round()} weeks left';
    return '${(days / 30).round()} months left';
  }

  // Get detailed countdown (for campaign detail page)
  String get countdownDetailed {
    if (isExpired) return 'Campaign has ended';
    
    final duration = deadline.difference(DateTime.now());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    
    if (days > 0) {
      return '$days days, $hours hours remaining';
    } else if (hours > 0) {
      return '$hours hours, $minutes minutes remaining';
    } else {
      return '$minutes minutes remaining';
    }
  }

  // Check if campaign is successful (reached target)
  bool get isSuccessful => progressPercentage >= 100;

  // Check if campaign is nearly funded (>= 75%)
  bool get isNearlyFunded => progressPercentage >= 75;

  // Get average donation in ETH
  double get averageDonation {
    if (totalBackers == 0) return 0.0;
    return collectedInEther / totalBackers;
  }

  // Format ETH with smart precision
  String formatEth(double value) {
    if (value == 0) return '0';
    if (value < 0.0001) return value.toStringAsExponential(2);
    if (value < 0.01) return value.toStringAsFixed(6);
    if (value < 1) return value.toStringAsFixed(4);
    if (value < 100) return value.toStringAsFixed(3);
    return value.toStringAsFixed(2);
  }

  // Get collected amount as formatted string
  String get collectedFormatted => formatEth(collectedInEther);

  // Get target amount as formatted string
  String get targetFormatted => formatEth(targetInEther);

  @override
  String toString() {
    return 'Campaign('
        'id: $id, '
        'title: $title, '
        'collected: $collectedFormatted ETH, '
        'target: $targetFormatted ETH, '
        'progress: $progressPercentageFormatted, '
        'backers: $totalBackers, '
        'status: ${isExpired ? 'Expired' : 'Active'}'
        ')';
  }

  // Create a copy with updated values (useful for state management)
  Campaign copyWith({
    BigInt? id,
    EthereumAddress? owner,
    String? title,
    String? description,
    BigInt? target,
    DateTime? deadline,
    BigInt? amountCollected,
    String? image,
    List<EthereumAddress>? donators,
    List<BigInt>? donations,
  }) {
    return Campaign(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      title: title ?? this.title,
      description: description ?? this.description,
      target: target ?? this.target,
      deadline: deadline ?? this.deadline,
      amountCollected: amountCollected ?? this.amountCollected,
      image: image ?? this.image,
      donators: donators ?? this.donators,
      donations: donations ?? this.donations,
    );
  }

  // Convert to JSON for debugging or storage
  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'owner': owner.hex,
      'title': title,
      'description': description,
      'target': target.toString(),
      'targetInEther': targetInEther,
      'deadline': deadline.toIso8601String(),
      'amountCollected': amountCollected.toString(),
      'collectedInEther': collectedInEther,
      'image': image,
      'donators': donators.map((d) => d.hex).toList(),
      'donations': donations.map((d) => d.toString()).toList(),
      'progressPercentage': progressPercentage,
      'totalBackers': totalBackers,
      'isExpired': isExpired,
      'daysRemaining': daysRemaining,
    };
  }
}