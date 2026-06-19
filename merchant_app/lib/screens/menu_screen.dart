import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Mock data for menu display
class _MockCategory {
  final String name;
  final List<_MockItem> items;
  _MockCategory({required this.name, required this.items});
}

class _MockItem {
  final String name;
  final double price;
  final bool isAvailable;
  _MockItem({required this.name, required this.price, this.isAvailable = true});
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final List<_MockCategory> _categories = [
    _MockCategory(
      name: 'Makanan Utama',
      items: [
        _MockItem(name: 'Nasi Campur Spesial', price: 50000),
        _MockItem(name: 'Ayam Bakar Taliwang', price: 40000),
        _MockItem(name: 'Plecing Kangkung', price: 15000),
        _MockItem(name: 'Nasi Goreng Lombok', price: 35000, isAvailable: false),
      ],
    ),
    _MockCategory(
      name: 'Minuman',
      items: [
        _MockItem(name: 'Es Kelapa Muda', price: 15000),
        _MockItem(name: 'Jus Mangga', price: 13000),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product & Inventory Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your product categories and items',
              style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, catIndex) {
                  final cat = _categories[catIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _showEditCategoryDialog(cat.name),
                                color: KuwrirColors.textSecondary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                onPressed: () => _showAddItemDialog(cat.name),
                                color: KuwrirColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Items
                      ...cat.items.map((item) => _ProductTile(
                            name: item.name,
                            price: item.price,
                            isAvailable: item.isAvailable,
                            onToggle: () {
                              setState(() {
                                // Toggle availability (mock)
                              });
                            },
                          )),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: KuwrirColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Snacks, Dessert',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _categories.add(_MockCategory(name: controller.text, items: []));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Save')),
        ],
      ),
    );
  }

  void _showAddItemDialog(String categoryName) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Item to $categoryName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Base Price (IDR)',
                hintText: 'e.g., 50000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  final cat = _categories.firstWhere((c) => c.name == categoryName);
                  cat.items.add(_MockItem(
                    name: nameCtrl.text,
                    price: double.tryParse(priceCtrl.text) ?? 0,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final String name;
  final double price;
  final bool isAvailable;
  final VoidCallback onToggle;

  const _ProductTile({
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: KuwrirColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.shopping_bag, color: KuwrirColors.primary, size: 22),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: isAvailable ? null : TextDecoration.lineThrough,
            color: isAvailable ? null : KuwrirColors.textHint,
          ),
        ),
        subtitle: Text(
          'IDR ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
          style: TextStyle(
            fontSize: 13,
            color: isAvailable ? KuwrirColors.primary : KuwrirColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Switch.adaptive(
          value: isAvailable,
          onChanged: (_) => onToggle(),
          activeColor: KuwrirColors.success,
        ),
      ),
    );
  }
}
