import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  Order? _order;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orderId = ModalRoute.of(context)?.settings.arguments as String?;
    if (orderId != null && _order == null) {
      _fetchOrder(orderId);
    }
  }

  Future<void> _fetchOrder(String orderId) async {
    try {
      final response = await ApiClient().get('/orders/$orderId');
      if (mounted) {
        setState(() {
          _order = Order.fromJson(response['order']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markPickedUp() async {
    if (_order == null) return;
    setState(() => _isLoading = true);
    try {
      await ApiClient().post('/driver-orders/${_order!.id}/pickup', {});
      await _fetchOrder(_order!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markDelivered() async {
    if (_order == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().post('/driver-orders/${_order!.id}/deliver', {});
      if (!mounted) return;
      
      final cashCollected = res['cash_collected'];
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Delivery Complete! 🎉'),
          content: Text('You collected Rp $cashCollected in cash.\nGreat job!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pushReplacementNamed('/job_board');
              },
              child: const Text('Back to Job Board'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete delivery: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Delivery')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final isPickedUp = _order!.status == 'picked_up';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPickedUp ? 'Deliver to Customer' : 'Pickup at Store'),
      ),
      body: Column(
        children: [
          // Map Placeholder
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Map Integration (Phase 5)'),
                  ],
                ),
              ),
            ),
          ),
          
          // Order Details Card
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPickedUp ? 'Drop-off' : 'Pick-up',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: KuwrirColors.primary,
                          ),
                        ),
                        Text(
                          'Order #${_order!.orderNumber.substring(4)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPickedUp ? (_order!.receiverName ?? 'Customer') : (_order!.senderName ?? 'Store'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPickedUp ? _order!.dropoffAddress : (_order!.pickupAddress ?? ''),
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    
                    if (!isPickedUp)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _markPickedUp,
                        child: const Text('Mark as Picked Up', style: TextStyle(fontSize: 18)),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _markDelivered,
                        child: Text(
                          'Complete Delivery (Collect Rp ${_order!.total.toStringAsFixed(0)})', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
