import 'package:flutter/material.dart';

import 'package:kuwrir_shared/kuwrir_shared.dart';

class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  bool _isOnline = false;
  List<Order> _availableOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('/driver-orders/available');
      if (response['orders'] != null) {
        setState(() {
          _availableOrders = (response['orders'] as List)
              .map((json) => Order.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch orders: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await ApiClient().post('/driver-orders/$orderId/accept', {});
      if (!mounted) return;
      
      // Navigate to active delivery screen
      Navigator.pushReplacementNamed(context, '/active_delivery', arguments: orderId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Board'),
        actions: [
          Row(
            children: [
              Text(_isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isOnline ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  )),
              Switch(
                value: _isOnline,
                onChanged: (val) {
                  setState(() => _isOnline = val);
                  if (val) _fetchOrders();
                },
                activeTrackColor: Colors.green,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.pushNamed(context, '/wallet'),
          ),
        ],
      ),
      body: !_isOnline
          ? const Center(
              child: Text(
                'You are offline.\nGo online to see available orders.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _availableOrders.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(
                              child: Text(
                                'No available orders right now.',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _availableOrders.length,
                          itemBuilder: (context, index) {
                            final order = _availableOrders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                                          'Earning: Rp ${order.driverEarning.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: KuwrirColors.primary,
                                          ),
                                        ),
                                        Text(
                                          '${order.distanceKm.toStringAsFixed(1)} km',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.store, color: Colors.orange, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Pickup', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              Text(order.senderName ?? 'Unknown Store', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text(order.pickupAddress ?? '', style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Drop-off', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              Text(order.dropoffAddress, style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: KuwrirColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () => _acceptOrder(order.id),
                                        child: const Text('Accept Delivery'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
