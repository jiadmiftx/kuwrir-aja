import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/wallet_cubit.dart';

const _bankCodes = ['BCA', 'BNI', 'BRI', 'MANDIRI', 'CIMB', 'PERMATA'];

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DriverWalletCubit>().load();
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Future<void> _openBankAccountSheet(Map<String, dynamic>? existing) async {
    final numberCtrl = TextEditingController(text: existing?['account_number'] as String? ?? '');
    final nameCtrl = TextEditingController(text: existing?['account_name'] as String? ?? '');
    String bankCode = (existing?['bank_code'] as String?) ?? _bankCodes.first;
    String? error;
    bool submitting = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rekening Bank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: bankCode,
                decoration: const InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
                items: _bankCodes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setSheetState(() => bankCode = v ?? bankCode),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor Rekening', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening', border: OutlineInputBorder()),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: KuwrirColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (numberCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                            setSheetState(() => error = 'Lengkapi data rekening');
                            return;
                          }
                          setSheetState(() {
                            submitting = true;
                            error = null;
                          });
                          try {
                            await context.read<DriverWalletCubit>().saveBankAccount(
                                  bankCode: bankCode,
                                  accountNumber: numberCtrl.text.trim(),
                                  accountName: nameCtrl.text.trim(),
                                );
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          } catch (e) {
                            setSheetState(() {
                              submitting = false;
                              error = e is ApiException ? e.message : '$e';
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWithdrawSheet(double balance) async {
    final saved = context.read<DriverWalletCubit>().bankAccount;
    final amountCtrl = TextEditingController();
    final accountNumberCtrl = TextEditingController(text: saved?['account_number'] as String? ?? '');
    final accountNameCtrl = TextEditingController(text: saved?['account_name'] as String? ?? '');
    String bankCode = (saved?['bank_code'] as String?) ?? _bankCodes.first;
    String? error;
    bool submitting = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tarik Dana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Saldo tersedia: Rp ${_fmt(balance)}', style: TextStyle(color: KuwrirColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah (Rp)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: bankCode,
                decoration: const InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
                items: _bankCodes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setSheetState(() => bankCode = v ?? bankCode),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor Rekening', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Pemilik Rekening', border: OutlineInputBorder()),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: KuwrirColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amount <= 0) {
                            setSheetState(() => error = 'Jumlah tidak valid');
                            return;
                          }
                          if (amount > balance) {
                            setSheetState(() => error = 'Jumlah melebihi saldo tersedia');
                            return;
                          }
                          if (accountNumberCtrl.text.trim().isEmpty || accountNameCtrl.text.trim().isEmpty) {
                            setSheetState(() => error = 'Lengkapi data rekening');
                            return;
                          }
                          setSheetState(() {
                            submitting = true;
                            error = null;
                          });
                          try {
                            await context.read<DriverWalletCubit>().withdraw(
                                  amount: amount,
                                  bankCode: bankCode,
                                  bankAccountNumber: accountNumberCtrl.text.trim(),
                                  bankAccountName: accountNameCtrl.text.trim(),
                                );
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          } catch (e) {
                            setSheetState(() {
                              submitting = false;
                              error = e is ApiException ? e.message : '$e';
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Tarik Dana'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDepositSheet(double codHolding) async {
    final amountCtrl = TextEditingController(text: codHolding.toStringAsFixed(0));
    final referenceCtrl = TextEditingController();
    String method = 'cash';
    String? error;
    bool submitting = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Setor Cash COD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Cash dipegang: Rp ${_fmt(codHolding)}', style: TextStyle(color: KuwrirColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah Setoran (Rp)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Metode', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Transfer Bank')),
                ],
                onChanged: (v) => setSheetState(() => method = v ?? method),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceCtrl,
                decoration: const InputDecoration(labelText: 'Nomor Referensi (opsional)', border: OutlineInputBorder()),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: KuwrirColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amount <= 0 || amount > codHolding) {
                            setSheetState(() => error = 'Jumlah tidak valid');
                            return;
                          }
                          setSheetState(() {
                            submitting = true;
                            error = null;
                          });
                          try {
                            await context.read<DriverWalletCubit>().depositCOD(
                                  amount: amount,
                                  method: method,
                                  reference: referenceCtrl.text.trim(),
                                );
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          } catch (e) {
                            setSheetState(() {
                              submitting = false;
                              error = e is ApiException ? e.message : '$e';
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Setor Sekarang'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverWalletCubit, DriverWalletState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          appBar: AppBar(title: const Text('Wallet & Earnings')),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DriverWalletState state) {
    if (state is DriverWalletLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is DriverWalletError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<DriverWalletCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final s = state as DriverWalletLoaded;
    return RefreshIndicator(
      onRefresh: () => context.read<DriverWalletCubit>().load(),
      color: KuwrirColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: KuwrirColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo Tersedia', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Rp ${_fmt(s.wallet.balance)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Pendapatan', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text('Rp ${_fmt(s.wallet.totalEarned)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Ditarik', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text('Rp ${_fmt(s.wallet.totalWithdrawn)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: KuwrirColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: s.wallet.balance > 0 ? () => _openWithdrawSheet(s.wallet.balance) : null,
                    child: const Text('Tarik Dana'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KuwrirColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KuwrirColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rekening Bank', style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        context.read<DriverWalletCubit>().bankAccount != null
                            ? '${context.read<DriverWalletCubit>().bankAccount!['bank_code']} — ${context.read<DriverWalletCubit>().bankAccount!['account_number']}'
                            : 'Belum ada rekening tersimpan',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openBankAccountSheet(context.read<DriverWalletCubit>().bankAccount),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KuwrirColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.money_off_outlined, color: KuwrirColors.error, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Text('Cash to Deposit',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Kamu sudah mengumpulkan uang cash dari pesanan COD. Uang ini milik Cocourir dan merchant, dan wajib disetorkan.',
                  style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'Rp ${_fmt(s.codHolding)}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: KuwrirColors.error),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: KuwrirColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: s.codHolding > 0 ? () => _openDepositSheet(s.codHolding) : null,
                    child: const Text('Deposit Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('RIWAYAT TRANSAKSI',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: KuwrirColors.textHint)),
          const SizedBox(height: 10),
          if (s.transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Belum ada transaksi', style: TextStyle(color: KuwrirColors.textSecondary)),
            )
          else
            for (final tx in s.transactions) _TransactionTile(tx: tx, fmt: _fmt),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  final String Function(double) fmt;
  const _TransactionTile({required this.tx, required this.fmt});

  String _categoryLabel(String category) {
    switch (category) {
      case 'order_earning':
        return 'Pendapatan Pesanan';
      case 'withdrawal':
        return 'Penarikan Dana';
      case 'refund':
        return 'Refund';
      case 'adjustment':
        return 'Penyesuaian';
      case 'cod_deposit':
        return 'Setoran COD';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == 'credit';
    final tint = isCredit ? KuwrirColors.success : KuwrirColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: tint, size: 18),
        ),
        title: Text(_categoryLabel(tx.category), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 12, color: KuwrirColors.textSecondary),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}Rp ${fmt(tx.amount)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: tint),
        ),
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  final Widget child;
  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KuwrirColors.border),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
