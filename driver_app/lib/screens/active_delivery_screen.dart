import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/active_delivery_cubit.dart';

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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (state is ActiveDeliveryIdle) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pengiriman Aktif')),
            body: const Center(child: Text('Tidak ada pengiriman aktif')),
          );
        }

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
            appBar: AppBar(title: const Text('Selesai')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (order == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildScreen(context, order, isLoading);
      },
    );
  }

  Widget _buildScreen(
      BuildContext context, Map<String, dynamic> order, bool isLoading) {
    final status = order['status'] as String? ?? 'confirmed';
    final isPickedUp = status == 'picked_up';
    final orderId = order['id'] as String? ?? '';
    final orderNumber = order['order_number'] as String? ?? '';
    final merchantName = order['merchant_name'] as String? ??
        (order['merchant'] as Map?)?['name'] as String? ?? 'Merchant';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isPickedUp ? 'Antar ke Customer' : 'Ambil di Merchant'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Live delivery map
          Expanded(
            flex: 2,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(focusLat, focusLng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kuwrir.driver',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(pickupLat, pickupLng),
                      width: 48,
                      height: 48,
                      child: const Tooltip(
                        message: 'Merchant (Pickup)',
                        child: Icon(Icons.store, color: Colors.orange, size: 40),
                      ),
                    ),
                    Marker(
                      point: LatLng(dropoffLat, dropoffLng),
                      width: 48,
                      height: 48,
                      child: const Tooltip(
                        message: 'Customer (Dropoff)',
                        child: Icon(Icons.location_pin, color: Colors.red, size: 40),
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
                      isDotted: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Order details bottom sheet
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: KuwrirColors.primary),
                    ),
                    Text('#$orderNumber',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Penghasilan: Rp ${_fmt(driverEarning)}',
                  style: const TextStyle(
                      color: KuwrirColors.success, fontWeight: FontWeight.w600),
                ),
                const Divider(height: 20),

                // Location info
                if (!isPickedUp) ...[
                  _InfoRow(
                    icon: Icons.store,
                    color: Colors.orange,
                    label: merchantName,
                    sub: pickupAddress,
                  ),
                ] else ...[
                  _InfoRow(
                    icon: Icons.person,
                    color: Colors.blue,
                    label: receiverName,
                    sub: receiverPhone,
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.location_on,
                    color: Colors.red,
                    label: dropoffAddress,
                    sub: '',
                  ),
                ],

                if (paymentType == 'cash' && isPickedUp) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Tagih COD: Rp ${_fmt(total)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (!isPickedUp)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () =>
                        context.read<ActiveDeliveryCubit>().markPickedUp(orderId),
                    child: const Text('Sudah Diambil',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: KuwrirColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () =>
                        context.read<ActiveDeliveryCubit>().markDelivered(orderId),
                    child: const Text('Selesai Diantarkan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
        title: const Text('Pengiriman Selesai!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cashCollected > 0)
              Text('Uang COD diterima: Rp ${_fmt(cashCollected)}',
                  style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text('Penghasilan: Rp ${_fmt(driverEarning)}',
                style: const TextStyle(
                    fontSize: 15,
                    color: KuwrirColors.success,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ActiveDeliveryCubit>().reset();
              Navigator.of(context).pop();
            },
            child: const Text('Kembali ke Job Board'),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;

  const _InfoRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              if (sub.isNotEmpty)
                Text(sub,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
