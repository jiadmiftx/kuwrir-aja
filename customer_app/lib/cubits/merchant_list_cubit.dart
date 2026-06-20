import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class MerchantListState {}

class MerchantListInitial extends MerchantListState {}

class MerchantListLoading extends MerchantListState {}

class MerchantListLoaded extends MerchantListState {
  final List<Merchant> merchants;
  MerchantListLoaded(this.merchants);
}

class MerchantListError extends MerchantListState {
  final String message;
  MerchantListError(this.message);
}

class MerchantListCubit extends Cubit<MerchantListState> {
  final ApiClient _api;

  MerchantListCubit(this._api) : super(MerchantListInitial());

  Future<void> loadMerchants({String? category}) async {
    emit(MerchantListLoading());
    try {
      final merchants = await _api.getMerchants(category: category);
      emit(MerchantListLoaded(merchants));
    } on ApiException catch (e) {
      emit(MerchantListError(e.message));
    } catch (e) {
      emit(MerchantListError('Gagal memuat daftar restoran'));
    }
  }
}
