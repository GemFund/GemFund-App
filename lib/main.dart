import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_theme.dart';
import 'providers/campaign_provider.dart';
import 'providers/balance_notifier.dart';
import 'services/wallet_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/create_campaign_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CampaignProvider()),
        ChangeNotifierProvider(create: (context) => BalanceNotifier()),
      ],
      child: MaterialApp(
        title: 'GemFund',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthChecker(),
        routes: {
          '/main': (context) => const MainNavigation(),
          '/create': (context) => const CreateCampaignScreen(),
          '/welcome': (context) => const WelcomeScreen(),
        },
      ),
    );
  }
}

// Auth Checker - Check if user is logged in
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final _walletService = WalletService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash duration

    try {
      // Check if onboarding is completed
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      if (!onboardingComplete && mounted) {
        // Show onboarding for first-time users
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                OnboardingScreen(
                  onComplete: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                    );
                  },
                ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }

      final isLoggedIn = await _walletService.isLoggedIn();

      if (isLoggedIn) {
        // Load wallet credentials
        await _walletService.loadWallet();

        // Start auto-refresh balance when logged in
        if (mounted) {
          Provider.of<BalanceNotifier>(context, listen: false).startAutoRefresh();
        }
      }

      if (mounted) {
        setState(() => _isChecking = false);

        // Navigate based on auth status
        if (isLoggedIn) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
              const MainNavigation(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with icon.png
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64B5F6).withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/icon.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            Text(
              'GemFund',
              style: GoogleFonts.urbanist(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Empower dreams, fund futures',
              style: GoogleFonts.urbanist(
                fontSize: 15,
                color: Colors.black54,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            if (_isChecking)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF1976D2),
                  ),
                  strokeWidth: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}