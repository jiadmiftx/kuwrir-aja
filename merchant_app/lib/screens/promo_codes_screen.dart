import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Merchant's own promo codes — only ever discount this merchant's own
/// orders (backend enforces this via Promotion.MerchantID), separate from
/// admin's platform-wide promos.
class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final promos = await context.read<ApiClient>().getMyPromotions();
      if (!mounted) return;
      setState(() {
        _promos = promos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat promo';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PromoEditorDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> promo) async {
    try {
      await context.read<ApiClient>().toggleMyPromotion(promo['id'] as String);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Gagal mengubah status')),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kode promo?'),
        content: Text('Kode "${promo['code']}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KuwrirColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<ApiClient>().deleteMyPromotion(promo['id'] as String);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Gagal menghapus')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Kode Promo'),
        backgroundColor: KuwrirColors.background,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Buat Promo'),
        backgroundColor: KuwrirColors.primary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_promos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sell_outlined, size: 48, color: KuwrirColors.textHint),
              const SizedBox(height: 12),
              Text('Belum ada kode promo',
                  style: TextStyle(fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Buat kode promo buat menarik pelanggan ke tokomu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: KuwrirColors.textHint)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _promos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PromoCard(
          promo: _promos[i],
          onTap: () => _openEditor(existing: _promos[i]),
          onToggle: () => _toggle(_promos[i]),
          onDelete: () => _delete(_promos[i]),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PromoCard({
    required this.promo,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  String _valueLabel() {
    final type = promo['type'] as String? ?? '';
    final value = (promo['value'] as num?)?.toDouble() ?? 0;
    switch (type) {
      case 'percentage':
        return '${value.toStringAsFixed(0)}% off';
      case 'fixed':
        return 'Potongan Rp${value.toStringAsFixed(0)}';
      case 'free_delivery':
        return 'Gratis Ongkir';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = promo['is_active'] as bool? ?? true;
    final usedCount = promo['used_count'] as int? ?? 0;
    final usageLimit = promo['usage_limit'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(promo['code'] as String? ?? '',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KuwrirColors.textHint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Nonaktif',
                                style: TextStyle(fontSize: 10.5, color: KuwrirColors.textHint)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(promo['title'] as String? ?? '',
                        style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(_valueLabel(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KuwrirColors.primary)),
                    if (usageLimit > 0) ...[
                      const SizedBox(height: 4),
                      Text('Terpakai $usedCount / $usageLimit',
                          style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint)),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Switch.adaptive(value: isActive, onChanged: (_) => onToggle(), activeThumbColor: KuwrirColors.primary),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: KuwrirColors.error),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _PromoEditorDialog({this.existing});

  @override
  State<_PromoEditorDialog> createState() => _PromoEditorDialogState();
}

class _PromoEditorDialogState extends State<_PromoEditorDialog> {
  late final _codeCtrl = TextEditingController(text: widget.existing?['code'] as String? ?? '');
  late final _titleCtrl = TextEditingController(text: widget.existing?['title'] as String? ?? '');
  late final _valueCtrl = TextEditingController(
      text: ((widget.existing?['value'] as num?)?.toDouble() ?? 0) > 0
          ? (widget.existing!['value'] as num).toStringAsFixed(0)
          : '');
  late final _minOrderCtrl = TextEditingController(
      text: ((widget.existing?['min_order'] as num?)?.toDouble() ?? 0) > 0
          ? (widget.existing!['min_order'] as num).toStringAsFixed(0)
          : '');
  late final _maxDiscountCtrl = TextEditingController(
      text: ((widget.existing?['max_discount'] as num?)?.toDouble() ?? 0) > 0
          ? (widget.existing!['max_discount'] as num).toStringAsFixed(0)
          : '');
  late final _usageLimitCtrl = TextEditingController(
      text: ((widget.existing?['usage_limit'] as int?) ?? 0) > 0
          ? '${widget.existing!['usage_limit']}'
          : '');
  late String _type = widget.existing?['type'] as String? ?? 'percentage';
  late DateTime _startsAt = DateTime.tryParse(widget.existing?['starts_at'] as String? ?? '') ?? DateTime.now();
  late DateTime _expiresAt = DateTime.tryParse(widget.existing?['expires_at'] as String? ?? '') ??
      DateTime.now().add(const Duration(days: 30));
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _titleCtrl.dispose();
    _valueCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _usageLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startsAt : _expiresAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final title = _titleCtrl.text.trim();
    if (code.isEmpty || title.isEmpty) {
      setState(() => _error = 'Kode dan judul wajib diisi');
      return;
    }
    final value = double.tryParse(_valueCtrl.text.trim()) ?? 0;
    if (_type != 'free_delivery' && value <= 0) {
      setState(() => _error = 'Nilai promo wajib diisi');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final body = {
      'code': code,
      'title': title,
      'type': _type,
      'value': value,
      'min_order': double.tryParse(_minOrderCtrl.text.trim()) ?? 0,
      'max_discount': double.tryParse(_maxDiscountCtrl.text.trim()) ?? 0,
      'usage_limit': int.tryParse(_usageLimitCtrl.text.trim()) ?? 0,
      'starts_at': fmt(_startsAt),
      'expires_at': fmt(_expiresAt),
    };

    try {
      final api = context.read<ApiClient>();
      if (_isEdit) {
        await api.updateMyPromotion(widget.existing!['id'] as String, body);
      } else {
        await api.createMyPromotion(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal menyimpan promo';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Ubah Kode Promo' : 'Buat Kode Promo'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Kode (misal: HEMAT20)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul (misal: Diskon 20% Spesial)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipe Diskon'),
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('Persentase (%)')),
                  DropdownMenuItem(value: 'fixed', child: Text('Potongan Tetap (Rp)')),
                  DropdownMenuItem(value: 'free_delivery', child: Text('Gratis Ongkir')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'percentage'),
              ),
              if (_type != 'free_delivery') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _type == 'percentage' ? 'Nilai (%)' : 'Nilai (Rp)',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _minOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minimum belanja (Rp, opsional)'),
              ),
              if (_type == 'percentage') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _maxDiscountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maksimum potongan (Rp, opsional)'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _usageLimitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Batas pemakaian (opsional, 0 = tanpa batas)'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Mulai',
                      date: _startsAt,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DatePickerField(
                      label: 'Berakhir',
                      date: _expiresAt,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: KuwrirColors.error, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text('${date.day}/${date.month}/${date.year}'),
      ),
    );
  }
}
