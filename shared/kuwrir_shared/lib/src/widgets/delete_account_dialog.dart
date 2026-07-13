import 'package:flutter/material.dart';

import '../theme/kuwrir_colors.dart';

/// Shows the "type HAPUS to confirm" dialog every app's account-deletion
/// row should use — a single free-form "Yakin?" tap is too easy to hit by
/// accident for something this irreversible. Returns true only if the user
/// typed the confirmation word and pressed the delete button.
Future<bool?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => _DeleteAccountDialog(dialogContext: dialogContext),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  final BuildContext dialogContext;
  const _DeleteAccountDialog({required this.dialogContext});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _ctrl = TextEditingController();
  bool _canConfirm = false;

  static const _kConfirmWord = 'HAPUS';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final match = _ctrl.text.trim().toUpperCase() == _kConfirmWord;
      if (match != _canConfirm) setState(() => _canConfirm = match);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hapus Akun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akun, alamat tersimpan, dan akses login akan dihapus permanen dan tidak bisa dipulihkan. '
            'Riwayat transaksi tetap disimpan untuk keperluan pembukuan.',
          ),
          const SizedBox(height: 16),
          Text('Ketik "$_kConfirmWord" untuk konfirmasi',
              style: const TextStyle(fontSize: 12.5, color: KuwrirColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          child: const Text('Hapus Akun'),
        ),
      ],
    );
  }
}
