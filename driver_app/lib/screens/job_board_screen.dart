import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/job_board_cubit.dart';
import '../cubits/active_delivery_cubit.dart';
import 'active_delivery_screen.dart';
import 'service_jobs_screen.dart';

class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JobBoardCubit, JobBoardState>(
      listener: (context, state) {
        if (state is JobBoardError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isOnline = state is JobBoardLoaded && state.isOnline;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Job Board'),
              bottom: const TabBar(tabs: [
                Tab(icon: Icon(Icons.delivery_dining), text: 'Makanan'),
                Tab(icon: Icon(Icons.handyman), text: 'Jasa'),
              ]),
              actions: [
                Row(
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
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
                      activeTrackColor: Colors.green,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet),
                  onPressed: () => Navigator.pushNamed(context, '/wallet'),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Keluar',
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
            body: TabBarView(children: [
              _buildFoodTab(context, state),
              const ServiceJobsScreen(),
            ]),
          ),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

  Widget _buildFoodTab(BuildContext context, JobBoardState state) {
    if (state is JobBoardOffline) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Anda sedang Offline.\nAktifkan Online untuk melihat pesanan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (state is JobBoardLoading || state is JobBoardAccepting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is JobBoardLoaded) {
      if (state.jobs.isEmpty) {
        return RefreshIndicator(
          onRefresh: () => context.read<JobBoardCubit>().loadJobs(),
          child: ListView(
            children: const [
              SizedBox(height: 200),
              Center(
                child: Text(
                  'Belum ada pesanan tersedia.\nTarik ke bawah untuk refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => context.read<JobBoardCubit>().loadJobs(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
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
            Text(state.message, style: const TextStyle(color: Colors.grey)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    fontWeight: FontWeight.bold,
                    color: KuwrirColors.primary,
                  ),
                ),
                Row(
                  children: [
                    Text('${distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: paymentType == 'cash'
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        paymentType == 'cash' ? 'COD' : 'QRIS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: paymentType == 'cash' ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('#$orderNumber',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),

            // Pickup
            _AddressRow(
              icon: Icons.store,
              iconColor: Colors.orange,
              label: 'Ambil di',
              name: merchantName,
              address: pickupAddress,
            ),
            const SizedBox(height: 12),

            // Dropoff
            _AddressRow(
              icon: Icons.location_on,
              iconColor: Colors.red,
              label: 'Antar ke',
              name: '',
              address: dropoffAddress,
            ),

            if (paymentType == 'cash') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'Tagih COD: Rp ${_fmt(total)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.orange, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KuwrirColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _accepting ? null : () => _accept(context, orderId, job),
                child: _accepting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Ambil Pesanan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveDeliveryScreen()),
      );
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
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (name.isNotEmpty)
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(address,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
