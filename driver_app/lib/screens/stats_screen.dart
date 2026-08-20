import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  double _rating = 5.0;
  int _totalDelivered = 0;
  double _totalEarned = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient();
    try {
      final results = await Future.wait([
        api.get('/driver/application'),
        api.getDriverWallet(),
      ]);
      final application = results[0];
      _rating = (application['rating'] as num?)?.toDouble() ?? 5.0;
      _totalDelivered = (application['total_delivered'] as num?)?.toInt() ?? 0;
      final wallet = results[1]['wallet'] as Map<String, dynamic>?;
      _totalEarned = (wallet?['total_earned'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      // Best-effort — show whatever loaded.
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmtMoney(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Statistik & Performa'),
        backgroundColor: KuwrirColors.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: HugeIcons.strokeRoundedStar,
                        iconColor: KuwrirColors.warning,
                        label: 'Rating',
                        value: _rating.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: HugeIcons.strokeRoundedPackage,
                        iconColor: KuwrirColors.primary,
                        label: 'Total Antar',
                        value: '$_totalDelivered',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatCard(
                  icon: HugeIcons.strokeRoundedMoney01,
                  iconColor: KuwrirColors.success,
                  label: 'Total Penghasilan (sepanjang waktu)',
                  value: 'Rp ${_fmtMoney(_totalEarned)}',
                  wide: true,
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool wide;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: HugeIcon(icon: icon, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: wide ? 22 : 20,
              fontWeight: FontWeight.w800,
              color: KuwrirColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
