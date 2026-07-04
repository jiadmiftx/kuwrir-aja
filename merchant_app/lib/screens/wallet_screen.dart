import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    context.read<MerchantWalletCubit>().load();
  }

  String _fmt(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Future<void> _openWithdrawSheet(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    final amountCtrl = TextEditingController();
    final accountNumberCtrl = TextEditingController(text: prefs.getString('wd_account_number'));
    final accountNameCtrl = TextEditingController(text: prefs.getString('wd_account_name'));
    String bankCode = prefs.getString('wd_bank_code') ?? _bankCodes.first;
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
                            await context.read<MerchantWalletCubit>().withdraw(
                                  amount: amount,
                                  bankCode: bankCode,
                                  bankAccountNumber: accountNumberCtrl.text.trim(),
                                  bankAccountName: accountNameCtrl.text.trim(),
                                );
                            await prefs.setString('wd_bank_code', bankCode);
                            await prefs.setString('wd_account_number', accountNumberCtrl.text.trim());
                            await prefs.setString('wd_account_name', accountNameCtrl.text.trim());
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantWalletCubit, MerchantWalletState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KuwrirColors.background,
          appBar: AppBar(
            title: const Text('Keuangan'),
            backgroundColor: KuwrirColors.background,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<MerchantWalletCubit>().load(),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, MerchantWalletState state) {
    if (state is MerchantWalletLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is MerchantWalletError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message, style: TextStyle(color: KuwrirColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<MerchantWalletCubit>().load(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final s = state as MerchantWalletLoaded;
    return RefreshIndicator(
      onRefresh: () => context.read<MerchantWalletCubit>().load(),
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
