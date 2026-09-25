import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class StoreState {}

class StoreLoading extends StoreState {}

class StoreLoaded extends StoreState {
  final Merchant merchant;
  final int todayOrders;
  final double todayRevenue;
  StoreLoaded(this.merchant, {this.todayOrders = 0, this.todayRevenue = 0});
}

class StoreError extends StoreState {
  final String message;
  StoreError(this.message);
}

class StoreCubit extends Cubit<StoreState> {
  final ApiClient _api;

  StoreCubit(this._api) : super(StoreLoading());

  Future<void> load() async {
    emit(StoreLoading());
    try {
      final merchant = await _api.getMyMerchant();
      final summary = await _api.getTodaySummary();
      emit(StoreLoaded(
        merchant,
        todayOrders: (summary['order_count'] as num?)?.toInt() ?? 0,
        todayRevenue: (summary['total_revenue'] as num?)?.toDouble() ?? 0,
      ));
    } on ApiException catch (e) {
      emit(StoreError(e.message));
    } catch (_) {
      emit(StoreError('Gagal memuat info toko'));
    }
  }

  Future<void> toggleOpen(bool open) async {
    await _api.toggleStoreOpen(open);
    await load();
  }
}
