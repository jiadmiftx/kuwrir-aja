import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/menu_cubit.dart';
import 'variant_manager_sheet.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<MenuCubit>().load();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Rebuilds the TabController whenever the category count changes
  /// (category added/deleted) — Flutter's TabController has a fixed
  /// `length`, so it can't just be reused across a changing category list.
  void _syncTabController(int categoryCount) {
    if (_tabController != null && _tabController!.length == categoryCount)
      return;
    _tabController?.dispose();
    _tabController = categoryCount > 0
        ? TabController(length: categoryCount, vsync: this)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuCubit, MenuState>(
      builder: (context, state) {
        final categories = state is MenuLoaded
            ? state.categories
            : (state is MenuSaving ? state.categories : <ProductCategory>[]);
        _syncTabController(categories.length);

        return Scaffold(
          backgroundColor: KuwrirColors.background,
          appBar: AppBar(
            title: const Text('Menu Saya'),
            backgroundColor: KuwrirColors.background,
            bottom:
                (categories.isEmpty ||
                    _query.isNotEmpty ||
                    _tabController == null)
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(44),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: KuwrirColors.primary,
                      unselectedLabelColor: KuwrirColors.textSecondary,
                      indicatorColor: KuwrirColors.primary,
                      tabAlignment: TabAlignment.start,
                      tabs: [for (final c in categories) Tab(text: c.name)],
                    ),
                  ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search,
                      color: KuwrirColors.textHint,
                      size: 20,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: KuwrirColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KuwrirColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: KuwrirColors.border),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody(context, state, categories)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state is MenuLoading
                ? null
                : () => _showAddCategoryDialog(context),
            backgroundColor: KuwrirColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kategori'),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    MenuState state,
    List<ProductCategory> categories,
  ) {
    if (state is MenuLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is MenuError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.message,
              style: TextStyle(color: KuwrirColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<MenuCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 36,
                  color: KuwrirColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Belum ada menu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: KuwrirColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tambah kategori dan produk pertama Anda',
                style: TextStyle(
                  color: KuwrirColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget body;
    if (_query.isNotEmpty) {
      body = _SearchResults(categories: categories, query: _query);
    } else if (_tabController != null) {
      body = TabBarView(
        controller: _tabController,
        children: [
          for (final cat in categories) _CategoryProductsList(category: cat),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }

    return Stack(
      children: [
        body,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
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

/// One tab page's content — the category name itself now lives in the
/// TabBar above, so this only needs the add/delete-category actions plus
/// the product list.
class _CategoryProductsList extends StatelessWidget {
  final ProductCategory category;
  const _CategoryProductsList({required this.category});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('${category.name} akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KuwrirColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<MenuCubit>().deleteCategory(category.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Gagal menghapus kategori',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () =>
                  _showAddProductDialog(context, category.id, category.name),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Tambah Produk'),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: KuwrirColors.error,
              ),
              tooltip: 'Hapus Kategori',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        if (category.products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Belum ada produk di kategori ini',
                style: TextStyle(color: KuwrirColors.textHint, fontSize: 13),
              ),
            ),
          )
        else
          for (final product in category.products)
            _ProductTile(product: product),
      ],
    );
  }

  void _showAddProductDialog(
    BuildContext context,
    String catId,
    String catName,
  ) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final packagingFeeCtrl = TextEditingController();
    File? imageFile;
    bool trackStock = false;
    String? foodCategoryId;
    bool alwaysVisible = true;
    TimeOfDay? visibleFrom;
    TimeOfDay? visibleUntil;
    final cubit = context.read<MenuCubit>();
    final foodCategoriesFuture = ApiClient().getFoodCategories();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Tambah ke $catName'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProductImagePicker(
                    imageFile: imageFile,
                    onPick: (file) => setState(() => imageFile = file),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: skuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SKU (opsional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FoodCategoryDropdown(
                    future: foodCategoriesFuture,
                    value: foodCategoryId,
                    onChanged: (v) => setState(() => foodCategoryId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Diskon (opsional)',
                      hintText: 'Kosongkan jika tidak ada diskon',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: packagingFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Biaya Kemasan per Item (opsional)',
                      hintText: '0',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _VisibilityWindowField(
                    alwaysVisible: alwaysVisible,
                    from: visibleFrom,
                    until: visibleUntil,
                    onAlwaysVisibleChanged: (v) =>
                        setState(() => alwaysVisible = v),
                    onFromChanged: (v) => setState(() => visibleFrom = v),
                    onUntilChanged: (v) => setState(() => visibleUntil = v),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Lacak Stok',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: trackStock,
                    onChanged: (v) => setState(() => trackStock = v),
                  ),
                  if (trackStock)
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Stok',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0;
                final discount = double.tryParse(discountCtrl.text);
                if (discount != null && (discount <= 0 || discount >= price)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Harga diskon harus lebih besar dari 0 dan lebih kecil dari harga dasar',
                      ),
                    ),
                  );
                  return;
                }
                if (name.isNotEmpty && price > 0) {
                  cubit.createProduct(catId, {
                    'name': name,
                    'price': price,
                    'description': descCtrl.text.trim(),
                    'is_available': true,
                    'sku': skuCtrl.text.trim(),
                    'track_stock': trackStock,
                    'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                    'food_category_id': foodCategoryId,
                    'discount_price': discount,
                    'packaging_fee':
                        double.tryParse(packagingFeeCtrl.text) ?? 0,
                    'visible_from_minute': alwaysVisible
                        ? null
                        : _toMinute(visibleFrom),
                    'visible_until_minute': alwaysVisible
                        ? null
                        : _toMinute(visibleUntil),
                  }, image: imageFile);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat, cross-category product search — active whenever the search field
/// has text, replacing the category tabs entirely so results aren't
/// confined to whichever tab happens to be open.
class _SearchResults extends StatelessWidget {
  final List<ProductCategory> categories;
  final String query;
  const _SearchResults({required this.categories, required this.query});

  @override
  Widget build(BuildContext context) {
    final matches = <(ProductCategory, Product)>[
      for (final cat in categories)
        for (final p in cat.products)
          if (p.name.toLowerCase().contains(query)) (cat, p),
    ];

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 40, color: KuwrirColors.textHint),
              const SizedBox(height: 12),
              Text(
                'Tidak ada produk yang cocok dengan "$query"',
                style: TextStyle(
                  color: KuwrirColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final (cat, product) = matches[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: KuwrirColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _ProductTile(product: product),
            ],
          ),
        );
      },
    );
  }
}

int? _toMinute(TimeOfDay? t) => t == null ? null : t.hour * 60 + t.minute;

/// Optional platform-wide food category picker, shared by add/edit product
/// dialogs. Untagged products (no selection) simply won't surface under any
/// category filter on the customer app's Home screen.
class _FoodCategoryDropdown extends StatelessWidget {
  final Future<List<FoodCategory>> future;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FoodCategoryDropdown({
    required this.future,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoodCategory>>(
      future: future,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const [];
        if (snapshot.connectionState != ConnectionState.done ||
            categories.isEmpty) {
          return const SizedBox.shrink();
        }
        return DropdownButtonFormField<String?>(
          initialValue: value,
          decoration: const InputDecoration(
            labelText: 'Kategori Makanan (opsional)',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tanpa kategori'),
            ),
            ...categories.map(
              (c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text('${c.icon ?? ''} ${c.name}'.trim()),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

/// Tap-to-pick product photo, shared by add/edit product dialogs.
class _ProductImagePicker extends StatelessWidget {
  final File? imageFile;
  final String? existingUrl;
  final ValueChanged<File> onPick;

  const _ProductImagePicker({
    required this.imageFile,
    required this.onPick,
    this.existingUrl,
  });

  Future<void> _pick(BuildContext context) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    final xfile = await ImagePicker().pickImage(
      source: src,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (xfile == null) return;
    onPick(File(xfile.path));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: KuwrirColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: KuwrirColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  imageFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            : (existingUrl != null && existingUrl!.isNotEmpty)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  existingUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => _placeholder(),
                ),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_a_photo_outlined, color: KuwrirColors.primary),
          const SizedBox(height: 4),
          Text(
            'Upload Foto Produk',
            style: TextStyle(fontSize: 12, color: KuwrirColors.primary),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.fastfood, color: KuwrirColors.primary),
                  ),
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
            color: product.isAvailable
                ? KuwrirColors.primary
                : KuwrirColors.textHint,
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
              activeThumbColor: KuwrirColors.success,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'variants',
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 18),
                      SizedBox(width: 10),
                      Text('Kelola Topping/Varian'),
                    ],
                  ),
                ),
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
    } else if (action == 'variants') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => VariantManagerSheet(product: product),
      );
    } else if (action == 'delete') {
      _showDeleteConfirm(context);
    }
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(
      text: product.price.toStringAsFixed(0),
    );
    final descCtrl = TextEditingController(text: product.description ?? '');
    final skuCtrl = TextEditingController(text: product.sku ?? '');
    final stockCtrl = TextEditingController(
      text: product.stockQuantity.toString(),
    );
    final discountCtrl = TextEditingController(
      text: product.discountPrice?.toStringAsFixed(0) ?? '',
    );
    final packagingFeeCtrl = TextEditingController(
      text: product.packagingFee > 0
          ? product.packagingFee.toStringAsFixed(0)
          : '',
    );
    File? imageFile;
    bool trackStock = product.trackStock;
    String? foodCategoryId = product.foodCategoryId;
    bool alwaysVisible =
        product.visibleFromMinute == null && product.visibleUntilMinute == null;
    TimeOfDay? visibleFrom = _fromMinute(product.visibleFromMinute);
    TimeOfDay? visibleUntil = _fromMinute(product.visibleUntilMinute);
    final cubit = context.read<MenuCubit>();
    final foodCategoriesFuture = ApiClient().getFoodCategories();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Produk'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProductImagePicker(
                    imageFile: imageFile,
                    existingUrl: product.imageUrl,
                    onPick: (file) => setState(() => imageFile = file),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga (IDR)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Deskripsi'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: skuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SKU (opsional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FoodCategoryDropdown(
                    future: foodCategoriesFuture,
                    value: foodCategoryId,
                    onChanged: (v) => setState(() => foodCategoryId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Diskon (opsional)',
                      hintText: 'Kosongkan jika tidak ada diskon',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: packagingFeeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Biaya Kemasan per Item (opsional)',
                      hintText: '0',
                    ),
                  ),
                  const SizedBox(height: 4),
                  _VisibilityWindowField(
                    alwaysVisible: alwaysVisible,
                    from: visibleFrom,
                    until: visibleUntil,
                    onAlwaysVisibleChanged: (v) =>
                        setState(() => alwaysVisible = v),
                    onFromChanged: (v) => setState(() => visibleFrom = v),
                    onUntilChanged: (v) => setState(() => visibleUntil = v),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Lacak Stok',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: trackStock,
                    onChanged: (v) => setState(() => trackStock = v),
                  ),
                  if (trackStock)
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Stok',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceCtrl.text) ?? product.price;
                final discount = double.tryParse(discountCtrl.text);
                if (discount != null && (discount <= 0 || discount >= price)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Harga diskon harus lebih besar dari 0 dan lebih kecil dari harga dasar',
                      ),
                    ),
                  );
                  return;
                }
                cubit.updateProduct(product.id, {
                  'name': nameCtrl.text.trim(),
                  'price': price,
                  'description': descCtrl.text.trim(),
                  'sku': skuCtrl.text.trim(),
                  'track_stock': trackStock,
                  'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                  'food_category_id': foodCategoryId,
                  'discount_price': discount,
                  'packaging_fee': double.tryParse(packagingFeeCtrl.text) ?? 0,
                  'visible_from_minute': alwaysVisible
                      ? null
                      : _toMinute(visibleFrom),
                  'visible_until_minute': alwaysVisible
                      ? null
                      : _toMinute(visibleUntil),
                }, image: imageFile);
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KuwrirColors.error,
            ),
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

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

TimeOfDay? _fromMinute(int? minute) =>
    minute == null ? null : TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

/// Toggle + two time pickers controlling when a product shows up for
/// customers. Off (always visible) by default — matches every product
/// created before this feature existed.
class _VisibilityWindowField extends StatelessWidget {
  final bool alwaysVisible;
  final TimeOfDay? from;
  final TimeOfDay? until;
  final ValueChanged<bool> onAlwaysVisibleChanged;
  final ValueChanged<TimeOfDay?> onFromChanged;
  final ValueChanged<TimeOfDay?> onUntilChanged;

  const _VisibilityWindowField({
    required this.alwaysVisible,
    required this.from,
    required this.until,
    required this.onAlwaysVisibleChanged,
    required this.onFromChanged,
    required this.onUntilChanged,
  });

  Future<void> _pick(
    BuildContext context,
    TimeOfDay? initial,
    ValueChanged<TimeOfDay?> onChanged,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Selalu Tampil', style: TextStyle(fontSize: 14)),
          value: alwaysVisible,
          onChanged: onAlwaysVisibleChanged,
        ),
        if (!alwaysVisible)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(context, from, onFromChanged),
                  child: Text(from == null ? 'Mulai' : from!.format(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(context, until, onUntilChanged),
                  child: Text(
                    until == null ? 'Selesai' : until!.format(context),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
