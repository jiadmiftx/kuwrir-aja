import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  Future<void> _handleOtpVerify(String phone, String code) async {
    final client = ApiClient();
    final res = await client.verifyOtp(phone, code);
    if (!mounted) return;
    if (res['token'] == null) {
      throw res['error'] ?? 'Verifikasi gagal';
    }
    await client.saveToken(res['token'], res['refresh_token'] ?? '');
    await NotificationService.uploadToken(client);
    if (!mounted) return;
    await maybePromptBiometricOptIn(context);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _continueAsGuest() {
    Navigator.pushReplacementNamed(context, '/home');
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
                        headerTitle: 'Masuk atau daftar',
                        headerSubtitle: 'Nomor baru otomatis terdaftar sebagai akun baru',
                        verifyButtonLabel: 'Masuk',
                        showHeaderIcon: false,
                        showCountryCode: true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: KuwrirColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('atau',
                                style: TextStyle(color: KuwrirColors.textHint, fontSize: 12.5)),
                          ),
                          Expanded(child: Divider(color: KuwrirColors.border)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _continueAsGuest,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: KuwrirColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.explore_outlined, size: 18, color: KuwrirColors.textSecondary),
                          label: Text('Jelajahi dulu restoran sekitarmu',
                              style: TextStyle(color: KuwrirColors.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dengan melanjutkan, kamu setuju dengan Syarat & Ketentuan serta Kebijakan Privasi Cocourir',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint, height: 1.4),
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
  'Lapar dikit, langsung meluncur',
  'Warung favoritmu, tinggal klik',
  'Anter cepat, harga tetap jujur',
  'Rasa lokal, sampai depan pintu',
];

/// Top "boarding" panel, Gojek/Grab-style: a colored hero carrying the
/// branding + tagline, with the login sheet overlapping its bottom edge.
class _LoginHero extends StatefulWidget {
  const _LoginHero();

  @override
  State<_LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<_LoginHero> with SingleTickerProviderStateMixin {
  int _taglineIndex = 0;
  Timer? _timer;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      setState(() => _taglineIndex = (_taglineIndex + 1) % _kHeroTaglines.length);
    });
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Taller hero pushes the login sheet (and its fields) further down the
    // screen, closer to where a thumb naturally rests on a one-handed grip.
    final heroHeight = (MediaQuery.of(context).size.height * 0.58).clamp(360.0, 480.0);
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
          const Align(alignment: Alignment(1.05, -0.8), child: _FloatingBite(icon: Icons.local_pizza_outlined, size: 46, angle: -0.3)),
          const Align(alignment: Alignment(-1.08, -0.06), child: _FloatingBite(icon: Icons.ramen_dining_outlined, size: 52, angle: 0.25)),
          const Align(alignment: Alignment(0.86, 0.88), child: _FloatingBite(icon: Icons.icecream_outlined, size: 34, angle: 0.15)),
          const Align(alignment: Alignment(-0.8, 0.94), child: _FloatingBite(icon: Icons.emoji_food_beverage_outlined, size: 30, angle: -0.2)),
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
                      scale: Tween(begin: 1.0, end: 1.035)
                          .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine)),
                      child: SizedBox(
                        width: 236,
                        child: SvgPicture.asset('assets/images/cocourir_food_logo.svg'),
                      ),
                    ),
                    SizedBox(
                      height: 22,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _kHeroTaglines[_taglineIndex],
                          key: ValueKey(_taglineIndex),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14.5, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Bisa lihat ongkir sebelum order',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w600)),
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

class _FloatingBite extends StatelessWidget {
  final IconData icon;
  final double size;
  final double angle;
  const _FloatingBite({required this.icon, required this.size, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * math.pi,
      child: Icon(icon, size: size, color: Colors.white.withValues(alpha: 0.14)),
    );
  }
}
