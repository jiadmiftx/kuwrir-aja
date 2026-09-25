import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Result of [showReasonDialog] — `category` matches the backend's
/// ReasonCategory* consts (model.go), `reason` is the free-text note
/// (required when category is "lainnya", optional otherwise).
class ReasonResult {
  final String category;
  final String reason;
  const ReasonResult({required this.category, required this.reason});
}

const _reasonCategories = {
  'stok_habis': 'Stok habis',
  'toko_tutup': 'Toko tutup',
  'item_tidak_tersedia': 'Item tidak tersedia',
  'lainnya': 'Lainnya',
};

/// Human-readable label for a category value — used to combine
/// [ReasonResult] into the single free-text `reason` string the backend's
/// reject/cancel endpoints take (they don't store category separately).
String reasonCategoryLabel(String category) =>
    _reasonCategories[category] ?? category;

/// Shared reason-category picker used by both the pre-accept reject dialog
/// and the post-accept cancel/item-change-request dialogs — one place so
/// the categories (and their backend-matching values) can't drift between
/// the two flows.
Future<ReasonResult?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  Color confirmColor = KuwrirColors.error,
}) {
  return showDialog<ReasonResult>(
    context: context,
    builder: (ctx) => _ReasonDialog(
      title: title,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final Color confirmColor;
  const _ReasonDialog({
    required this.title,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  String _category = 'stok_habis';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsText = _category == 'lainnya';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasonCategories.entries.map((e) {
              final selected = _category == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => setState(() => _category = e.key),
                selectedColor: KuwrirColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected
                      ? KuwrirColors.primary
                      : KuwrirColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected ? KuwrirColors.primary : KuwrirColors.border,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: needsText,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: needsText
                  ? 'Jelaskan alasannya'
                  : 'Catatan tambahan (opsional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          onPressed: needsText && _ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  ReasonResult(category: _category, reason: _ctrl.text.trim()),
                ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
