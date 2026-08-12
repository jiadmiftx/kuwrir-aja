import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:vibration/vibration.dart';
import '../cubits/store_orders_cubit.dart';

/// Full-screen "incoming order" alarm — plays a looping siren + repeating
/// vibration until the merchant taps Terima or Tolak, mirroring how
/// Gojek/Grab surface new orders (rather than a normal notification the
/// merchant might not notice while busy). Reached either straight from
/// NotificationService (foreground push) or after a full-screen-intent
/// notification launches/foregrounds the app (see main.dart).
class IncomingOrderScreen extends StatefulWidget {
  final String orderId;
  const IncomingOrderScreen({super.key, required this.orderId});

  @override
  State<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends State<IncomingOrderScreen> {
  final _player = AudioPlayer();
  Map<String, dynamic>? _order;
  bool _loadingOrder = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startAlarm();
    _loadOrder();
  }

  Future<void> _startAlarm() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    unawaited(_player.play(AssetSource('sounds/order_alarm.wav'), volume: 1.0));
    if (await Vibration.hasVibrator()) {
      // Repeats the pattern until cancel() is called.
      Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400], repeat: 0);
    }
  }

  Future<void> _stopAlarm() async {
    await _player.stop();
    Vibration.cancel();
  }

  /// The push payload only carries `order_id` — reusing the merchant order
  /// list (already fetched every poll cycle) avoids needing a new backend
  /// endpoint just to hydrate this screen with item/total/customer details.
  Future<void> _loadOrder() async {
    try {
      final api = context.read<ApiClient>();
      final orders = await api.getMyStoreOrders();
      final match = orders.where((o) => o['id'] == widget.orderId);
      if (mounted) {
        setState(() {
          _order = match.isNotEmpty ? match.first : null;
          _loadingOrder = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrder = false);
    }
  }

  @override
  void dispose() {
    _stopAlarm();
    _player.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().acceptOrder(widget.orderId);
      if (mounted) context.read<StoreOrdersCubit>().load();
    } catch (_) {
      // Order list refresh on the previous screen will still reflect the
      // real state — no need to block exit on this call succeeding.
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    final reason = await _askRejectReason();
    if (reason == null) return; // cancelled the dialog
    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().rejectOrder(
        widget.orderId,
        reason: reason.isEmpty ? null : reason,
      );
      if (mounted) context.read<StoreOrdersCubit>().load();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<String?> _askRejectReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Tolak pesanan?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Alasan (opsional) — cth. stok habis',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Tolak Pesanan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final items = order?['items'] as List<dynamic>? ?? [];
    final total = (order?['total'] as num?)?.toDouble() ?? 0;
    final orderNumber = order?['order_number'] as String? ?? '';
    final receiverName = order?['receiver_name'] as String? ?? 'Customer';

    return PopScope(
      canPop: false, // must Accept/Reject — no accidental back-swipe dismiss
      child: Scaffold(
        backgroundColor: KuwrirColors.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pesanan Baru Masuk!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (orderNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '#$orderNumber',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: KuwrirColors.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: _loadingOrder
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receiverName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Divider(height: 1, color: KuwrirColors.border),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final item in items)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          '${item['quantity']}x ${item['item_name']}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: KuwrirColors.border),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Rp ${_fmt(total)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: KuwrirColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_submitting)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _reject,
                            child: const Text(
                              'Tolak',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: KuwrirColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _accept,
                            child: const Text(
                              'Terima Pesanan',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
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
