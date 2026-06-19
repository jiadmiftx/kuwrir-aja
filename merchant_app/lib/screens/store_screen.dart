import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Store Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),

          // Store banner
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: KuwrirColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 32, color: KuwrirColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'Upload Banner',
                    style: TextStyle(color: KuwrirColors.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Store details
          _InfoTile(
            icon: Icons.store,
            label: 'Store Name',
            value: 'Warung Nasi Campur Bu Eka',
          ),
          _InfoTile(
            icon: Icons.phone,
            label: 'Phone',
            value: '08123456789',
          ),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: 'Jl. Raya Kuta, Lombok Tengah',
          ),
          _InfoTile(
            icon: Icons.star,
            label: 'Rating',
            value: '4.8 (124 reviews)',
          ),

          const SizedBox(height: 24),

          // Toggle store open/closed
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store Status',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggle to accept or stop orders',
                        style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: true,
                    onChanged: (_) {
                      // TODO: Call API PUT /my-merchant/toggle-open
                    },
                    activeColor: KuwrirColors.success,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Self-delivery toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Self-Delivery',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Antar pesanan sendiri tanpa driver Kuwrir',
                          style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: false,
                    onChanged: (_) {
                      // TODO: Call API PUT /my-store/toggle-self-deliver
                    },
                    activeColor: KuwrirColors.primary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Self-delivery fee
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ongkir Self-Delivery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tarif ongkir saat Anda mengantar sendiri (0 = gratis)',
                    style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Rp ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Call API PUT /my-store/self-delivery-fee
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sales summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Summary',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatBox(label: 'Orders', value: '0'),
                      const SizedBox(width: 12),
                      _StatBox(label: 'Revenue', value: 'IDR 0'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KuwrirColors.textSecondary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: KuwrirColors.textHint),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KuwrirColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
