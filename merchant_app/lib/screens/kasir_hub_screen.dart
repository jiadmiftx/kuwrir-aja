import 'package:flutter/material.dart';
import 'kasir_screen.dart';
import 'kasir_reports_screen.dart';
import 'kasir_receivables_screen.dart';
import 'kasir_payables_screen.dart';
import 'package:hugeicons/hugeicons.dart';

/// KasirHub is the entry point for all POS/Kasir features.
/// Provides quick-access tiles to: POS Terminal, Piutang, Hutang, Laporan.
class KasirHub extends StatelessWidget {
  const KasirHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary action — POS Terminal
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton.icon(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedCreditCardPos, size: 28),
                label: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buka Kasir / POS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Catat transaksi penjualan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                  ],
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KasirScreen())),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Keuangan Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 12),

            // 2x2 grid of financial features
            Row(
              children: [
                Expanded(child: _hubTile(context, HugeIcons.strokeRoundedAnalyticsUp, 'Laporan', 'Laba Rugi · Arus Kas · Stok', Colors.green, const KasirReportsScreen())),
                const SizedBox(width: 12),
                Expanded(child: _hubTile(context, HugeIcons.strokeRoundedArrowRight01, 'Piutang', 'Tab & kredit pelanggan', Colors.blue, const KasirReceivablesScreen())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _hubTile(context, HugeIcons.strokeRoundedArrowLeft01, 'Hutang', 'Pembelian bahan supplier', Colors.red, const KasirPayablesScreen())),
                const SizedBox(width: 12),
                Expanded(child: _hubTile(context, HugeIcons.strokeRoundedPackage, 'Stok', 'Cek & sesuaikan stok', Colors.orange, const KasirReportsScreen())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hubTile(BuildContext context, List<List<dynamic>> icon, String title, String subtitle, Color color, Widget screen) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: HugeIcon(icon: icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
