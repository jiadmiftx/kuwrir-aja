import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class JobBoardState {}

class JobBoardOffline extends JobBoardState {}

class JobBoardLoading extends JobBoardState {}

class JobBoardLoaded extends JobBoardState {
  final List<Map<String, dynamic>> jobs;
  final bool isOnline;
  JobBoardLoaded(this.jobs, {this.isOnline = true});
}

class JobBoardAccepting extends JobBoardState {
  final String orderId;
  JobBoardAccepting(this.orderId);
}

/// The driver already has an order accepted but not yet delivered — surfaces
/// on app start (see JobBoardCubit's constructor) so a restart mid-delivery
/// (app killed in background, crash, etc.) doesn't strand them on an empty
/// job board with no way back to the order that's already theirs.
class JobBoardResumeDelivery extends JobBoardState {
  final Map<String, dynamic> order;
  JobBoardResumeDelivery(this.order);
}

class JobBoardError extends JobBoardState {
  final String message;
  JobBoardError(this.message);
}

class JobBoardCubit extends Cubit<JobBoardState> {
  final ApiClient _api;
  bool _isOnline = false;
  Timer? _pollTimer;

  JobBoardCubit(this._api) : super(JobBoardOffline()) {
    _checkResumeDelivery();
  }

  Future<void> _checkResumeDelivery() async {
    try {
      final order = await _api.getCurrentDelivery();
      if (order != null && !isClosed) emit(JobBoardResumeDelivery(order));
    } catch (_) {
      // No active delivery, or the check failed — falling through to the
      // normal offline/online flow is the safe default either way.
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  Future<void> goOnline() async {
    emit(JobBoardLoading());
    try {
      await _api.setDriverStatus(true);
      _isOnline = true;
      final resume = await _api.getCurrentDelivery();
      if (resume != null) {
        emit(JobBoardResumeDelivery(resume));
        return;
      }
      await loadJobs();
      _startPolling();
    } on ApiException catch (e) {
      emit(JobBoardError(e.message));
    } catch (_) {
      emit(JobBoardError('Gagal mengubah status'));
    }
  }

  Future<void> goOffline() async {
    _stopPolling();
    try {
      await _api.setDriverStatus(false);
      _isOnline = false;
      emit(JobBoardOffline());
    } catch (_) {
      emit(JobBoardOffline());
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _silentRefresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _silentRefresh() async {
    if (!_isOnline || isClosed) return;
    try {
      final jobs = await _api.getAvailableJobs();
      if (!isClosed) emit(JobBoardLoaded(jobs, isOnline: _isOnline));
    } catch (_) {}
  }

  Future<void> loadJobs() async {
    emit(JobBoardLoading());
    try {
      final jobs = await _api.getAvailableJobs();
      emit(JobBoardLoaded(jobs, isOnline: _isOnline));
    } on ApiException catch (e) {
      emit(JobBoardError(e.message));
    } catch (_) {
      emit(JobBoardError('Gagal memuat pekerjaan'));
    }
  }

  Future<Map<String, dynamic>?> acceptJob(String orderId) async {
    _stopPolling();
    emit(JobBoardAccepting(orderId));
    try {
      final result = await _api.acceptDelivery(orderId);
      // Stay online — accepting a delivery just means the driver is busy
      // with it, not that they toggled off. Job board polling resumes via
      // resetAfterDelivery() once they return from the delivery flow. The
      // backend's online flag is untouched here too, so it stays in sync
      // with what the switch shows.
      return result;
    } on ApiException catch (e) {
      if (_isOnline) _startPolling();
      emit(JobBoardError(e.message));
      return null;
    } catch (_) {
      if (_isOnline) _startPolling();
      emit(JobBoardError('Gagal mengambil pesanan'));
      return null;
    }
  }

  /// Called when the driver returns to the job board after finishing (or
  /// dropping) a delivery. Resumes browsing/polling if still online instead
  /// of forcing the toggle off — going offline is now only ever a deliberate
  /// tap on the switch.
  void resetAfterDelivery() {
    if (_isOnline) {
      loadJobs();
      _startPolling();
    } else {
      emit(JobBoardOffline());
    }
  }
}
