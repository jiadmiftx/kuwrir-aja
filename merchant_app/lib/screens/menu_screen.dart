import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/menu_cubit.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MenuCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuCubit, MenuState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Menu Saya'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<MenuCubit>().load(),
              ),
            ],
          ),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state is MenuLoading ? null : () => _showAddCategoryDialog(context),
            backgroundColor: KuwrirColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kategori'),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, MenuState state) {
    if (state is MenuLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is MenuError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<MenuCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final categories = state is MenuLoaded
        ? state.categories
        : (state is MenuSaving ? state.categories : <ProductCategory>[]);

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Belum ada menu', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Tambah kategori dan produk pertama Anda',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final cat = categories[i];
            return _CategorySection(category: cat);
          },
        ),
        if (state is MenuSaving)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori',
            hintText: 'cth. Makanan Utama, Minuman',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<MenuCubit>().createCategory(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ProductCategory category;
  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: KuwrirColors.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: KuwrirColors.primary,
                onPressed: () => _showAddProductDialog(context, category.id, category.name),
              ),
            ],
          ),
        ),
        if (category.products.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Belum ada produk',
                style: TextStyle(color: KuwrirColors.textHint, fontSize: 13)),
          )
        else
          for (final product in category.products)
            _ProductTile(product: product),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showAddProductDialog(BuildContext context, String catId, String catName) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah ke $catName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Dasar (IDR)',
                  hintText: '50000',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (name.isNotEmpty && price > 0) {
                context.read<MenuCubit>().createProduct(catId, {
                  'name': name,
                  'price': price,
                  'description': descCtrl.text.trim(),
                  'is_available': true,
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

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
          child: product.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.fastfood, color: KuwrirColors.primary)),
                )
              : Icon(Icons.fastfood, color: KuwrirColors.primary, size: 22),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: product.isAvailable ? null : TextDecoration.lineThrough,
            color: product.isAvailable ? null : KuwrirColors.textHint,
          ),
        ),
        subtitle: Text(
          'IDR ${_fmt(product.price)}',
          style: TextStyle(
            fontSize: 13,
            color: product.isAvailable ? KuwrirColors.primary : KuwrirColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: product.isAvailable,
              onChanged: (v) =>
                  context.read<MenuCubit>().toggleAvailability(product.id, v),
              activeColor: KuwrirColors.success,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    if (action == 'edit') {
      _showEditDialog(context);
    } else if (action == 'delete') {
      _showDeleteConfirm(context);
    }
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.price.toStringAsFixed(0));
    final descCtrl = TextEditingController(text: product.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Produk'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga (IDR)'),
              ),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              context.read<MenuCubit>().updateProduct(product.id, {
                'name': nameCtrl.text.trim(),
                'price': double.tryParse(priceCtrl.text) ?? product.price,
                'description': descCtrl.text.trim(),
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('${product.name} akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<MenuCubit>().deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}
