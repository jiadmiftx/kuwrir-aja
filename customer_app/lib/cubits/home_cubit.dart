import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<Merchant> nearby;
  final List<Merchant> popular;
  final List<FoodCategory> categories;
  final List<Promotion> promotions;
  final String? selectedCategoryId;

  HomeLoaded({
    required this.nearby,
    required this.popular,
    required this.categories,
    required this.promotions,
    this.selectedCategoryId,
  });

  HomeLoaded copyWith({
    List<Merchant>? nearby,
    List<Merchant>? popular,
    List<FoodCategory>? categories,
    List<Promotion>? promotions,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
  }) =>
      HomeLoaded(
        nearby: nearby ?? this.nearby,
        popular: popular ?? this.popular,
        categories: categories ?? this.categories,
        promotions: promotions ?? this.promotions,
        selectedCategoryId:
            clearSelectedCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      );
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}

/// Drives the customer app's food-discovery Home screen: nearby merchants
/// (real distance), top-rated merchants, the global food-category filter
/// chips, and active promotions — all real data, no fabricated sections.
class HomeCubit extends Cubit<HomeState> {
  final ApiClient _api;
  double? _lat;
  double? _lng;

  HomeCubit(this._api) : super(HomeInitial());

  Future<void> load({double? lat, double? lng}) async {
    _lat = lat ?? _lat;
    _lng = lng ?? _lng;
    emit(HomeLoading());
    try {
      final results = await Future.wait([
        _fetchNearby(),
        _api.getPopularMerchants(),
        _api.getFoodCategories(),
        _api.getActivePromotions(),
      ]);
      emit(HomeLoaded(
        nearby: results[0] as List<Merchant>,
        popular: results[1] as List<Merchant>,
        categories: results[2] as List<FoodCategory>,
        promotions: results[3] as List<Promotion>,
      ));
    } on ApiException catch (e) {
      emit(HomeError(e.message));
    } catch (_) {
      emit(HomeError('Gagal memuat beranda'));
    }
  }

  /// Re-fetches only the merchant rails (nearby/popular) filtered by
  /// category — categories and promotions stay as-is.
  Future<void> selectCategory(String? categoryId) async {
    final current = state;
    if (current is! HomeLoaded) return;
    try {
      final results = await Future.wait([
        _fetchNearby(categoryId: categoryId),
        _api.getPopularMerchants(foodCategoryId: categoryId),
      ]);
      emit(current.copyWith(
        nearby: results[0],
        popular: results[1],
        selectedCategoryId: categoryId,
        clearSelectedCategory: categoryId == null,
      ));
    } on ApiException catch (e) {
      emit(HomeError(e.message));
    } catch (_) {
      emit(HomeError('Gagal memuat kategori'));
    }
  }

  Future<List<Merchant>> _fetchNearby({String? categoryId}) {
    if (_lat == null || _lng == null) return Future.value(const []);
    return _api.getNearbyMerchants(
      lat: _lat!,
      lng: _lng!,
      radiusKm: 15,
      foodCategoryId: categoryId,
    );
  }
}
