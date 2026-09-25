import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class CustomerWalletState {}

class CustomerWalletLoading extends CustomerWalletState {}

class CustomerWalletLoaded extends CustomerWalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;
  CustomerWalletLoaded(this.wallet, this.transactions);
}

class CustomerWalletError extends CustomerWalletState {
  final String message;
  CustomerWalletError(this.message);
}

class CustomerWalletCubit extends Cubit<CustomerWalletState> {
  final ApiClient _api;
  Map<String, dynamic>? bankAccount;

  CustomerWalletCubit(this._api) : super(CustomerWalletLoading());

  Future<void> load() async {
    emit(CustomerWalletLoading());
    try {
      final wallet = await _api.getCustomerWallet();
      final transactions = await _api.getCustomerWalletTransactions();
      bankAccount = await _api.getBankAccount();
      emit(CustomerWalletLoaded(wallet, transactions));
    } on ApiException catch (e) {
      emit(CustomerWalletError(e.message));
    } catch (_) {
      emit(CustomerWalletError('Gagal memuat saldo'));
    }
  }

  Future<void> saveBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    bankAccount = await _api.saveBankAccount(
      bankCode: bankCode,
      accountNumber: accountNumber,
      accountName: accountName,
    );
    final current = state;
    if (current is CustomerWalletLoaded) emit(CustomerWalletLoaded(current.wallet, current.transactions));
  }

  /// Throws ApiException on failure so the calling form can show the exact
  /// backend error inline.
  Future<void> withdraw({
    required double amount,
    required String bankCode,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    await _api.withdrawCustomer(
      amount: amount,
      bankCode: bankCode,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
    await load();
  }

  /// Returns the Duitku payment_url to open — the wallet only updates once
  /// the customer finishes paying and Duitku's webhook lands, so the
  /// caller should refresh (load()) when the user returns to the app.
  Future<String> topup({required double amount, required String paymentMethod}) async {
    final resp = await _api.topupCustomerWallet(amount: amount, paymentMethod: paymentMethod);
    return resp['payment_url'] as String;
  }
}
