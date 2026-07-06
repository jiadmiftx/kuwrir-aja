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
  final List<PromoBanner> banners;
  final List<ProductSearchResult> trending;
  final String? selectedCategoryId;

  HomeLoaded({
    required this.nearby,
    required this.popular,
    required this.categories,
    required this.promotions,
    required this.banners,
    required this.trending,
    this.selectedCategoryId,
  });

  HomeLoaded copyWith({
    List<Merchant>? nearby,
    List<Merchant>? popular,
    List<FoodCategory>? categories,
    List<Promotion>? promotions,
    List<PromoBanner>? banners,
    List<ProductSearchResult>? trending,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
  }) =>
      HomeLoaded(
        nearby: nearby ?? this.nearby,
        popular: popular ?? this.popular,
        categories: categories ?? this.categories,
        promotions: promotions ?? this.promotions,
        banners: banners ?? this.banners,
        trending: trending ?? this.trending,
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
    final results = await Future.wait([
      _safe(_fetchNearby(), const <Merchant>[]),
      _safe(_api.getPopularMerchants(), const <Merchant>[]),
      _safe(_api.getFoodCategories(), const <FoodCategory>[]),
      _safe(_api.getActivePromotions(), const <Promotion>[]),
      _safe(_api.getActiveBanners(), const <PromoBanner>[]),
      _safe(_api.getPopularProducts(), const <ProductSearchResult>[]),
    ]);
    emit(HomeLoaded(
      nearby: results[0] as List<Merchant>,
      popular: results[1] as List<Merchant>,
      categories: results[2] as List<FoodCategory>,
      promotions: results[3] as List<Promotion>,
      banners: results[4] as List<PromoBanner>,
      trending: results[5] as List<ProductSearchResult>,
    ));
  }

  /// Re-fetches only the merchant rails (nearby/popular) filtered by
  /// category — categories and promotions stay as-is.
  Future<void> selectCategory(String? categoryId) async {
    final current = state;
    if (current is! HomeLoaded) return;
    final results = await Future.wait([
      _safe(_fetchNearby(categoryId: categoryId), const <Merchant>[]),
      _safe(_api.getPopularMerchants(foodCategoryId: categoryId), const <Merchant>[]),
    ]);
    emit(current.copyWith(
      nearby: results[0],
      popular: results[1],
      selectedCategoryId: categoryId,
      clearSelectedCategory: categoryId == null,
    ));
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

  /// Runs [future], falling back to [fallback] on any failure. Each Home
  /// rail is independent — one endpoint erroring (e.g. not deployed yet,
  /// or a transient network hiccup) shouldn't blank out every other
  /// section that loaded fine.
  Future<T> _safe<T>(Future<T> future, T fallback) => future.catchError((_) => fallback);
}
