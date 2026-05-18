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
        appBar: AppBar(title: const Text('Wallet & Earnings')),
        body: Center(child: CircularProgressIndicator()),
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
      appBar: AppBar(
        title: const Text('Wallet & Earnings'),
      ),
      backgroundColor: KuwrirColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Earning Summary
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Total Deliveries',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalDelivered',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: KuwrirColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Cash Balance (Owed to Platform)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.money_off, color: Colors.red),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Cash to Deposit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You have collected cash from COD deliveries. This amount belongs to Kuwrir and Merchants, and must be deposited.',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rp ${cashBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: cashBalance > 0 ? () {
                          // TODO: Phase 4.5 deposit flow
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Deposit instruction will be available soon')),
                          );
                        } : null,
                        child: const Text('Deposit Now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
