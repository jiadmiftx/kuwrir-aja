import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

// Local cart item wraps the shared Product model
class _CartItem {
  final Product product;
  int qty = 1;
  double discount = 0;

  _CartItem({required this.product});

  double get subtotal => qty * product.price - discount;
  double get totalCost => qty * product.costPrice;
}

// ─── POS / Kasir Screen ───────────────────────────────────────────────────────

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  // Product data from API
  List<ProductCategory> _categories = [];
  bool _loading = true;
  String? _error;

  final List<_CartItem> _cart = [];
  String _selectedCategory = 'Semua';
  String _paymentMethod = 'cash';
  final _cashReceivedCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  double _orderDiscount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadMenu();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashReceivedCtrl.dispose();
    _customerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cats = await _api.getMyStoreMenu();
      setState(() { _categories = cats; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // All products flattened
  List<Product> get _allProducts =>
      _categories.expand((c) => c.products).toList();

  List<String> get _categoryNames {
    final names = _categories.map((c) => c.name).toList();
    return ['Semua', ...names];
  }

  List<Product> get _filteredProducts {
    final available = _allProducts.where((p) => p.isAvailable).toList();
    if (_selectedCategory == 'Semua') return available;
    final cat = _categories.firstWhere(
      (c) => c.name == _selectedCategory,
      orElse: () => const ProductCategory(id: '', merchantId: '', name: ''),
    );
    return cat.products.where((p) => p.isAvailable).toList();
  }

  double get _subtotal => _cart.fold(0, (s, i) => s + i.subtotal);
  double get _grandTotal => (_subtotal - _orderDiscount).clamp(0, double.infinity);
  double get _totalCost => _cart.fold(0, (s, i) => s + i.totalCost);
  double get _grossProfit => _grandTotal - _totalCost;
  double get _cashChange {
    final received = double.tryParse(_cashReceivedCtrl.text.replaceAll('.', '')) ?? 0;
    return (received - _grandTotal).clamp(0, double.infinity);
  }

  void _addToCart(Product p) {
    if (p.trackStock && p.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${p.name} habis'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      final idx = _cart.indexWhere((i) => i.product.id == p.id);
      if (idx >= 0) {
        if (p.trackStock && _cart[idx].qty >= p.stockQuantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stok ${p.name} hanya ${p.stockQuantity}'), backgroundColor: Colors.orange),
          );
          return;
        }
        _cart[idx].qty++;
      } else {
        _cart.add(_CartItem(product: p));
      }
    });
  }

  void _removeFromCart(int index) => setState(() => _cart.removeAt(index));

  void _updateQty(int index, int delta) {
    setState(() {
      _cart[index].qty = (_cart[index].qty + delta).clamp(1, 999);
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _orderDiscount = 0;
      _cashReceivedCtrl.clear();
      _customerNameCtrl.clear();
      _paymentMethod = 'cash';
    });
  }

  Future<void> _processPayment() async {
    if (_cart.isEmpty) return;

    if (_paymentMethod == 'tab' && _customerNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama pelanggan wajib diisi untuk Tab'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Subtotal', _subtotal),
            if (_orderDiscount > 0) _summaryRow('Diskon', -_orderDiscount, color: Colors.green),
            const Divider(),
            _summaryRow('Total', _grandTotal, bold: true),
            if (_totalCost > 0) ...[
              _summaryRow('HPP', _totalCost, color: Colors.grey),
              _summaryRow('Laba Kotor', _grossProfit, color: KuwrirColors.primary),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.payment, size: 16),
              const SizedBox(width: 4),
              Text(_paymentMethod.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (_paymentMethod == 'cash') ...[
              const SizedBox(height: 4),
              _summaryRow('Kembalian', _cashChange, color: Colors.blue),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proses')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final txNumber = 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _clearCart();
    _showReceipt(txNumber);
  }

  void _showReceipt(String txNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Transaksi Berhasil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(txNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Struk telah disimpan'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.print),
            label: const Text('Cetak Struk'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false, Color? color}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_fmt(amount), style: style),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final abs = v.abs();
    final s = abs.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.',
    );
    return v < 0 ? '-Rp $s' : 'Rp $s';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir / POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang produk',
            onPressed: _loadMenu,
          ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Kosongkan keranjang',
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Kosongkan Keranjang?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    FilledButton(onPressed: () { Navigator.pop(ctx); _clearCart(); }, child: const Text('Kosongkan')),
                  ],
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Produk', icon: Icon(Icons.grid_view)),
            Tab(
              text: 'Keranjang',
              icon: _cart.isNotEmpty
                  ? Badge(label: Text('${_cart.length}'), child: const Icon(Icons.shopping_cart))
                  : const Icon(Icons.shopping_cart),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductGrid(),
          _buildCart(),
        ],
      ),
      floatingActionButton: _cart.isNotEmpty && _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.shopping_cart),
              label: Text('${_cart.length} item · ${_fmt(_grandTotal)}'),
              backgroundColor: KuwrirColors.primary,
            )
          : null,
    );
  }

  // ─── Product Grid ─────────────────────────────────────────────────────────

  Widget _buildProductGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('Gagal memuat produk', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadMenu,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_allProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Belum ada produk', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Tambahkan produk di menu "Menu" terlebih dahulu',
                style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadMenu,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _categoryNames.length,
            itemBuilder: (_, i) {
              final cat = _categoryNames[i];
              final selected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),

        // Product grid
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Text('Tidak ada produk di kategori "$_selectedCategory"',
                      style: const TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (_, i) => _buildProductCard(_filteredProducts[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product p) {
    final inCart = _cart.where((i) => i.product.id == p.id).fold(0, (s, i) => s + i.qty);
    final lowStock = p.trackStock && p.stockQuantity <= 3 && p.stockQuantity > 0;
    final noStock = p.trackStock && p.stockQuantity <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: noStock ? null : () => _addToCart(p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (inCart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: KuwrirColors.primary,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$inCart',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const Spacer(),
              Text(_fmt(p.price),
                  style: TextStyle(
                      color: noStock ? Colors.grey : KuwrirColors.primary,
                      fontWeight: FontWeight.bold)),
              if (p.trackStock)
                Text(
                  noStock
                      ? 'Habis'
                      : (lowStock ? 'Sisa: ${p.stockQuantity}' : 'Stok: ${p.stockQuantity}'),
                  style: TextStyle(
                      fontSize: 11,
                      color: noStock
                          ? Colors.red
                          : (lowStock ? Colors.orange : Colors.grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Cart ─────────────────────────────────────────────────────────────────

  Widget _buildCart() {
    if (_cart.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Keranjang kosong', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('Tap produk untuk menambahkan', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _cart.length,
            itemBuilder: (_, i) => _buildCartItem(i),
          ),
        ),
        _buildPaymentPanel(),
      ],
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cart[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(_fmt(item.subtotal),
                    style: TextStyle(fontWeight: FontWeight.bold, color: KuwrirColors.primary)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeFromCart(index),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${_fmt(item.product.price)} × ',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _updateQty(index, -1),
                ),
                Text('${item.qty}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _updateQty(index, 1),
                ),
                if (item.product.costPrice > 0) ...[
                  const Spacer(),
                  Text('HPP: ${_fmt(item.totalCost)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 8, offset: const Offset(0, -2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Diskon Order', style: TextStyle(color: Colors.grey)),
              GestureDetector(
                onTap: _showDiscountDialog,
                child: Text(
                  _orderDiscount > 0 ? '-${_fmt(_orderDiscount)}' : 'Tambah',
                  style: TextStyle(color: KuwrirColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_fmt(_grandTotal),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: KuwrirColors.primary)),
            ],
          ),
          if (_totalCost > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('HPP: ${_fmt(_totalCost)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Laba: ${_fmt(_grossProfit)}',
                    style: TextStyle(
                        fontSize: 11, color: _grossProfit >= 0 ? Colors.green : Colors.red)),
              ],
            ),
          const SizedBox(height: 12),

          const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildPaymentMethodSelector(),
          const SizedBox(height: 12),

          if (_paymentMethod == 'tab') ...[
            TextField(
              controller: _customerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Pelanggan *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_paymentMethod == 'cash') ...[
            TextField(
              controller: _cashReceivedCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Uang Diterima',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.money),
                isDense: true,
                suffixText: _cashChange > 0 ? 'Kembalian: ${_fmt(_cashChange)}' : null,
                suffixStyle: const TextStyle(color: Colors.blue),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _processPayment,
              icon: const Icon(Icons.check_circle),
              label: Text(
                _paymentMethod == 'tab'
                    ? 'Catat Tab (${_fmt(_grandTotal)})'
                    : 'Bayar ${_fmt(_grandTotal)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    const methods = [
      ('cash', Icons.money, 'Cash'),
      ('qris', Icons.qr_code, 'QRIS'),
      ('card', Icons.credit_card, 'Kartu'),
      ('tab', Icons.person_add, 'Tab'),
    ];
    return Row(
      children: methods.map((m) {
        final selected = _paymentMethod == m.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _paymentMethod = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? KuwrirColors.primary : Colors.grey.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected ? KuwrirColors.primary : Colors.transparent),
                ),
                child: Column(
                  children: [
                    Icon(m.$2, size: 20, color: selected ? Colors.white : Colors.grey),
                    Text(m.$3,
                        style: TextStyle(
                            fontSize: 11, color: selected ? Colors.white : Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showDiscountDialog() {
    final ctrl = TextEditingController(
        text: _orderDiscount > 0 ? _orderDiscount.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diskon Order'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Jumlah Diskon (Rp)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.discount),
          ),
        ),
        actions: [
          if (_orderDiscount > 0)
            TextButton(
              onPressed: () {
                setState(() => _orderDiscount = 0);
                Navigator.pop(ctx);
              },
              child: const Text('Hapus Diskon', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text) ?? 0;
              setState(() => _orderDiscount = v.clamp(0, _subtotal));
              Navigator.pop(ctx);
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }
}
