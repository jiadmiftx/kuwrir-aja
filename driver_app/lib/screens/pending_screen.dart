import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Step 3: Waiting for admin review.
/// Polls GET /driver/application every 30s to check if approved/rejected.
class DriverPendingScreen extends StatefulWidget {
  const DriverPendingScreen({super.key});

  @override
  State<DriverPendingScreen> createState() => _DriverPendingScreenState();
}

class _DriverPendingScreenState extends State<DriverPendingScreen> {
  String _status = 'pending'; // pending | approved | rejected
  String _note = '';
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Poll every 30 seconds
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
      final res = await client.get('/driver/application');
      if (!mounted) return;

      final app = res['application'];
      if (app != null) {
        setState(() {
          _status = app['status'] ?? 'pending';
          _note = app['review_note'] ?? '';
          _loading = false;
        });

        // If approved and is_active → go to job board
        if (_status == 'approved' && res['is_active'] == true) {
          _pollTimer?.cancel();
          Navigator.pushReplacementNamed(context, '/job_board');
        }
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildStatusIcon(),
              const SizedBox(height: 32),
              Text(
                _statusTitle(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _statusBody(),
                style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (_note.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _status == 'rejected' ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _status == 'rejected' ? Colors.red.shade200 : Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.comment, size: 16, color: _status == 'rejected' ? Colors.red : Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan admin: $_note',
                          style: TextStyle(color: _status == 'rejected' ? Colors.red.shade700 : Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (_status == 'pending') ...[
                if (_loading)
                  const CircularProgressIndicator()
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Cek Status'),
                    onPressed: _checkStatus,
                  ),
              ],
              if (_status == 'rejected') ...[
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Kirim Ulang Dokumen'),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Kembali ke Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_status) {
      case 'approved':
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, size: 80, color: Colors.green),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.cancel, size: 80, color: Colors.red),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
        );
    }
  }

  String _statusTitle() {
    switch (_status) {
      case 'approved': return 'Pendaftaran Disetujui! 🎉';
      case 'rejected': return 'Pendaftaran Ditolak';
      default:         return 'Sedang Diverifikasi';
    }
  }

  String _statusBody() {
    switch (_status) {
      case 'approved':
        return 'Selamat! Akun driver kamu sudah aktif. Kamu bisa mulai menerima order sekarang.';
      case 'rejected':
        return 'Maaf, pendaftaran kamu belum bisa disetujui. Perbaiki dokumen sesuai catatan admin dan coba lagi.';
      default:
        return 'Dokumen kamu sedang diperiksa oleh tim kami.\nProses verifikasi biasanya membutuhkan 1-2 hari kerja.\n\nKamu akan mendapat notifikasi setelah diproses.';
    }
  }
}
