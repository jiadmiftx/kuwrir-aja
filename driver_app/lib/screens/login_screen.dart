import 'dart:async';
import 'package:hugeicons/hugeicons.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code, role: 'driver');
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (!mounted) return;

    final hasDriverProfile = res['has_driver_profile'] ?? false;
    if (!hasDriverProfile) {
      final userID = res['user']?['id'] as String?;
      final userName = res['user']?['name'] as String? ?? '';
      if (userID != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DriverOnboardingScreen(userID: userID, userName: userName),
          ),
        );
        return;
      }
    }
    Navigator.pushReplacementNamed(context, '/job_board');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LoginHero(),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: KuwrirColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: KuwrirColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      OtpFlow(
                        onVerify: _handleOtpVerify,
                        verifyButtonLabel: 'Masuk',
                        showHeaderIcon: false,
                        showCountryCode: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dengan melanjutkan, kamu setuju dengan Syarat & Ketentuan serta Kebijakan Privasi Cocourir',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: KuwrirColors.textHint,
                          height: 1.4,
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
    );
  }
}

const _kHeroTaglines = [
  'Antar cepat, cuan jalan terus',
  'Orderan deket, langsung gas',
  'Pendapatan transparan, tanpa ribet',
  'Jalan kaki atau motor, tetap cuan',
];

/// Top "boarding" panel, same Gojek/Grab-style treatment as customer_app's
/// login hero: a colored panel carrying the branding + tagline, with the
/// login sheet overlapping its bottom edge. Keeps every login screen in
/// this platform reading as one continuous product, not three separate
/// apps stitched together.
class _LoginHero extends StatefulWidget {
  const _LoginHero();

  @override
  State<_LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<_LoginHero>
    with SingleTickerProviderStateMixin {
  int _taglineIndex = 0;
  Timer? _timer;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      setState(
        () => _taglineIndex = (_taglineIndex + 1) % _kHeroTaglines.length,
      );
    });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.of(context).size.height * 0.58).clamp(
      360.0,
      480.0,
    );
    return Container(
      height: heroHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KuwrirColors.primaryDark, KuwrirColors.primary],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Align(
            alignment: Alignment(1.05, -0.8),
            child: _FloatingIcon(
              icon: HugeIcons.strokeRoundedMotorbike01,
              size: 48,
              angle: -0.3,
            ),
          ),
          const Align(
            alignment: Alignment(-1.08, -0.06),
            child: _FloatingIcon(
              icon: HugeIcons.strokeRoundedRoute01,
              size: 46,
              angle: 0.25,
            ),
          ),
          const Align(
            alignment: Alignment(0.86, 0.88),
            child: _FloatingIcon(
              icon: HugeIcons.strokeRoundedPaymentSuccess01,
              size: 34,
              angle: 0.15,
            ),
          ),
          const Align(
            alignment: Alignment(-0.8, 0.94),
            child: _FloatingIcon(
              icon: HugeIcons.strokeRoundedDeliveryTruck01,
              size: 32,
              angle: -0.2,
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.035).animate(
                        CurvedAnimation(
                          parent: _pulseCtrl,
                          curve: Curves.easeInOutSine,
                        ),
                      ),
                      child: SizedBox(
                        width: 236,
                        child: SvgPicture.asset(
                          'assets/images/cocourir_driver_logo.svg',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 22,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _kHeroTaglines[_taglineIndex],
                          key: ValueKey(_taglineIndex),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedFlash, size: 16, color: Colors.white),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Lihat estimasi pendapatan sebelum ambil orderan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final double size;
  final double angle;
  const _FloatingIcon({
    required this.icon,
    required this.size,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * math.pi,
      child: HugeIcon(
        icon: icon,
        size: size,
        color: Colors.white.withValues(alpha: 0.14),
      ),
    );
  }
}
