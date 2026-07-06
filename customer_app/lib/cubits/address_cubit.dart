import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class AddressState {}

class AddressInitial extends AddressState {}

class AddressLoading extends AddressState {}

class AddressLoaded extends AddressState {
  final List<SavedAddress> addresses;
  AddressLoaded(this.addresses);
}

class AddressError extends AddressState {
  final String message;
  AddressError(this.message);
}

/// Drives the customer app's saved-addresses list ("Rumah", "Kantor", etc.)
/// — used both by the standalone Addresses screen and Cart's checkout
/// selector. Every mutation just re-fetches the list rather than patching
/// state locally, since default-address reassignment on the backend can
/// touch more than one row.
class AddressCubit extends Cubit<AddressState> {
  final ApiClient _api;

  AddressCubit(this._api) : super(AddressInitial());

  Future<void> load() async {
    emit(AddressLoading());
    try {
      final addresses = await _api.getAddresses();
      emit(AddressLoaded(addresses));
    } on ApiException catch (e) {
      emit(AddressError(e.message));
    } catch (_) {
      emit(AddressError('Gagal memuat alamat'));
    }
  }

  Future<void> add({
    required String label,
    required String address,
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    await _api.createAddress(label: label, address: address, lat: lat, lng: lng, isDefault: isDefault);
    await load();
  }

  Future<void> edit(
    String id, {
    required String label,
    required String address,
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    await _api.updateAddress(id, label: label, address: address, lat: lat, lng: lng, isDefault: isDefault);
    await load();
  }

  Future<void> remove(String id) async {
    await _api.deleteAddress(id);
    await load();
  }

  Future<void> setDefault(String id) async {
    await _api.setDefaultAddress(id);
    await load();
  }
}
