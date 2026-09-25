import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/menu_cubit.dart';
import 'package:hugeicons/hugeicons.dart';

/// Lets a merchant create/manage variant groups (e.g. "Ukuran", "Topping")
/// and their options for a single product. Reads the live product from
/// MenuCubit so it stays in sync after each create/delete without needing
/// its own duplicate state.
class VariantManagerSheet extends StatefulWidget {
  final Product product;
  const VariantManagerSheet({super.key, required this.product});

  @override
  State<VariantManagerSheet> createState() => _VariantManagerSheetState();
}

class _VariantManagerSheetState extends State<VariantManagerSheet> {
  Product _currentProduct(MenuState state) {
    final categories = state is MenuLoaded
        ? state.categories
        : (state is MenuSaving ? state.categories : <ProductCategory>[]);
    for (final cat in categories) {
      for (final p in cat.products) {
        if (p.id == widget.product.id) return p;
      }
    }
    return widget.product;
  }

  Future<void> _addGroup(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final optionNameCtrl = TextEditingController();
    final optionPriceCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    final maxCtrl = TextEditingController(text: '1');

    final cubit = context.read<MenuCubit>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grup Topping/Varian Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Nama Grup', hintText: 'Level Pedas, Ukuran, Topping...'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min Pilih'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Maks Pilih'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: optionNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Opsi Pertama', hintText: 'Level Pedas Sedang, Ukuran Large, Extra Keju...'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: optionPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga Tambahan (IDR)', hintText: '0'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final groupName = nameCtrl.text.trim();
              final optionName = optionNameCtrl.text.trim();
              if (groupName.isEmpty || optionName.isEmpty) return;
              cubit.createVariant(widget.product.id, {
                'group_name': groupName,
                'name': optionName,
                'price': double.tryParse(optionPriceCtrl.text) ?? 0,
                'min_select': int.tryParse(minCtrl.text) ?? 0,
                'max_select': int.tryParse(maxCtrl.text) ?? 1,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOption(BuildContext context, String groupName, int minSelect, int maxSelect) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final cubit = context.read<MenuCubit>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Opsi ke $groupName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama Opsi'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga Tambahan (IDR)', hintText: '0'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              cubit.createVariant(widget.product.id, {
                'group_name': groupName,
                'name': name,
                'price': double.tryParse(priceCtrl.text) ?? 0,
                'min_select': minSelect,
                'max_select': maxSelect,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuCubit, MenuState>(
      builder: (context, state) {
        final product = _currentProduct(state);
        final groups = <String, List<ProductVariant>>{};
        for (final v in product.variants) {
          groups.putIfAbsent(v.groupName, () => []).add(v);
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: KuwrirColors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: KuwrirColors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Topping/Varian — ${product.name}',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: KuwrirColors.textPrimary)),
                    ),
                    IconButton(
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: KuwrirColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Belum ada topping atau pilihan tambahan. Tambahkan grup pertama, '
                      'mis. "Level Pedas", "Ukuran", atau "Topping".',
                      style: TextStyle(color: KuwrirColors.textSecondary),
                    ),
                  ),
                for (final entry in groups.entries)
                  _GroupCard(
                    groupName: entry.key,
                    options: entry.value,
                    onAddOption: () => _addOption(
                        context, entry.key, entry.value.first.minSelect, entry.value.first.maxSelect),
                    onDeleteOption: (id) => context.read<MenuCubit>().deleteVariant(id),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _addGroup(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KuwrirColors.primary,
                      side: BorderSide(color: KuwrirColors.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
                    label: const Text('Tambah Topping/Varian Baru',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String groupName;
  final List<ProductVariant> options;
  final VoidCallback onAddOption;
  final ValueChanged<String> onDeleteOption;

  const _GroupCard({
    required this.groupName,
    required this.options,
    required this.onAddOption,
    required this.onDeleteOption,
  });

  @override
  Widget build(BuildContext context) {
    final rule = options.first;
    final ruleLabel = rule.maxSelect <= 1
        ? (rule.minSelect > 0 ? 'Wajib pilih 1' : 'Pilih 1 (opsional)')
        : 'Pilih ${rule.minSelect}-${rule.maxSelect}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(groupName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5, color: KuwrirColors.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KuwrirColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(ruleLabel,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: KuwrirColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final o in options) ...[
              Divider(height: 1, color: KuwrirColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(o.name,
                          style: const TextStyle(fontSize: 13.5, color: KuwrirColors.textPrimary)),
                    ),
                    Text('+IDR ${o.price.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: KuwrirColors.primary)),
                    IconButton(
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 18, color: KuwrirColors.error),
                      onPressed: () => onDeleteOption(o.id),
                    ),
                  ],
                ),
              ),
            ],
            TextButton.icon(
              onPressed: onAddOption,
              style: TextButton.styleFrom(foregroundColor: KuwrirColors.primary),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 16),
              label: const Text('Tambah Opsi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
