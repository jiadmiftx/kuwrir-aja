import 'package:flutter/material.dart';
import '../theme/kuwrir_colors.dart';

/// Shows a fully-rendered legal document (customer T&C / partnership
/// agreement, with the signer's own data already filled in by the backend)
/// and requires a checkbox before the caller-supplied [onAgree] action runs.
class AgreementReviewScreen extends StatefulWidget {
  final String title;
  final Future<String> Function() fetchContent;
  final Future<void> Function() onAgree;
  final String agreeButtonLabel;
  final String checkboxLabel;

  const AgreementReviewScreen({
    super.key,
    required this.title,
    required this.fetchContent,
    required this.onAgree,
    this.agreeButtonLabel = 'Saya Menyetujui & Lanjutkan',
    this.checkboxLabel = 'Saya sudah membaca dan menyetujui isi perjanjian ini',
  });

  @override
  State<AgreementReviewScreen> createState() => _AgreementReviewScreenState();
}

class _AgreementReviewScreenState extends State<AgreementReviewScreen> {
  late Future<String> _future;
  bool _checked = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchContent();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onAgree();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: KuwrirColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<String>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Gagal memuat dokumen: ${snapshot.error}',
                          style: TextStyle(color: KuwrirColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: KuwrirColors.border),
                      ),
                      child: SelectableText(
                        snapshot.data ?? '',
                        style: TextStyle(fontSize: 13.5, height: 1.5, color: KuwrirColors.textPrimary),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: KuwrirColors.background,
                border: Border(top: BorderSide(color: KuwrirColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _checked = !_checked),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _checked,
                            activeColor: KuwrirColors.primary,
                            onChanged: (v) => setState(() => _checked = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              widget.checkboxLabel,
                              style: TextStyle(fontSize: 13, color: KuwrirColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: KuwrirColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: (_checked && !_submitting) ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(widget.agreeButtonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
