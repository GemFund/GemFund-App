import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web3dart/web3dart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../models/campaign.dart';
import '../providers/campaign_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/trust_score_card.dart';
import '../services/user_profile_service.dart';

class CampaignDetailScreen extends StatelessWidget {
  final Campaign campaign;

  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.black87),
                    onPressed: () {
                      final shareText = '''
🚀 Lihat campaign ini di GemFund!

📌 ${campaign.title}
💰 ${campaign.progressPercentage.toStringAsFixed(0)}% terdanai
🎯 Target: ${campaign.targetInEther.toStringAsFixed(2)} ETH
👥 ${campaign.donators.length} pendukung

Dukung di aplikasi GemFund!
#GemFund #Crowdfunding #Blockchain
''';
                      Share.share(shareText);
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  campaign.image.isNotEmpty
                      ? Image.network(
                    campaign.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _placeholderImage();
                    },
                  )
                      : _placeholderImage(),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),

                  // Status Badge - positioned below the share button
                  Positioned(
                    top: 120, // Moved down to avoid overlap with share button
                    right: 16,
                    child: FadeInRight(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: campaign.isExpired
                                ? [const Color(0xFFEF5350), const Color(0xFFE53935)]
                                : [const Color(0xFF66BB6A), const Color(0xFF43A047)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (campaign.isExpired ? const Color(0xFFEF5350) : const Color(0xFF66BB6A)).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              campaign.isExpired ? Icons.event_busy : Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              campaign.isExpired ? 'Ended' : 'Live',
                              style: GoogleFonts.urbanist(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Title & Owner Card
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64B5F6).withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          style: GoogleFonts.urbanist(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF1976D2),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Campaign Creator',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${campaign.owner.hex.substring(0, 10)}...${campaign.owner.hex.substring(campaign.owner.hex.length - 8)}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF90CAF9)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    size: 12,
                                    color: Color(0xFF1976D2),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1976D2),
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
                ),

                const SizedBox(height: 16),

                // AI Trust Score Card
                FutureBuilder<UserProfile?>(
                  future: UserProfileService().getProfile(campaign.owner.hexEip55),
                  builder: (context, snapshot) {
                    final creatorProfile = snapshot.data;
                    return TrustScoreCard(
                      campaignTitle: campaign.title,
                      campaignDescription: campaign.description,
                      imageUrl: campaign.image.isNotEmpty ? campaign.image : null,
                      creatorWalletAddress: campaign.owner.hexEip55,
                      donorAddresses: campaign.donators.map((d) => d.hexEip55).toList(),
                      creatorFullName: creatorProfile?.fullName,
                      creatorUsername: creatorProfile?.username,
                      creatorEmail: creatorProfile?.email,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Progress Card
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64B5F6).withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Raised',
                                    style: GoogleFonts.urbanist(
                                      color: const Color(0xFF1976D2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${campaign.collectedInEther.toStringAsFixed(4)} ETH',
                                    style: GoogleFonts.urbanist(
                                      color: const Color(0xFF1976D2),
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'of ${campaign.targetInEther.toStringAsFixed(2)} ETH goal',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: campaign.progressPercentage >= 100
                                      ? [const Color(0xFF66BB6A), const Color(0xFF43A047)]
                                      : [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: (campaign.progressPercentage >= 100
                                        ? const Color(0xFF66BB6A)
                                        : const Color(0xFF42A5F5)).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${campaign.progressPercentage.toStringAsFixed(0)}%',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'funded',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: LinearProgressIndicator(
                              value: (campaign.progressPercentage / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                campaign.progressPercentage >= 100
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFF1976D2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Stats Row
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _InfoItem(
                                  icon: Icons.people_outline,
                                  label: 'Backers',
                                  value: campaign.donators.length.toString(),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: _InfoItem(
                                  icon: Icons.access_time_outlined,
                                  label: 'Days Left',
                                  value: campaign.isExpired
                                      ? 'Ended'
                                      : campaign.deadline.difference(DateTime.now()).inDays.toString(),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: _InfoItem(
                                  icon: Icons.trending_up,
                                  label: 'Goal',
                                  value: '${campaign.targetInEther.toStringAsFixed(1)} ETH',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Tabs
                DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF1976D2),
                            labelStyle: GoogleFonts.urbanist(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            dividerColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                            overlayColor: WidgetStateProperty.all(Colors.transparent),
                            tabs: const [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_stories_outlined, size: 16),
                                    SizedBox(width: 6),
                                    Text('Story'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_none_outlined, size: 16),
                                    SizedBox(width: 6),
                                    Text('Updates'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 16),
                                    SizedBox(width: 6),
                                    Text('Backers'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(
                        height: 450,
                        child: TabBarView(
                          children: [
                            _StoryTab(campaign: campaign, dateFormat: dateFormat),
                            _UpdatesTab(),
                            _BackersTab(campaign: campaign),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: campaign.isExpired
          ? null
          : Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _showDonateDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_rounded, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Back This Project',
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign,
          size: 80,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make a Donation',
                        style: GoogleFonts.urbanist(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Support this amazing project',
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF1976D2)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (ETH)',
                    labelStyle: GoogleFonts.urbanist(
                      color: const Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    hintText: '0.1',
                    hintStyle: GoogleFonts.urbanist(color: Colors.black38),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFF1976D2),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.urbanist(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Amount Buttons
              Row(
                children: [
                  _QuickAmountButton(
                    amount: '0.01',
                    onTap: () => amountController.text = '0.01',
                  ),
                  const SizedBox(width: 8),
                  _QuickAmountButton(
                    amount: '0.05',
                    onTap: () => amountController.text = '0.05',
                  ),
                  const SizedBox(width: 8),
                  _QuickAmountButton(
                    amount: '0.1',
                    onTap: () => amountController.text = '0.1',
                  ),
                  const SizedBox(width: 8),
                  _QuickAmountButton(
                    amount: '0.5',
                    onTap: () => amountController.text = '0.5',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF90CAF9),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF1976D2),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Transaction will be made using your connected wallet',
                        style: GoogleFonts.urbanist(
                          color: const Color(0xFF1976D2),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF42A5F5).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);

                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enter a valid amount',
                              style: GoogleFonts.urbanist(),
                            ),
                            backgroundColor: const Color(0xFFEF5350),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }

                      // Check balance
                      try {
                        final walletService = WalletService();
                        final balance = await walletService.getBalance();
                        final balanceInEther = balance?.getValueInUnit(EtherUnit.ether) ?? 0;
                        final estimatedGas = 0.002;

                        if (balanceInEther < amount + estimatedGas) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Insufficient balance! You have ${balanceInEther.toStringAsFixed(4)} ETH but need ${(amount + estimatedGas).toStringAsFixed(4)} ETH (including gas)',
                                      style: GoogleFonts.urbanist(),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFFEF5350),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }
                      } catch (e) {
                        // Continue if balance check fails
                      }

                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.volunteer_activism,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Confirm Donation',
                                style: GoogleFonts.urbanist(fontSize: 18),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Amount:',
                                          style: GoogleFonts.urbanist(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '$amount ETH',
                                          style: GoogleFonts.urbanist(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Divider(height: 20, color: Colors.grey[400]),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'To:',
                                          style: GoogleFonts.urbanist(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            campaign.title,
                                            style: GoogleFonts.urbanist(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Divider(height: 20, color: Colors.grey[400]),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Gas Fee:',
                                          style: GoogleFonts.urbanist(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '~0.001 ETH',
                                          style: GoogleFonts.urbanist(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'This action cannot be undone',
                                        style: GoogleFonts.urbanist(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.urbanist(color: Colors.grey[600]),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF42A5F5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Confirm Donation',
                                style: GoogleFonts.urbanist(),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      Navigator.pop(context);

                      try {
                        final privateKey = await WalletService().getPrivateKey();
                        if (privateKey == null) {
                          throw Exception('Unable to retrieve wallet credentials');
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => _DonationProgressDialog(
                            amount: amount,
                            campaign: campaign,
                            privateKey: privateKey,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                              style: GoogleFonts.urbanist(),
                            ),
                            backgroundColor: const Color(0xFFEF5350),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Donate Now',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Progress Dialog Widget
class _DonationProgressDialog extends StatefulWidget {
  final double amount;
  final Campaign campaign;
  final String privateKey;

  const _DonationProgressDialog({
    required this.amount,
    required this.campaign,
    required this.privateKey,
  });

  @override
  State<_DonationProgressDialog> createState() => _DonationProgressDialogState();
}

class _DonationProgressDialogState extends State<_DonationProgressDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isError = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<DonationStep> _steps = [
    DonationStep(
      title: 'Validating',
      subtitle: 'Checking transaction details',
      icon: Icons.fact_check_outlined,
    ),
    DonationStep(
      title: 'Connecting',
      subtitle: 'Establishing blockchain connection',
      icon: Icons.link_outlined,
    ),
    DonationStep(
      title: 'Processing',
      subtitle: 'Sending transaction to network',
      icon: Icons.rocket_launch_outlined,
    ),
    DonationStep(
      title: 'Confirming',
      subtitle: 'Waiting for blockchain confirmation',
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _startDonation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startDonation() async {
    try {
      setState(() => _currentStep = 0);
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() => _currentStep = 1);
      await Future.delayed(const Duration(milliseconds: 1000));

      setState(() => _currentStep = 2);

      final provider = context.read<CampaignProvider>();
      final success = await provider.donate(
        privateKey: widget.privateKey,
        campaignId: widget.campaign.id.toInt(),
        amount: widget.amount,
      );

      if (!success) {
        throw Exception(provider.error ?? 'Transaction failed');
      }

      setState(() => _currentStep = 3);
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Donation successful! Thank you! 🎉',
              style: GoogleFonts.urbanist(),
            ),
            backgroundColor: const Color(0xFF43A047),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage ?? 'Donation failed',
              style: GoogleFonts.urbanist(),
            ),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isError) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 40,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Processing Donation',
                  style: GoogleFonts.urbanist(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.amount.toStringAsFixed(4)} ETH',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1976D2),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Color(0xFFEF5350),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Transaction Failed',
                  style: GoogleFonts.urbanist(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'An error occurred',
                  style: GoogleFonts.urbanist(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 28),

              if (!_isError) ...[
                ..._steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  final isActive = index == _currentStep;
                  final isCompleted = index < _currentStep;

                  return FadeInUp(
                    delay: Duration(milliseconds: 100 * index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: isActive || isCompleted
                                  ? const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                              )
                                  : null,
                              color: !isActive && !isCompleted ? const Color(0xFFE0E0E0) : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isActive
                                  ? [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                                  : null,
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                : isActive
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Icon(step.icon, color: Colors.grey[400], size: 22),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isActive || isCompleted ? Colors.black87 : Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.subtitle,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 12,
                                    color: isActive || isCompleted ? Colors.black54 : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: GoogleFonts.urbanist(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            )
                          else if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF43A047).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.urbanist(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF43A047),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (_currentStep + 1) / _steps.length,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${((_currentStep + 1) / _steps.length * 100).toInt()}% Complete',
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isError
                      ? const Color(0xFFEF5350).withOpacity(0.1)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isError
                        ? const Color(0xFFEF5350).withOpacity(0.3)
                        : const Color(0xFF90CAF9),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.info_outline : Icons.hourglass_empty_rounded,
                      color: _isError ? const Color(0xFFEF5350) : const Color(0xFF1976D2),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isError
                            ? 'Please check your details and try again'
                            : 'Please wait while we process your donation',
                        style: GoogleFonts.urbanist(
                          color: _isError ? const Color(0xFFEF5350) : const Color(0xFF1976D2),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DonationStep {
  final String title;
  final String subtitle;
  final IconData icon;

  DonationStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1976D2)),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.urbanist(
            color: const Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.urbanist(
            color: Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StoryTab extends StatelessWidget {
  final Campaign campaign;
  final DateFormat dateFormat;

  const _StoryTab({required this.campaign, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this campaign',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            campaign.description,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),

          _CreatorInfoWidget(walletAddress: campaign.owner.hexEip55),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF1976D2),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Campaign Timeline',
                      style: GoogleFonts.urbanist(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deadline',
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(campaign.deadline),
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: campaign.isExpired
                                ? [const Color(0xFFEF5350), const Color(0xFFE53935)]
                                : [const Color(0xFF66BB6A), const Color(0xFF43A047)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          campaign.isExpired ? 'Ended' : 'Active',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdatesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                size: 48,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No updates yet',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Check back later for updates\nfrom the campaign owner',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackersTab extends StatelessWidget {
  final Campaign campaign;

  const _BackersTab({required this.campaign});

  @override
  Widget build(BuildContext context) {
    if (campaign.donators.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 48,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No backers yet',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Be the first to support\nthis amazing campaign!',
                style: GoogleFonts.urbanist(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: campaign.donators.length,
      itemBuilder: (context, index) {
        final donator = campaign.donators[index];
        final donation = campaign.donations[index];
        final amountInEther = donation.toInt() / 1e18;

        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64B5F6).withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${donator.hex.substring(0, 10)}...${donator.hex.substring(donator.hex.length - 8)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Backer #${index + 1}',
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${amountInEther.toStringAsFixed(4)} ETH',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF43A047),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.favorite,
                      size: 14,
                      color: Color(0xFFEF5350),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Center(
            child: Text(
              '$amount ETH',
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1976D2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorInfoWidget extends StatefulWidget {
  final String walletAddress;

  const _CreatorInfoWidget({required this.walletAddress});

  @override
  State<_CreatorInfoWidget> createState() => _CreatorInfoWidgetState();
}

class _CreatorInfoWidgetState extends State<_CreatorInfoWidget> {
  UserProfile? _creatorProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreatorProfile();
  }

  Future<void> _loadCreatorProfile() async {
    try {
      final profile = await UserProfileService().getProfile(widget.walletAddress);
      if (mounted) {
        setState(() {
          _creatorProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getShortAddress() {
    final addr = widget.walletAddress;
    if (addr.length > 10) {
      return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
  }

  String _getInitials() {
    if (_creatorProfile?.fullName != null && _creatorProfile!.fullName!.isNotEmpty) {
      final parts = _creatorProfile!.fullName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return _creatorProfile!.fullName!.substring(0, 1).toUpperCase();
    }
    return widget.walletAddress.substring(2, 4).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64B5F6).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                _getInitials(),
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created by',
                  style: GoogleFonts.urbanist(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _creatorProfile?.hasProfile == true
                      ? _creatorProfile!.getDisplayName()
                      : _getShortAddress(),
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_creatorProfile?.email != null && _creatorProfile!.email!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _creatorProfile!.email!,
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_creatorProfile?.hasProfile == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: GoogleFonts.urbanist(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}