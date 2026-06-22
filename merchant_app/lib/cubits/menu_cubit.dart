import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class MenuState {}

class MenuLoading extends MenuState {}

class MenuLoaded extends MenuState {
  final List<ProductCategory> categories;
  MenuLoaded(this.categories);
}

class MenuSaving extends MenuState {
  final List<ProductCategory> categories;
  MenuSaving(this.categories);
}

class MenuError extends MenuState {
  final String message;
  MenuError(this.message);
}

class MenuCubit extends Cubit<MenuState> {
  final ApiClient _api;

  MenuCubit(this._api) : super(MenuLoading());

  Future<void> load() async {
    emit(MenuLoading());
    try {
      final cats = await _api.getMyStoreMenu();
      emit(MenuLoaded(cats));
    } on ApiException catch (e) {
      emit(MenuError(e.message));
    } catch (_) {
      emit(MenuError('Gagal memuat menu'));
    }
  }

  Future<void> createCategory(String name) async {
    final current = state is MenuLoaded ? (state as MenuLoaded).categories : [];
    emit(MenuSaving(current.cast<ProductCategory>()));
    await _api.createCategory(name);
    await load();
  }

  Future<void> createProduct(String catId, Map<String, dynamic> data, {File? image}) async {
    final product = await _api.createProduct(catId, data);
    if (image != null) {
      await _api.uploadProductImage(product.id, image);
    }
    await load();
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data, {File? image}) async {
    await _api.updateProduct(productId, data);
    if (image != null) {
      await _api.uploadProductImage(productId, image);
    }
    await load();
  }

  Future<void> deleteProduct(String productId) async {
    await _api.deleteProduct(productId);
    await load();
  }

  Future<void> toggleAvailability(String productId, bool available) async {
    await _api.toggleProductAvailability(productId, available);
    await load();
  }
}
