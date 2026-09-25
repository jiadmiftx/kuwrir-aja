import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// A row in the Dashboard's "Menu Terlaris" rail — ranked by real delivered-
/// order frequency in the last 30 days, falling back to the merchant's
/// most recently added products when there's no order history yet.
class TopProduct {
  final String id;
  final String name;
  final String? imageUrl;
  final double price;
  final double? discountPrice;
  final int orderCount;

  const TopProduct({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.price,
    this.discountPrice,
    this.orderCount = 0,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        discountPrice: (json['discount_price'] as num?)?.toDouble(),
        orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
      );
}

abstract class DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int newOrders;
  final int processingOrders;
  final int courierEnRoute;
  final int completedOrders;
  final int cancelledOrders;
  final double todayRevenue;
  final double rating;
  final int totalReviews;
  final double walletBalance;
  final List<TopProduct> topProducts;

  DashboardLoaded({
    this.newOrders = 0,
    this.processingOrders = 0,
    this.courierEnRoute = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.todayRevenue = 0,
    this.rating = 0,
    this.totalReviews = 0,
    this.walletBalance = 0,
    this.topProducts = const [],
  });
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

class DashboardCubit extends Cubit<DashboardState> {
  final ApiClient _api;

  DashboardCubit(this._api) : super(DashboardLoading());

  Future<void> load() async {
    emit(DashboardLoading());
    try {
      final summary = await _api.getMerchantDashboardSummary();
      double walletBalance = 0;
      try {
        final wallet = await _api.getMerchantWallet();
        walletBalance = wallet.balance;
      } catch (_) {
        // Wallet is a secondary teaser stat here — don't fail the whole
        // dashboard load if it's unavailable.
      }
      final topProductsJson = summary['top_products'] as List<dynamic>? ?? [];
      emit(DashboardLoaded(
        newOrders: (summary['new_orders'] as num?)?.toInt() ?? 0,
        processingOrders: (summary['processing_orders'] as num?)?.toInt() ?? 0,
        courierEnRoute: (summary['courier_en_route'] as num?)?.toInt() ?? 0,
        completedOrders: (summary['completed_orders'] as num?)?.toInt() ?? 0,
        cancelledOrders: (summary['cancelled_orders'] as num?)?.toInt() ?? 0,
        todayRevenue: (summary['today_revenue'] as num?)?.toDouble() ?? 0,
        rating: (summary['rating'] as num?)?.toDouble() ?? 0,
        totalReviews: (summary['total_reviews'] as num?)?.toInt() ?? 0,
        walletBalance: walletBalance,
        topProducts: topProductsJson.map((p) => TopProduct.fromJson(p as Map<String, dynamic>)).toList(),
      ));
    } on ApiException catch (e) {
      emit(DashboardError(e.message));
    } catch (_) {
      emit(DashboardError('Gagal memuat dashboard'));
    }
  }
}
