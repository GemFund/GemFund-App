import 'package:flutter/material.dart';
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

  /// Replaced emoji with Material Icons (professional & scalable)
  IconData get icon {
    switch (this) {
      case CampaignCategory.medical:
        return Icons.medical_services;
      case CampaignCategory.education:
        return Icons.school;
      case CampaignCategory.disaster:
        return Icons.emergency;
      case CampaignCategory.community:
        return Icons.groups;
      case CampaignCategory.technology:
        return Icons.memory;
      case CampaignCategory.environment:
        return Icons.eco;
      case CampaignCategory.other:
        return Icons.category;
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

  double get targetInEther {
    try {
      return target.toInt() / 1e18;
    } catch (_) {
      return 0.0;
    }
  }

  double get collectedInEther {
    try {
      return amountCollected.toInt() / 1e18;
    } catch (_) {
      return 0.0;
    }
  }

  double get progressPercentage {
    if (targetInEther <= 0) return 0.0;
    final percentage = (collectedInEther / targetInEther) * 100.0;
    return percentage.clamp(0.0, 100.0);
  }

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

  /// Auto-detect category from title & description
  CampaignCategory get category {
    final text = '$title $description'.toLowerCase();

    if (text.contains('hospital') ||
        text.contains('medical') ||
        text.contains('health') ||
        text.contains('surgery') ||
        text.contains('cancer') ||
        text.contains('treatment') ||
        text.contains('doctor') ||
        text.contains('medicine') ||
        text.contains('disease')) {
      return CampaignCategory.medical;
    }

    if (text.contains('school') ||
        text.contains('education') ||
        text.contains('student') ||
        text.contains('university') ||
        text.contains('scholarship') ||
        text.contains('learning') ||
        text.contains('college')) {
      return CampaignCategory.education;
    }

    if (text.contains('flood') ||
        text.contains('earthquake') ||
        text.contains('disaster') ||
        text.contains('emergency') ||
        text.contains('refugee') ||
        text.contains('relief') ||
        text.contains('fire')) {
      return CampaignCategory.disaster;
    }

    if (text.contains('tech') ||
        text.contains('software') ||
        text.contains('app') ||
        text.contains('startup') ||
        text.contains('innovation') ||
        text.contains('digital')) {
      return CampaignCategory.technology;
    }

    if (text.contains('environment') ||
        text.contains('climate') ||
        text.contains('green') ||
        text.contains('sustainable') ||
        text.contains('nature') ||
        text.contains('conservation')) {
      return CampaignCategory.environment;
    }

    if (text.contains('community') ||
        text.contains('local') ||
        text.contains('village') ||
        text.contains('charity') ||
        text.contains('nonprofit')) {
      return CampaignCategory.community;
    }

    return CampaignCategory.other;
  }

  bool get isExpired => DateTime.now().isAfter(deadline);
  bool get hasDonations => donators.isNotEmpty && collectedInEther > 0;
  int get totalBackers => donators.length;
  int get daysRemaining => deadline.difference(DateTime.now()).inDays;

  bool get isSuccessful => progressPercentage >= 100;
  bool get isNearlyFunded => progressPercentage >= 75;
}
