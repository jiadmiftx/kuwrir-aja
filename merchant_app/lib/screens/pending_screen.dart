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
  bool _refreshing = false;
  Timer? _pollTimer;

  static const _gold = Color(0xFFB8862E);
  static const _goldSoft = Color(0xFFF3E7D3);
  static const _rust = Color(0xFFB8483A);
  static const _rustSoft = Color(0xFFF3DCD8);
  static const _forest = Color(0xFF0F6B3F);
  static const _forestSoft = Color(0xFFDCEEE2);

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

  Future<void> _checkStatus({bool manual = false}) async {
    if (manual) setState(() => _refreshing = true);
    try {
      final client = ApiClient();
      final res = await client.get('/my-store/status');
      if (!mounted) return;
      setState(() {
        _status = res['status'] ?? 'pending';
        _note = res['verification_note'] ?? '';
        _storeName = res['name'] ?? '';
        _loading = false;
        _refreshing = false;
      });
      if (_status == 'approved' && res['is_active'] == true) {
        _pollTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _refreshing = false; });
    }
  }

  Color get _accent {
    switch (_status) {
      case 'approved': return _forest;
      case 'rejected': return _rust;
      default: return _gold;
    }
  }

  Color get _accentSoft {
    switch (_status) {
      case 'approved': return _forestSoft;
      case 'rejected': return _rustSoft;
      default: return _goldSoft;
    }
  }

  IconData get _icon {
    switch (_status) {
      case 'approved': return Icons.check_rounded;
      case 'rejected': return Icons.priority_high_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }

  String _title() {
    switch (_status) {
      case 'approved': return 'Toko Disetujui';
      case 'rejected': return 'Perlu Sedikit Perbaikan';
      default: return 'Menunggu Verifikasi';
    }
  }

  String _body() {
    switch (_status) {
      case 'approved':
        return 'Toko kamu sudah aktif. Selamat berjualan di KUWRIR.';
      case 'rejected':
        return 'Ada beberapa hal yang perlu dilengkapi sebelum toko kamu bisa disetujui.';
      default:
        return 'Tim kami sedang memeriksa dokumen tokomu. Biasanya selesai dalam 1–2 hari kerja.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      body: SafeArea(
        child: _loading ? const _InitialLoading() : Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutQuint,
                    switchOutCurve: Curves.easeInQuint,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _StatusBadge(
                      key: ValueKey(_status),
                      color: _accent,
                      soft: _accentSoft,
                      icon: _icon,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_storeName.isNotEmpty) ...[
                    Text(
                      _storeName.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: KuwrirColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    _title(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: KuwrirColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _body(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: KuwrirColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                  if (_status == 'pending') ...[
                    const SizedBox(height: 36),
                    const _VerificationTracker(),
                  ],
                  if (_note.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _NoteCard(status: _status, note: _note, accent: _accent),
                  ],
                  const SizedBox(height: 40),
                  if (_status == 'pending')
                    TextButton.icon(
                      onPressed: _refreshing ? null : () => _checkStatus(manual: true),
                      style: TextButton.styleFrom(
                        foregroundColor: KuwrirColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: BorderSide(color: KuwrirColors.border),
                        ),
                      ),
                      icon: _refreshing
                          ? const SizedBox(
                              width: 15, height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Perbarui Status', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  if (_status == 'rejected')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: KuwrirColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                        child: const Text('Lengkapi & Daftar Ulang',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    style: TextButton.styleFrom(foregroundColor: KuwrirColors.textHint),
                    child: const Text('Keluar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialLoading extends StatelessWidget {
  const _InitialLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28, height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: KuwrirColors.primary),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final Color soft;
  final IconData icon;
  const _StatusBadge({super.key, required this.color, required this.soft, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: soft,
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KuwrirColors.surface,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: color),
          ),
        ],
      ),
    );
  }
}

/// A quiet 3-step tracker (Diajukan → Diperiksa → Keputusan) — gives the
/// pending state a sense of concrete progress instead of an indefinite
/// spinner, and its horizontal symmetry anchors the whole composition.
class _VerificationTracker extends StatelessWidget {
  const _VerificationTracker();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(done: true),
        _line(done: true),
        _dot(done: false, active: true),
        _line(done: false),
        _dot(done: false),
      ],
    );
  }

  Widget _dot({required bool done, bool active = false}) {
    return Container(
      width: active ? 12 : 9,
      height: active ? 12 : 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? KuwrirColors.primary : (active ? Colors.white : KuwrirColors.border),
        border: active ? Border.all(color: KuwrirColors.primary, width: 2.5) : null,
      ),
      child: done ? const Icon(Icons.check, size: 7, color: Colors.white) : null,
    );
  }

  Widget _line({required bool done}) {
    return Expanded(
      child: Container(
        height: 2,
        color: done ? KuwrirColors.primary : KuwrirColors.border,
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String status;
  final String note;
  final Color accent;
  const _NoteCard({required this.status, required this.note, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'Catatan Admin',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: TextStyle(fontSize: 13.5, color: KuwrirColors.textPrimary.withValues(alpha: 0.85), height: 1.55),
          ),
        ],
      ),
    );
  }
}
