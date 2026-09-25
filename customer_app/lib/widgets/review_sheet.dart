import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Post-delivery rating sheet — one combined submission covering the
/// merchant/product quality and the driver (per the backend's Review
/// schema, one row per order, not per line item). The driver picker is
/// omitted entirely when the order never had a driver assigned.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String orderId,
  required bool hasDriver,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewSheet(orderId: orderId, hasDriver: hasDriver),
  ).then((v) => v ?? false);
}

class _ReviewSheet extends StatefulWidget {
  final String orderId;
  final bool hasDriver;
  const _ReviewSheet({required this.orderId, required this.hasDriver});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _merchantRating = 0;
  int _driverRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_merchantRating == 0 && _driverRating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beri rating minimal satu')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().submitOrderReview(
        widget.orderId,
        merchantRating: _merchantRating > 0 ? _merchantRating : null,
        driverRating: widget.hasDriver && _driverRating > 0
            ? _driverRating
            : null,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim rating, coba lagi')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: KuwrirColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: KuwrirColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Beri Rating Pesanan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _StarPickerRow(
              label: 'Rating Toko & Produk',
              value: _merchantRating,
              onChanged: (v) => setState(() => _merchantRating = v),
            ),
            if (widget.hasDriver) ...[
              const SizedBox(height: 18),
              _StarPickerRow(
                label: 'Rating Driver',
                value: _driverRating,
                onChanged: (v) => setState(() => _driverRating = v),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tulis komentar (opsional)',
                filled: true,
                fillColor: KuwrirColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kirim Rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPickerRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _StarPickerRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KuwrirColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (i) {
            final filled = i < value;
            return GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: HugeIcon(
                  icon: filled
                      ? HugeIcons.strokeRoundedStar
                      : HugeIcons.strokeRoundedStar,
                  color: filled ? KuwrirColors.warning : KuwrirColors.border,
                  size: 32,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
