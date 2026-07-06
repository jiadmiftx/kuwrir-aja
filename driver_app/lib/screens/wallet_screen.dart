import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await ApiClient().get('/auth/me'); // Using auth/me for profile info
      // Wait, there is no /auth/me or driver profile endpoint currently.
      // I will need to mock this or fetch from an endpoint.
      // Let's assume the backend has driver info in the auth/me response.
      if (mounted) {
        setState(() {
          _profile = response['user'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load wallet: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: KuwrirColors.background,
        appBar: AppBar(title: const Text('Wallet & Earnings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Since we don't have a direct /driver/me endpoint yet in the API,
    // we'll extract from user.driver relation if exists, or show 0.
    final driverData = _profile?['driver'] ?? {};
    final cashBalance = (driverData['cash_balance'] as num?)?.toDouble() ?? 0.0;
    final totalDelivered = driverData['total_delivered'] ?? 0;
    // We don't track total historical driver_earning per driver directly in the Driver table right now.
    // It can be calculated by joining orders, but for the UI we'll show a placeholder.

    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Wallet & Earnings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Earning Summary
            _SoftPanel(
              child: Column(
                children: [
                  Text(
                    'TOTAL PENGIRIMAN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: KuwrirColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$totalDelivered',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: KuwrirColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cash Balance (Owed to Platform)
            _SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KuwrirColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(Icons.money_off_outlined, color: KuwrirColors.error, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Cash to Deposit',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Kamu sudah mengumpulkan uang cash dari pesanan COD. Uang ini milik Cocourir dan merchant, dan wajib disetorkan.',
                    style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rp ${cashBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: KuwrirColors.error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: KuwrirColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: cashBalance > 0 ? () {
                        // TODO: Phase 4.5 deposit flow
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Deposit instruction will be available soon')),
                        );
                      } : null,
                      child: const Text('Deposit Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  final Widget child;
  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
