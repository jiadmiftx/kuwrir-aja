import 'dart:async';
import 'package:hugeicons/hugeicons.dart';
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
      backgroundColor: KuwrirColors.background,
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: KuwrirColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _statusBody(),
                style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 14.5, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (_note.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_status == 'rejected' ? KuwrirColors.error : KuwrirColors.info).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: (_status == 'rejected' ? KuwrirColors.error : KuwrirColors.info).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedComment01, size: 16, color: _status == 'rejected' ? KuwrirColors.error : KuwrirColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan admin: $_note',
                          style: TextStyle(
                            color: _status == 'rejected' ? KuwrirColors.error : KuwrirColors.info,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 36),
              if (_status == 'pending') ...[
                if (_loading)
                  const CircularProgressIndicator()
                else
                  OutlinedButton.icon(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
                    label: const Text('Cek Status'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KuwrirColors.primary,
                      side: BorderSide(color: KuwrirColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _checkStatus,
                  ),
              ],
              if (_status == 'rejected') ...[
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: KuwrirColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedFileUpload),
                    label: const Text('Kirim Ulang Dokumen', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text('Kembali ke Login', style: TextStyle(color: KuwrirColors.textSecondary)),
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
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: KuwrirColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, size: 40, color: KuwrirColors.success),
        );
      case 'rejected':
        return Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: KuwrirColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 40, color: KuwrirColors.error),
        );
      default:
        return Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: KuwrirColors.warning.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 40, color: KuwrirColors.warning),
        );
    }
  }

  String _statusTitle() {
    switch (_status) {
      case 'approved': return 'Pendaftaran Disetujui!';
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
