import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _orders = await ApiClient().getDriverDeliveryHistory();
    } catch (_) {
      // Best-effort — show whatever loaded, empty state otherwise.
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmtMoney(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Pengantaran'),
        backgroundColor: KuwrirColors.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const SizedBox(height: 140),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: KuwrirColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedClock01,
                              size: 36,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Belum ada riwayat',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: KuwrirColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pengantaran yang sudah selesai akan muncul di sini',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: KuwrirColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _orders.length,
                itemBuilder: (context, i) => _HistoryCard(
                  order: _orders[i],
                  fmtMoney: _fmtMoney,
                  fmtDate: _fmtDate,
                ),
              ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String Function(double) fmtMoney;
  final String Function(String?) fmtDate;
  const _HistoryCard({
    required this.order,
    required this.fmtMoney,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final orderNumber = order['order_number'] as String? ?? '-';
    final merchantName =
        (order['merchant'] as Map?)?['name'] as String? ?? 'Merchant';
    final dropoffAddress = order['dropoff_address'] as String? ?? '';
    final driverEarning = (order['driver_earning'] as num?)?.toDouble() ?? 0;
    final deliveredAt = order['delivered_at'] as String?;
    final paymentType = order['payment_type'] as String? ?? 'cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+Rp ${fmtMoney(driverEarning)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KuwrirColors.success,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (paymentType == 'cash'
                              ? KuwrirColors.warning
                              : KuwrirColors.info)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  paymentType == 'cash' ? 'COD' : 'QRIS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: paymentType == 'cash'
                        ? KuwrirColors.warning
                        : KuwrirColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '#$orderNumber · ${fmtDate(deliveredAt)}',
            style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedStore01,
                size: 15,
                color: KuwrirColors.textHint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$merchantName → $dropoffAddress',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
