import 'dart:async';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/job_board_cubit.dart';
import '../cubits/active_delivery_cubit.dart';
import '../services/location_service.dart';
import '../widgets/open_in_maps_button.dart';
import '../widgets/whatsapp_launcher.dart';
import '../widgets/driver_drawer.dart';
import 'active_delivery_screen.dart';

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isOnline = state is JobBoardLoaded && state.isOnline;

        return Scaffold(
          backgroundColor: KuwrirColors.background,
          drawer: const DriverDrawer(),
          appBar: AppBar(
            title: const Text('Job Board'),
            actions: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isOnline
                                  ? KuwrirColors.success
                                  : KuwrirColors.textHint)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isOnline
                            ? KuwrirColors.success
                            : KuwrirColors.textHint,
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
            ],
          ),
          body: _buildFoodTab(context, state),
        );
      },
    );
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
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedWifiOff01,
                  size: 36,
                  color: KuwrirColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Anda sedang offline',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: KuwrirColors.textPrimary,
                ),
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

    if (state is JobBoardLoading || state is JobBoardAccepting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is JobBoardLoaded) {
      final myActive = state.myActiveOrders;
      final pending = <Map<String, dynamic>>[];
      final others = <Map<String, dynamic>>[];
      for (final job in state.jobs) {
        final assignment = job['assignment_status'] as String? ?? 'unassigned';
        if (assignment == 'mine_active') continue; // already shown via myActive
        if (assignment == 'mine_pending') {
          pending.add(job);
        } else {
          others.add(job);
        }
      }

      if (myActive.isEmpty && pending.isEmpty && others.isEmpty) {
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
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedInbox,
                          size: 36,
                          color: KuwrirColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Belum ada pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: KuwrirColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tarik ke bawah untuk refresh',
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
        );
      }

      return RefreshIndicator(
        onRefresh: () => context.read<JobBoardCubit>().loadJobs(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (myActive.isNotEmpty) ...[
              _SectionHeader('Sedang Kamu Antar'),
              const SizedBox(height: 10),
              ...myActive.map((o) => _ActiveOrderCard(order: o)),
              const SizedBox(height: 8),
            ],
            if (pending.isNotEmpty) ...[
              _SectionHeader('Ditugaskan Untukmu'),
              const SizedBox(height: 10),
              ...pending.map((job) => _JobCard(job: job)),
              const SizedBox(height: 8),
            ],
            if (others.isNotEmpty) ...[
              _SectionHeader('Pesanan Lain'),
              const SizedBox(height: 10),
              ...others.map((job) => _OtherJobCard(job: job)),
            ],
          ],
        ),
      );
    }

    if (state is JobBoardError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.message,
              style: TextStyle(color: KuwrirColors.textSecondary),
            ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: KuwrirColors.textHint,
      ),
    );
  }
}

double _lat(Map<String, dynamic> order, String key) {
  if (key == 'pickup') {
    final merchant = order['merchant'] as Map<String, dynamic>?;
    return (merchant?['latitude'] as num?)?.toDouble() ?? -8.7185;
  }
  return (order['dropoff_lat'] as num?)?.toDouble() ?? -8.7185;
}

double _lng(Map<String, dynamic> order, String key) {
  if (key == 'pickup') {
    final merchant = order['merchant'] as Map<String, dynamic>?;
    return (merchant?['longitude'] as num?)?.toDouble() ?? 116.3516;
  }
  return (order['dropoff_lng'] as num?)?.toDouble() ?? 116.3516;
}

String _fmtMoney(double v) => v
    .toStringAsFixed(0)
    .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

/// Card for an order the driver has already accepted and is carrying — shows
/// the 1-tap Google Maps route CTA plus a "Lihat Detail" button that opens
/// the full map/status-update screen for just that order. The board stays
/// visible underneath; this never forces navigation.
class _ActiveOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  const _ActiveOrderCard({required this.order});

  @override
  State<_ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends State<_ActiveOrderCard> {
  bool _updating = false;

  Future<void> _markPickedUp() async {
    final orderId = widget.order['id'] as String? ?? '';
    final api = context.read<ApiClient>();
    setState(() => _updating = true);
    try {
      await api.markPickedUp(orderId);
      unawaited(LocationService.sendCurrentLocation(api));
      if (mounted) context.read<JobBoardCubit>().loadJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Gagal konfirmasi pickup',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _markDelivered() async {
    final orderId = widget.order['id'] as String? ?? '';
    final api = context.read<ApiClient>();
    setState(() => _updating = true);
    try {
      final result = await api.markDelivered(orderId);
      unawaited(LocationService.sendCurrentLocation(api));
      if (mounted) await _showDoneDialog(result);
      if (mounted) context.read<JobBoardCubit>().loadJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Gagal konfirmasi pengiriman',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _showDoneDialog(Map<String, dynamic> result) {
    final cashCollected = (result['cash_collected'] as num?)?.toDouble() ?? 0;
    final driverEarning = (result['driver_earning'] as num?)?.toDouble() ?? 0;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Pengiriman Selesai!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cashCollected > 0)
              Text(
                'Uang COD diterima: Rp ${_fmtMoney(cashCollected)}',
                style: const TextStyle(fontSize: 14.5),
              ),
            const SizedBox(height: 6),
            Text(
              'Penghasilan: Rp ${_fmtMoney(driverEarning)}',
              style: const TextStyle(
                fontSize: 15,
                color: KuwrirColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KuwrirColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Oke',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderNumber = order['order_number'] as String? ?? '-';
    final status = order['status'] as String? ?? 'ready';
    final isPickedUp = status == 'picked_up';
    final merchantName =
        order['merchant_name'] as String? ??
        (order['merchant'] as Map?)?['name'] as String? ??
        'Merchant';
    final pickupAddress = order['pickup_address'] as String? ?? '';
    final dropoffAddress = order['dropoff_address'] as String? ?? '';
    final receiverName = order['receiver_name'] as String? ?? '';
    final receiverPhone = order['receiver_phone'] as String? ?? '';
    final driverEarning = (order['driver_earning'] as num?)?.toDouble() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final paymentType = order['payment_type'] as String? ?? 'cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.primary.withValues(alpha: 0.3)),
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
                  'Rp ${_fmtMoney(driverEarning)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KuwrirColors.primary,
                  ),
                ),
                Text(
                  '#$orderNumber',
                  style: TextStyle(fontSize: 12, color: KuwrirColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Two-stage progress: which leg of the trip this order is on,
            // so a driver returning to the board (not just the detail
            // screen) can tell at a glance whether they still need to swing
            // by the merchant or are already headed to the customer.
            _TripStageBar(isPickedUp: isPickedUp),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HugeIcon(
                  icon: isPickedUp
                      ? HugeIcons.strokeRoundedUser
                      : HugeIcons.strokeRoundedStore01,
                  size: 16,
                  color: isPickedUp ? KuwrirColors.error : KuwrirColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPickedUp
                            ? (receiverName.isNotEmpty
                                  ? receiverName
                                  : 'Customer')
                            : merchantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        isPickedUp ? dropoffAddress : pickupAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: KuwrirColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPickedUp && receiverPhone.isNotEmpty)
                  IconButton(
                    tooltip: 'Chat WhatsApp',
                    onPressed: () => openWhatsApp(context, receiverPhone),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedWhatsapp,
                      color: KuwrirColors.success,
                      size: 20,
                    ),
                  ),
              ],
            ),

            if (paymentType == 'cash' && isPickedUp) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: KuwrirColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPaymentSuccess01,
                      size: 16,
                      color: KuwrirColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tagih COD: Rp ${_fmtMoney(total)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: KuwrirColors.warning,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPickedUp
                      ? KuwrirColors.success
                      : KuwrirColors.warning,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _updating
                    ? null
                    : (isPickedUp ? _markDelivered : _markPickedUp),
                child: _updating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isPickedUp
                            ? 'Selesai Diantarkan'
                            : 'Sudah Diambil dari Merchant',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OpenInMapsButton(
                  onTap: () => openInGoogleMaps(
                    context: context,
                    merchantLat: _lat(order, 'pickup'),
                    merchantLng: _lng(order, 'pickup'),
                    customerLat: _lat(order, 'dropoff'),
                    customerLng: _lng(order, 'dropoff'),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider<ActiveDeliveryCubit>(
                          create: (ctx) =>
                              ActiveDeliveryCubit(ctx.read<ApiClient>(), order),
                          child: const ActiveDeliveryScreen(),
                        ),
                      ),
                    );
                    if (context.mounted) {
                      context.read<JobBoardCubit>().loadJobs();
                    }
                  },
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMaps,
                    size: 16,
                  ),
                  label: const Text(
                    'Lihat Detail',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-segment "Ambil di Merchant -> Antar ke Customer" progress bar —
/// makes the job board card itself (not just the detail screen) show which
/// leg of the trip an order is on.
class _TripStageBar extends StatelessWidget {
  final bool isPickedUp;
  const _TripStageBar({required this.isPickedUp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stageDot(done: true),
        Expanded(
          child: Container(
            height: 2,
            color: isPickedUp ? KuwrirColors.success : KuwrirColors.border,
          ),
        ),
        _stageDot(done: isPickedUp),
        const SizedBox(width: 8),
        Expanded(
          flex: 0,
          child: Text(
            isPickedUp ? 'Menuju Customer' : 'Menuju Merchant',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isPickedUp ? KuwrirColors.success : KuwrirColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stageDot({required bool done}) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? KuwrirColors.success : KuwrirColors.border,
      ),
    );
  }
}

/// Read-only card for an order not assigned to this driver — either still
/// unassigned (waiting on admin) or already taken by another driver. Full
/// board visibility per the requested change; no action available here.
class _OtherJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  const _OtherJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final assignment = job['assignment_status'] as String? ?? 'unassigned';
    final isTaken = assignment == 'other';
    final orderNumber = job['order_number'] as String? ?? '-';
    final merchantName = job['merchant_name'] as String? ?? 'Merchant';
    final dropoffAddress = job['dropoff_address'] as String? ?? '';

    return Opacity(
      opacity: 0.65,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KuwrirColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KuwrirColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$orderNumber',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: KuwrirColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$merchantName → $dropoffAddress',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isTaken ? KuwrirColors.textHint : KuwrirColors.warning)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                isTaken ? 'Diambil Driver Lain' : 'Menunggu Admin',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isTaken ? KuwrirColors.textHint : KuwrirColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    // Admin can pre-assign a driver as early as confirmed/preparing (see
    // backend AssignDriverToOrder) so they're lined up before the order is
    // actually ready — but AcceptDelivery still only lets the driver confirm
    // once it hits ready, so the button stays disabled/informational until
    // then instead of letting them tap into a guaranteed-400 request.
    final status = job['status'] as String? ?? 'ready';
    final isReady = status == 'ready';

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
                  'Rp ${_fmtMoney(driverEarning)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: KuwrirColors.primary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: KuwrirColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '#$orderNumber',
              style: TextStyle(fontSize: 12, color: KuwrirColors.textHint),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: KuwrirColors.border),
            const SizedBox(height: 12),

            // Pickup
            _AddressRow(
              icon: HugeIcons.strokeRoundedStore01,
              iconColor: KuwrirColors.warning,
              label: 'Ambil di',
              name: merchantName,
              address: pickupAddress,
            ),
            const SizedBox(height: 12),

            // Dropoff
            _AddressRow(
              icon: HugeIcons.strokeRoundedLocation01,
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
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPaymentSuccess01,
                      size: 16,
                      color: KuwrirColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tagih COD: Rp ${_fmtMoney(total)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: KuwrirColors.warning,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            if (!isReady)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: KuwrirColors.textHint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: KuwrirColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Menunggu Merchant Siapkan Pesanan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: KuwrirColors.textHint,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KuwrirColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _accepting
                      ? null
                      : () => _accept(context, orderId),
                  child: _accepting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Terima Tugas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, String orderId) async {
    setState(() => _accepting = true);
    await context.read<JobBoardCubit>().acceptJob(orderId);
    if (!mounted) return;
    setState(() => _accepting = false);
  }
}

class _AddressRow extends StatelessWidget {
  final List<List<dynamic>> icon;
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
          child: HugeIcon(icon: icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: KuwrirColors.textHint, fontSize: 11.5),
              ),
              if (name.isNotEmpty)
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              Text(
                address,
                style: TextStyle(
                  fontSize: 12,
                  color: KuwrirColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
