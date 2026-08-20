import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/active_delivery_cubit.dart';
import '../widgets/open_in_maps_button.dart';
import '../widgets/whatsapp_launcher.dart';
import 'chat_screen.dart';

/// Detail view for one order — reached via "Lihat Detail" from the job
/// board, never forced. Has a real back button so the driver can return to
/// the board (which may show several concurrent active orders) at any time.
class ActiveDeliveryScreen extends StatelessWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActiveDeliveryCubit, ActiveDeliveryState>(
      listener: (context, state) {
        if (state is ActiveDeliveryDone) {
          _showDoneDialog(context, state.result);
        }
        if (state is ActiveDeliveryError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        Map<String, dynamic>? order;
        bool isLoading = false;

        if (state is ActiveDeliveryActive) order = state.order;
        if (state is ActiveDeliveryMarkingPickup) {
          order = state.order;
          isLoading = true;
        }
        if (state is ActiveDeliveryMarkingDelivered) {
          order = state.order;
          isLoading = true;
        }
        if (state is ActiveDeliveryDone) {
          return Scaffold(
            backgroundColor: KuwrirColors.background,
            appBar: AppBar(title: const Text('Selesai')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (order == null) {
          return Scaffold(
            backgroundColor: KuwrirColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return _buildScreen(context, order, isLoading);
      },
    );
  }

  Widget _buildScreen(
    BuildContext context,
    Map<String, dynamic> order,
    bool isLoading,
  ) {
    final status = order['status'] as String? ?? 'confirmed';
    final isPickedUp = status == 'picked_up';
    final orderId = order['id'] as String? ?? '';
    final orderNumber = order['order_number'] as String? ?? '';
    final merchantName =
        order['merchant_name'] as String? ??
        (order['merchant'] as Map?)?['name'] as String? ??
        'Merchant';
    final pickupAddress = order['pickup_address'] as String? ?? '';
    final dropoffAddress = order['dropoff_address'] as String? ?? '';
    final receiverName = order['receiver_name'] as String? ?? 'Customer';
    final receiverPhone = order['receiver_phone'] as String? ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final driverEarning = (order['driver_earning'] as num?)?.toDouble() ?? 0;
    final paymentType = order['payment_type'] as String? ?? 'cash';

    final merchant = order['merchant'] as Map<String, dynamic>?;
    final pickupLat = (merchant?['latitude'] as num?)?.toDouble() ?? -8.7185;
    final pickupLng = (merchant?['longitude'] as num?)?.toDouble() ?? 116.3516;
    final dropoffLat = (order['dropoff_lat'] as num?)?.toDouble() ?? -8.7185;
    final dropoffLng = (order['dropoff_lng'] as num?)?.toDouble() ?? 116.3516;
    final focusLat = isPickedUp ? dropoffLat : pickupLat;
    final focusLng = isPickedUp ? dropoffLng : pickupLng;
    final fallbackDistanceKm = (order['distance_km'] as num?)?.toDouble() ?? 0;

    void openMaps() => openInGoogleMaps(
      context: context,
      merchantLat: pickupLat,
      merchantLng: pickupLng,
      customerLat: dropoffLat,
      customerLng: dropoffLng,
    );

    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: Text(isPickedUp ? 'Antar ke Customer' : 'Ambil di Merchant'),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMessage01),
            tooltip: 'Chat dengan Customer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(orderId: orderId, orderNumber: orderNumber),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live delivery map
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(focusLat, focusLng),
                    initialZoom: 15,
                    onTap: (tapPosition, point) => openMaps(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kuwrir.driver',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(pickupLat, pickupLng),
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message: 'Merchant (Pickup)',
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedStore01,
                              color: KuwrirColors.warning,
                              size: 40,
                            ),
                          ),
                        ),
                        Marker(
                          point: LatLng(dropoffLat, dropoffLng),
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message: 'Customer (Dropoff)',
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedPinLocation01,
                              color: KuwrirColors.error,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(pickupLat, pickupLng),
                            LatLng(dropoffLat, dropoffLng),
                          ],
                          color: KuwrirColors.primary,
                          strokeWidth: 3,
                          pattern: StrokePattern.dashed(
                            segments: const [12, 8],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: OpenInMapsButton(onTap: openMaps),
                ),
              ],
            ),
          ),

          // Order details bottom sheet
          Container(
            decoration: BoxDecoration(
              color: KuwrirColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: KuwrirColors.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Order number + earning
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPickedUp ? 'Antar ke Customer' : 'Ambil di Merchant',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: KuwrirColors.primary,
                      ),
                    ),
                    Text(
                      '#$orderNumber',
                      style: TextStyle(
                        color: KuwrirColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Penghasilan: Rp ${_fmt(driverEarning)}',
                  style: const TextStyle(
                    color: KuwrirColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                _RoadDistanceLabel(
                  orderId: orderId,
                  fallbackKm: fallbackDistanceKm,
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: KuwrirColors.border),
                const SizedBox(height: 14),

                // Location info
                if (!isPickedUp) ...[
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedStore01,
                    color: KuwrirColors.warning,
                    label: merchantName,
                    sub: pickupAddress,
                  ),
                ] else ...[
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedUser,
                    color: KuwrirColors.info,
                    label: receiverName,
                    sub: receiverPhone,
                    trailing: receiverPhone.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Chat WhatsApp',
                            onPressed: () =>
                                openWhatsApp(context, receiverPhone),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedWhatsapp,
                              color: KuwrirColors.success,
                              size: 22,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: HugeIcons.strokeRoundedLocation01,
                    color: KuwrirColors.error,
                    label: dropoffAddress,
                    sub: '',
                  ),
                ],

                if (paymentType == 'cash' && isPickedUp) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KuwrirColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedPaymentSuccess01,
                          color: KuwrirColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tagih COD: Rp ${_fmt(total)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KuwrirColors.warning,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (!isPickedUp)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: KuwrirColors.warning,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context
                          .read<ActiveDeliveryCubit>()
                          .markPickedUp(orderId),
                      child: const Text(
                        'Sudah Diambil',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: KuwrirColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context
                          .read<ActiveDeliveryCubit>()
                          .markDelivered(orderId),
                      child: const Text(
                        'Selesai Diantarkan',
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
        ],
      ),
    );
  }

  void _showDoneDialog(BuildContext context, Map<String, dynamic> result) {
    final cashCollected = (result['cash_collected'] as num?)?.toDouble() ?? 0;
    final driverEarning = (result['driver_earning'] as num?)?.toDouble() ?? 0;

    showDialog(
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
                'Uang COD diterima: Rp ${_fmt(cashCollected)}',
                style: const TextStyle(fontSize: 14.5),
              ),
            const SizedBox(height: 6),
            Text(
              'Penghasilan: Rp ${_fmt(driverEarning)}',
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
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KuwrirColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Kembali ke Job Board',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

/// Road-following distance/duration for this delivery. Shows the straight-line
/// `fallbackKm` immediately (no blocking spinner on first paint), then swaps
/// to the OpenRouteService road value once `/driver-orders/:id/road-route`
/// resolves — or stays on the fallback, honestly, if that call fails.
class _RoadDistanceLabel extends StatefulWidget {
  final String orderId;
  final double fallbackKm;
  const _RoadDistanceLabel({required this.orderId, required this.fallbackKm});

  @override
  State<_RoadDistanceLabel> createState() => _RoadDistanceLabelState();
}

class _RoadDistanceLabelState extends State<_RoadDistanceLabel> {
  double? _roadKm;
  double? _durationMin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiClient>();
      final result = await api.getDriverRoadRoute(widget.orderId);
      if (!mounted || result['source'] != 'road') return;
      setState(() {
        _roadKm = (result['distance_km'] as num?)?.toDouble();
        _durationMin = (result['duration_min'] as num?)?.toDouble();
      });
    } catch (_) {
      // Stay on the straight-line fallback — this is a display-only nicety,
      // not worth surfacing an error for.
    }
  }

  String _fmtKm(double v) => v.toStringAsFixed(1).replaceAll('.0', '');

  @override
  Widget build(BuildContext context) {
    final km = _roadKm ?? widget.fallbackKm;
    final label = _durationMin != null
        ? '≈ ${_fmtKm(km)} km · ${_durationMin!.round()} menit'
        : '≈ ${_fmtKm(km)} km';
    return Text(
      label,
      style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 12.5),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String label;
  final String sub;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    this.trailing,
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(icon: icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: TextStyle(
                    color: KuwrirColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
