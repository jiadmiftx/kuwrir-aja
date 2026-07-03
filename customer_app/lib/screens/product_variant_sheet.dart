import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// What the customer picked, handed back to the caller when they confirm.
class VariantSelectionResult {
  final List<ProductVariant> selectedVariants;
  final int quantity;
  const VariantSelectionResult({required this.selectedVariants, required this.quantity});
}

/// Bottom sheet for customizing a product with variant groups before adding
/// it to the cart. Radio buttons for single-select groups (maxSelect == 1),
/// checkboxes capped at maxSelect otherwise. The confirm button stays
/// disabled until every group with minSelect > 0 has enough selections.
class VariantSelectionSheet extends StatefulWidget {
  final Product product;
  const VariantSelectionSheet({super.key, required this.product});

  @override
  State<VariantSelectionSheet> createState() => _VariantSelectionSheetState();
}

class _VariantSelectionSheetState extends State<VariantSelectionSheet> {
  final Map<String, Set<String>> _selectedByGroup = {};
  int _quantity = 1;

  Map<String, List<ProductVariant>> get _groups {
    final map = <String, List<ProductVariant>>{};
    for (final v in widget.product.variants) {
      map.putIfAbsent(v.groupName, () => []).add(v);
    }
    return map;
  }

  bool get _isValid {
    for (final entry in _groups.entries) {
      final rule = entry.value.first;
      final count = _selectedByGroup[entry.key]?.length ?? 0;
      if (count < rule.minSelect) return false;
    }
    return true;
  }

  double get _unitPrice {
    final base = widget.product.discountPrice ?? widget.product.price;
    final variantsSum = _groups.values.expand((g) => g).where((v) {
      return _selectedByGroup[v.groupName]?.contains(v.id) ?? false;
    }).fold(0.0, (sum, v) => sum + v.price);
    return base + variantsSum;
  }

  void _toggle(ProductVariant v) {
    setState(() {
      final selected = _selectedByGroup.putIfAbsent(v.groupName, () => {});
      final rule = _groups[v.groupName]!.first;
      if (rule.maxSelect <= 1) {
        // Single-select: replace whatever was picked in this group.
        selected
          ..clear()
          ..add(v.id);
        return;
      }
      if (selected.contains(v.id)) {
        selected.remove(v.id);
      } else if (selected.length < rule.maxSelect) {
        selected.add(v.id);
      }
    });
  }

  String _formatIdr(double price) => price
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(widget.product.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                if (widget.product.description != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.product.description!, style: TextStyle(color: KuwrirColors.textSecondary)),
                ],
                const SizedBox(height: 16),
                for (final entry in groups.entries) _VariantGroupSection(
                  groupName: entry.key,
                  options: entry.value,
                  selectedIds: _selectedByGroup[entry.key] ?? const {},
                  onToggle: _toggle,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  _QtyStepper(
                    quantity: _quantity,
                    onChanged: (q) => setState(() => _quantity = q),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KuwrirColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isValid
                          ? () {
                              final selected = groups.values
                                  .expand((g) => g)
                                  .where((v) => _selectedByGroup[v.groupName]?.contains(v.id) ?? false)
                                  .toList();
                              Navigator.pop(
                                context,
                                VariantSelectionResult(selectedVariants: selected, quantity: _quantity),
                              );
                            }
                          : null,
                      child: Text('Tambah — IDR ${_formatIdr(_unitPrice * _quantity)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantGroupSection extends StatelessWidget {
  final String groupName;
  final List<ProductVariant> options;
  final Set<String> selectedIds;
  final ValueChanged<ProductVariant> onToggle;

  const _VariantGroupSection({
    required this.groupName,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rule = options.first;
    final hint = rule.maxSelect <= 1
        ? (rule.minSelect > 0 ? 'Wajib pilih 1' : 'Pilih 1 (opsional)')
        : 'Pilih ${rule.minSelect > 0 ? '${rule.minSelect}-' : 'hingga '}${rule.maxSelect}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(groupName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(hint, style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
            ],
          ),
          for (final o in options)
            InkWell(
              onTap: () => onToggle(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    rule.maxSelect <= 1
                        ? Radio<String>(
                            value: o.id,
                            groupValue: selectedIds.isEmpty ? null : selectedIds.first,
                            onChanged: (_) => onToggle(o),
                            activeColor: KuwrirColors.primary,
                          )
                        : Checkbox(
                            value: selectedIds.contains(o.id),
                            onChanged: (_) => onToggle(o),
                            activeColor: KuwrirColors.primary,
                          ),
                    Expanded(child: Text(o.name, style: const TextStyle(fontSize: 14))),
                    if (o.price > 0)
                      Text('+IDR ${o.price.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: KuwrirColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}
