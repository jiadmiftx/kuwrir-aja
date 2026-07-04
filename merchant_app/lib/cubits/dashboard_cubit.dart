import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

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
      ));
    } on ApiException catch (e) {
      emit(DashboardError(e.message));
    } catch (_) {
      emit(DashboardError('Gagal memuat dashboard'));
    }
  }
}
