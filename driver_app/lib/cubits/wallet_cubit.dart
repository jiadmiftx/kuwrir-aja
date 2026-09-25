import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class DriverWalletState {}

class DriverWalletLoading extends DriverWalletState {}

class DriverWalletLoaded extends DriverWalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;
  final double codHolding;
  DriverWalletLoaded(this.wallet, this.transactions, this.codHolding);
}

class DriverWalletError extends DriverWalletState {
  final String message;
  DriverWalletError(this.message);
}

class DriverWalletCubit extends Cubit<DriverWalletState> {
  final ApiClient _api;
  Map<String, dynamic>? bankAccount;

  DriverWalletCubit(this._api) : super(DriverWalletLoading());

  Future<void> load() async {
    emit(DriverWalletLoading());
    try {
      final walletResp = await _api.getDriverWallet();
      final wallet = Wallet.fromJson(walletResp['wallet'] as Map<String, dynamic>);
      final codHolding = (walletResp['cod_holding'] as num?)?.toDouble() ?? 0.0;
      final transactions = await _api.getDriverWalletTransactions();
      bankAccount = await _api.getBankAccount();
      emit(DriverWalletLoaded(wallet, transactions, codHolding));
    } on ApiException catch (e) {
      emit(DriverWalletError(e.message));
    } catch (_) {
      emit(DriverWalletError('Gagal memuat saldo'));
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
    if (current is DriverWalletLoaded) {
      emit(DriverWalletLoaded(current.wallet, current.transactions, current.codHolding));
    }
  }

  /// Throws ApiException on failure so the calling form can show the exact
  /// backend error inline.
  Future<void> withdraw({
    required double amount,
    required String bankCode,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    await _api.withdrawDriver(
      amount: amount,
      bankCode: bankCode,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
    await load();
  }

  Future<void> depositCOD({
    required double amount,
    String method = 'cash',
    String reference = '',
  }) async {
    await _api.depositDriverCOD(amount: amount, method: method, reference: reference);
    await load();
  }
}
