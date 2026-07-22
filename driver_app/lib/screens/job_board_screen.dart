import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/job_board_cubit.dart';
import '../cubits/active_delivery_cubit.dart';
import 'active_delivery_screen.dart';

class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

// Delete-account is implemented (see _deleteAccount below) but hidden from
// the account menu for now, pending review — flip this back on when ready
// instead of re-implementing.
const _kShowDeleteAccount = false;

class _JobBoardScreenState extends State<JobBoardScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JobBoardCubit, JobBoardState>(
      listener: (context, state) {
        if (state is JobBoardError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
        if (state is JobBoardResumeDelivery) {
          context.read<ActiveDeliveryCubit>().setOrder(state.order);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActiveDeliveryScreen()),
          ).then((_) {
            if (context.mounted) {
              context.read<JobBoardCubit>().resetAfterDelivery();
            }
          });
        }
      },
      builder: (context, state) {
        final isOnline = state is JobBoardLoaded && state.isOnline;

        return Scaffold(
            backgroundColor: KuwrirColors.background,
            appBar: AppBar(
              title: const Text('Job Board'),
              actions: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isOnline ? KuwrirColors.success : KuwrirColors.textHint).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isOnline ? KuwrirColors.success : KuwrirColors.textHint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: isOnline,
                      onChanged: (val) {
                        final cubit = context.read<JobBoardCubit>();
                        if (val) {
                          cubit.goOnline();
                        } else {
                          cubit.goOffline();
                        }
                      },
                      activeTrackColor: KuwrirColors.success,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/wallet'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'logout') _confirmLogout(context);
                    if (value == 'delete') _deleteAccount(context);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'logout', child: Text('Keluar')),
                    if (_kShowDeleteAccount)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus Akun', style: TextStyle(color: KuwrirColors.error)),
                      ),
                  ],
                ),
              ],
            ),
            body: _buildFoodTab(context, state),
          );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari akun driver ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await ApiClient().clearTokens();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDeleteAccountDialog(context);
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient().deleteAccount();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Gagal menghapus akun')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    await ApiClient().clearTokens();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Widget _buildFoodTab(BuildContext context, JobBoardState state) {
    if (state is JobBoardOffline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off, size: 36, color: KuwrirColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Anda sedang offline',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: KuwrirColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Aktifkan Online untuk melihat pesanan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: KuwrirColors.textHint),
              ),
            ],
          ),
        ),
      );
    }

    if (state is JobBoardLoading || state is JobBoardAccepting || state is JobBoardResumeDelivery) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is JobBoardLoaded) {
      if (state.jobs.isEmpty) {
        return RefreshIndicator(
          onRefresh: () => context.read<JobBoardCubit>().loadJobs(),
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
                          color: KuwrirColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.inbox_outlined, size: 36, color: KuwrirColors.primary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Belum ada pesanan tersedia',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: KuwrirColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tarik ke bawah untuk refresh',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: KuwrirColors.textHint),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => context.read<JobBoardCubit>().loadJobs(),
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: state.jobs.length,
          itemBuilder: (context, i) {
            return _JobCard(job: state.jobs[i]);
          },
        ),
      );
    }

    if (state is JobBoardError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<JobBoardCubit>().loadJobs(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _JobCard extends StatefulWidget {
  final Map<String, dynamic> job;
  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final orderId = job['id'] as String? ?? '';
    final orderNumber = job['order_number'] as String? ?? '-';
    final driverEarning = (job['driver_earning'] as num?)?.toDouble() ?? 0;
    final distanceKm = (job['distance_km'] as num?)?.toDouble() ?? 0;
    final merchantName = job['merchant_name'] as String? ?? 'Merchant';
    final pickupAddress = job['pickup_address'] as String? ?? '';
    final dropoffAddress = job['dropoff_address'] as String? ?? '';
    final paymentType = job['payment_type'] as String? ?? 'cash';
    final total = (job['total'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rp ${_fmt(driverEarning)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: KuwrirColors.primary,
                  ),
                ),
                Row(
                  children: [
                    Text('${distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                            color: KuwrirColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (paymentType == 'cash' ? KuwrirColors.warning : KuwrirColors.info)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        paymentType == 'cash' ? 'COD' : 'QRIS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: paymentType == 'cash' ? KuwrirColors.warning : KuwrirColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('#$orderNumber',
                style: TextStyle(fontSize: 12, color: KuwrirColors.textHint)),
            const SizedBox(height: 10),
            Divider(height: 1, color: KuwrirColors.border),
            const SizedBox(height: 12),

            // Pickup
            _AddressRow(
              icon: Icons.storefront_outlined,
              iconColor: KuwrirColors.warning,
              label: 'Ambil di',
              name: merchantName,
              address: pickupAddress,
            ),
            const SizedBox(height: 12),

            // Dropoff
            _AddressRow(
              icon: Icons.location_on_outlined,
              iconColor: KuwrirColors.error,
              label: 'Antar ke',
              name: '',
              address: dropoffAddress,
            ),

            if (paymentType == 'cash') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KuwrirColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 16, color: KuwrirColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      'Tagih COD: Rp ${_fmt(total)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: KuwrirColors.warning, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KuwrirColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _accepting ? null : () => _accept(context, orderId, job),
                child: _accepting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Ambil Pesanan',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(
      BuildContext context, String orderId, Map<String, dynamic> job) async {
    setState(() => _accepting = true);
    final result = await context.read<JobBoardCubit>().acceptJob(orderId);
    if (!mounted) return;
    setState(() => _accepting = false);

    if (result != null) {
      context.read<ActiveDeliveryCubit>().setOrder(
          result['order'] as Map<String, dynamic>? ?? job);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveDeliveryScreen()),
      );
      // Driver returned from active delivery — reset to offline so they
      // can manually go online to receive more orders.
      if (mounted) context.read<JobBoardCubit>().resetAfterDelivery();
    }
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String name;
  final String address;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.name,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: KuwrirColors.textHint, fontSize: 11.5)),
              if (name.isNotEmpty)
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              Text(address,
                  style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
