import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class MerchantDetailState {}

class MerchantDetailInitial extends MerchantDetailState {}

class MerchantDetailLoading extends MerchantDetailState {}

class MerchantDetailLoaded extends MerchantDetailState {
  final Merchant merchant;
  final List<ProductCategory> categories;
  MerchantDetailLoaded(this.merchant, this.categories);
}

class MerchantDetailError extends MerchantDetailState {
  final String message;
  MerchantDetailError(this.message);
}

class MerchantDetailCubit extends Cubit<MerchantDetailState> {
  final ApiClient _api;

  MerchantDetailCubit(this._api) : super(MerchantDetailInitial());

  Future<void> load(String merchantId) async {
    emit(MerchantDetailLoading());
    try {
      final merchant = await _api.getMerchant(merchantId);
      final categories = await _api.getMerchantMenu(merchantId);
      emit(MerchantDetailLoaded(merchant, categories));
    } on ApiException catch (e) {
      emit(MerchantDetailError(e.message));
    } catch (e) {
      emit(MerchantDetailError('Gagal memuat menu restoran'));
    }
  }
}
