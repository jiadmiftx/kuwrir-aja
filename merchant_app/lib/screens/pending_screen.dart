import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Merchant waiting for admin verification.
/// Polls GET /my-store/status every 30s.
class MerchantPendingScreen extends StatefulWidget {
  const MerchantPendingScreen({super.key});

  @override
  State<MerchantPendingScreen> createState() => _MerchantPendingScreenState();
}

class _MerchantPendingScreenState extends State<MerchantPendingScreen> {
  String _status = 'pending';
  String _note = '';
  String _storeName = '';
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final client = ApiClient();
      final res = await client.get('/my-store/status');
      if (!mounted) return;
      setState(() {
        _status = res['status'] ?? 'pending';
        _note = res['verification_note'] ?? '';
        _storeName = res['name'] ?? '';
        _loading = false;
      });
      // If approved → go to main app
      if (_status == 'approved' && res['is_active'] == true) {
        _pollTimer?.cancel();
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statusIcon(),
              const SizedBox(height: 32),
              if (_storeName.isNotEmpty)
                Text(_storeName, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(_title(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(_body(), style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
              if (_note.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _status == 'rejected' ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _status == 'rejected' ? Colors.red.shade200 : Colors.blue.shade200),
                  ),
                  child: Text('Catatan admin: $_note',
                      style: TextStyle(color: _status == 'rejected' ? Colors.red.shade700 : Colors.blue.shade700)),
                ),
              ],
              const SizedBox(height: 40),
              if (_status == 'pending')
                OutlinedButton.icon(
                  icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                  label: const Text('Cek Status'),
                  onPressed: _loading ? null : _checkStatus,
                ),
              if (_status == 'rejected')
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Daftar Ulang'),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('Logout')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon() {
    switch (_status) {
      case 'approved':
        return const Icon(Icons.check_circle, size: 96, color: Colors.green);
      case 'rejected':
        return const Icon(Icons.cancel, size: 96, color: Colors.red);
      default:
        return const Icon(Icons.pending_actions, size: 96, color: Colors.orange);
    }
  }

  String _title() {
    switch (_status) {
      case 'approved': return 'Toko Disetujui! 🎉';
      case 'rejected': return 'Pendaftaran Ditolak';
      default:         return 'Menunggu Verifikasi';
    }
  }

  String _body() {
    switch (_status) {
      case 'approved': return 'Toko kamu sudah aktif. Selamat berjualan di KUWRIR!';
      case 'rejected': return 'Pendaftaran toko belum disetujui. Perbaiki sesuai catatan admin dan daftar ulang.';
      default:         return 'Dokumen toko kamu sedang diperiksa.\nProses verifikasi biasanya 1-2 hari kerja.';
    }
  }
}
