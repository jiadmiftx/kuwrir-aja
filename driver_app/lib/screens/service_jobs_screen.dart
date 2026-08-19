import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Service job board for drivers — two types of jobs:
/// 1. Leg 1 (Pickup)  : pick up items from customer → deliver to merchant
/// 2. Leg 2 (Return)  : pick up finished items from merchant → return to customer + collect COD
class ServiceJobsScreen extends StatefulWidget {
  const ServiceJobsScreen({super.key});

  @override
  State<ServiceJobsScreen> createState() => _ServiceJobsScreenState();
}

// ─── Mock data ────────────────────────────────────────────────────────────────

enum _JobLeg { pickup, returnToCustomer }

class _ServiceJob {
  final String id, orderNumber, customerName, merchantName;
  final String pickupAddress, dropoffAddress;
  final double distanceKm, driverEarning, totalCod;
  final List<String> items;
  final String serviceNotes;
  final _JobLeg leg;

  const _ServiceJob({
    required this.id, required this.orderNumber,
    required this.customerName, required this.merchantName,
    required this.pickupAddress, required this.dropoffAddress,
    required this.distanceKm, required this.driverEarning, required this.totalCod,
    required this.items, required this.leg,
    this.serviceNotes = '',
  });
}

// ─── Active job state ─────────────────────────────────────────────────────────

class _ActiveJob {
  final _ServiceJob job;
  String status; // 'heading_to_pickup' | 'picked_up' | 'heading_to_dropoff'
  _ActiveJob(this.job) : status = 'heading_to_pickup';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class _ServiceJobsScreenState extends State<ServiceJobsScreen> {
  _ActiveJob? _activeJob;

  final _pickupJobs = [
    const _ServiceJob(
      id: 'j1', orderNumber: 'SVC-260601091015',
      customerName: 'Ibu Ratna', merchantName: 'Laundry Bersih Kilat',
      pickupAddress: 'Jl. Pantai Kuta No. 5', dropoffAddress: 'Jl. Kuta No. 12',
      distanceKm: 1.8, driverEarning: 15000, totalCod: 0,
      items: ['Cuci + Setrika (4kg)'], serviceNotes: 'Pisahkan baju putih',
      leg: _JobLeg.pickup,
    ),
    const _ServiceJob(
      id: 'j2', orderNumber: 'SVC-260601094522',
      customerName: 'Pak Budi', merchantName: 'Bengkel Motor Pak Dedi',
      pickupAddress: 'Jl. Raya No. 12', dropoffAddress: 'Jl. Raya Kuta No. 45',
      distanceKm: 2.4, driverEarning: 15000, totalCod: 0,
      items: ['Servis Ringan', 'Tambal Ban ×2'], serviceNotes: 'Ganti oli Castrol',
      leg: _JobLeg.pickup,
    ),
  ];

  final _returnJobs = [
    const _ServiceJob(
      id: 'j3', orderNumber: 'SVC-260601082030',
      customerName: 'Pak Joko', merchantName: 'Bengkel Motor Pak Dedi',
      pickupAddress: 'Jl. Raya Kuta No. 45', dropoffAddress: 'Jl. Bypass No. 23',
      distanceKm: 3.1, driverEarning: 15000, totalCod: 187000,
      items: ['Tune Up (selesai)'],
      leg: _JobLeg.returnToCustomer,
    ),
  ];

  String _fmt(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  void _acceptJob(_ServiceJob job) {
    setState(() => _activeJob = _ActiveJob(job));
  }

  void _nextStep() {
    if (_activeJob == null) return;
    setState(() {
      switch (_activeJob!.status) {
        case 'heading_to_pickup':
          _activeJob!.status = 'picked_up';
          break;
        case 'picked_up':
          _activeJob!.status = 'heading_to_dropoff';
          break;
        case 'heading_to_dropoff':
          _showCompletionDialog();
          break;
      }
    });
  }

  void _showCompletionDialog() {
    final isReturn = _activeJob!.job.leg == _JobLeg.returnToCustomer;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isReturn ? 'Konfirmasi Penyerahan & COD' : 'Konfirmasi Pengiriman'),
        content: isReturn
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pastikan barang sudah diserahkan ke ${_activeJob!.job.customerName}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                  child: Row(children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedPaymentSuccess01, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Terima uang tunai COD:', style: TextStyle(color: Colors.green, fontSize: 12)),
                      Text(_fmt(_activeJob!.job.totalCod), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('Kamu perlu setor ${_fmt(_activeJob!.job.totalCod - _activeJob!.job.driverEarning)} ke admin', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])
            : Text('Konfirmasi barang sudah diserahkan ke ${_activeJob!.job.merchantName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeJob();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isReturn ? 'Terima COD & Selesai' : 'Konfirmasi Selesai'),
          ),
        ],
      ),
    );
  }

  void _completeJob() {
    final isReturn = _activeJob!.job.leg == _JobLeg.returnToCustomer;
    setState(() => _activeJob = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isReturn
            ? 'Order selesai! COD diterima dan dicatat.'
            : 'Barang berhasil diantarkan ke merchant.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeJob != null) return _buildActiveJobScreen();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Job Jasa'),
          bottom: TabBar(tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedArrowUp01, size: 16),
              const SizedBox(width: 4),
              const Text('Jemput'),
              if (_pickupJobs.isNotEmpty) ...[
                const SizedBox(width: 6),
                CircleAvatar(radius: 9, backgroundColor: KuwrirColors.primary, child: Text('${_pickupJobs.length}', style: const TextStyle(fontSize: 11, color: Colors.white))),
              ],
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, size: 16),
              const SizedBox(width: 4),
              const Text('Antar Balik'),
              if (_returnJobs.isNotEmpty) ...[
                const SizedBox(width: 6),
                CircleAvatar(radius: 9, backgroundColor: Colors.green, child: Text('${_returnJobs.length}', style: const TextStyle(fontSize: 11, color: Colors.white))),
              ],
            ])),
          ]),
        ),
        body: TabBarView(children: [
          _buildJobList(_pickupJobs, isPickup: true),
          _buildJobList(_returnJobs, isPickup: false),
        ]),
      ),
    );
  }

  Widget _buildJobList(List<_ServiceJob> jobs, {required bool isPickup}) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          HugeIcon(icon: isPickup ? HugeIcons.strokeRoundedPackage : HugeIcons.strokeRoundedDeliveryTruck01, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(isPickup ? 'Tidak ada job jemput tersedia' : 'Tidak ada job antar balik tersedia', style: const TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: jobs.length,
      itemBuilder: (_, i) => _buildJobCard(jobs[i]),
    );
  }

  Widget _buildJobCard(_ServiceJob job) {
    final isReturn = job.leg == _JobLeg.returnToCustomer;
    final accent = isReturn ? Colors.green : KuwrirColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                HugeIcon(icon: isReturn ? HugeIcons.strokeRoundedArrowDown01 : HugeIcons.strokeRoundedArrowUp01, size: 12, color: accent),
                const SizedBox(width: 4),
                Text(isReturn ? 'ANTAR BALIK + COD' : 'JEMPUT BARANG', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Spacer(),
            Text(job.orderNumber, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 10),

          // Route
          _routeRow(
            isReturn ? HugeIcons.strokeRoundedStore01 : HugeIcons.strokeRoundedUser,
            isReturn ? 'Dari: ${job.merchantName}' : 'Dari: ${job.customerName}',
            job.pickupAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Container(width: 2, height: 16, color: Colors.grey.shade200),
          ),
          _routeRow(
            isReturn ? HugeIcons.strokeRoundedHome01 : HugeIcons.strokeRoundedStore01,
            isReturn ? 'Ke: ${job.customerName}' : 'Ke: ${job.merchantName}',
            job.dropoffAddress,
          ),
          const SizedBox(height: 10),

          // Items
          ...job.items.map((item) => Text('• $item', style: const TextStyle(fontSize: 13))),
          if (job.serviceNotes.isNotEmpty)
            Text('📝 ${job.serviceNotes}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),

          // Earnings row
          Row(children: [
            Text('${job.distanceKm} km', style: const TextStyle(color: Colors.grey)),
            const SizedBox(width: 12),
            HugeIcon(icon: HugeIcons.strokeRoundedMoney01, size: 16, color: accent),
            const SizedBox(width: 4),
            Text('Kamu dapat: ${_fmt(job.driverEarning)}', style: TextStyle(fontWeight: FontWeight.bold, color: accent)),
            if (isReturn) ...[
              const Spacer(),
              Text('COD: ${_fmt(job.totalCod)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ]),
          const SizedBox(height: 10),

          // Accept button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: () => _acceptJob(job),
              child: Text(isReturn ? 'Ambil Job Antar Balik' : 'Ambil Job Jemput'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _routeRow(List<List<dynamic>> icon, String title, String address) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HugeIcon(icon: icon, size: 18, color: Colors.grey),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(address, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
    ],
  );

  // ─── Active job screen ───────────────────────────────────────────────────────

  Widget _buildActiveJobScreen() {
    final job = _activeJob!.job;
    final isReturn = job.leg == _JobLeg.returnToCustomer;
    final step = _activeJob!.status;

    final (stepLabel, stepDesc, nextLabel, currentAddress) = switch (step) {
      'heading_to_pickup' => isReturn
          ? ('Menuju Merchant', 'Ambil barang yang sudah selesai dikerjakan', 'Barang Sudah Diambil dari Merchant', job.pickupAddress)
          : ('Menuju Customer', 'Jemput barang dari customer', 'Barang Sudah Diambil dari Customer', job.pickupAddress),
      'picked_up' => isReturn
          ? ('Menuju Customer', 'Antarkan barang kembali ke customer & terima COD', 'Sampai di Customer', job.dropoffAddress)
          : ('Menuju Merchant', 'Antar barang ke tempat jasa', 'Sampai di Merchant', job.dropoffAddress),
      _ => ('Selesai', '', 'Selesai', ''),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Job Aktif — ${job.orderNumber}'),
        leading: const SizedBox(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              color: isReturn ? Colors.green.shade50 : KuwrirColors.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  HugeIcon(icon: step == 'heading_to_pickup' ? HugeIcons.strokeRoundedNavigation01 : (step == 'picked_up' ? HugeIcons.strokeRoundedScooter01 : HugeIcons.strokeRoundedCheckmarkCircle02),
                      size: 48, color: isReturn ? Colors.green : KuwrirColors.primary),
                  const SizedBox(height: 8),
                  Text(stepLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(stepDesc, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Destination
            Card(
              child: ListTile(
                leading: const HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: KuwrirColors.primary),
                title: const Text('Tujuan Sekarang'),
                subtitle: Text(currentAddress, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMaps),
                  onPressed: () {},
                  tooltip: 'Buka Maps',
                ),
              ),
            ),

            // Job info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isReturn ? 'Customer: ${job.customerName}' : 'Customer: ${job.customerName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(isReturn ? 'Merchant: ${job.merchantName}' : 'Merchant: ${job.merchantName}', style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 12),
                  ...job.items.map((i) => Text('• $i', style: const TextStyle(fontSize: 13))),
                  if (job.serviceNotes.isNotEmpty)
                    Text('📝 ${job.serviceNotes}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (isReturn && step == 'picked_up') ...[
                    const Divider(height: 12),
                    Row(children: [
                      const HugeIcon(icon: HugeIcons.strokeRoundedPaymentSuccess01, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text('Terima COD: ${_fmt(job.totalCod)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                    ]),
                  ],
                ]),
              ),
            ),

            const Spacer(),

            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: isReturn ? Colors.green : KuwrirColors.primary),
                onPressed: _nextStep,
                child: Text(nextLabel, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
