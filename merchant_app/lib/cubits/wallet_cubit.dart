import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class MerchantWalletState {}

class MerchantWalletLoading extends MerchantWalletState {}

class MerchantWalletLoaded extends MerchantWalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;
  MerchantWalletLoaded(this.wallet, this.transactions);
}

class MerchantWalletError extends MerchantWalletState {
  final String message;
  MerchantWalletError(this.message);
}

class MerchantWalletCubit extends Cubit<MerchantWalletState> {
  final ApiClient _api;

  MerchantWalletCubit(this._api) : super(MerchantWalletLoading());

  Future<void> load() async {
    emit(MerchantWalletLoading());
    try {
      final wallet = await _api.getMerchantWallet();
      final transactions = await _api.getMerchantWalletTransactions();
      emit(MerchantWalletLoaded(wallet, transactions));
    } on ApiException catch (e) {
      emit(MerchantWalletError(e.message));
    } catch (_) {
      emit(MerchantWalletError('Gagal memuat saldo'));
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
    await _api.withdrawMerchant(
      amount: amount,
      bankCode: bankCode,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
    await load();
  }
}
