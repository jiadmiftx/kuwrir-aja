import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/location_service.dart';

abstract class JobBoardState {}

class JobBoardOffline extends JobBoardState {}

class JobBoardLoading extends JobBoardState {}

class JobBoardLoaded extends JobBoardState {
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> myActiveOrders;
  final bool isOnline;
  JobBoardLoaded(
    this.jobs, {
    this.myActiveOrders = const [],
    this.isOnline = true,
  });
}

class JobBoardAccepting extends JobBoardState {
  final String orderId;
  JobBoardAccepting(this.orderId);
}

class JobBoardError extends JobBoardState {
  final String message;
  JobBoardError(this.message);
}

class JobBoardCubit extends Cubit<JobBoardState> {
  final ApiClient _api;
  bool _isOnline = false;
  Timer? _pollTimer;
  Timer? _locationTimer;

  JobBoardCubit(this._api) : super(JobBoardOffline()) {
    _resumeIfActive();
  }

  /// On app start, if the driver already has in-progress deliveries, treat
  /// them as effectively online (going offline would strand those orders
  /// with no way to see them) and load the board straight away instead of
  /// stranding the driver on an empty offline screen.
  Future<void> _resumeIfActive() async {
    try {
      final active = await _api.getCurrentDelivery();
      if (active.isNotEmpty && !isClosed) {
        _isOnline = true;
        await loadJobs();
        _startPolling();
        unawaited(LocationService.sendCurrentLocation(_api));
      }
    } catch (_) {
      // No active delivery, or the check failed — falling through to the
      // normal offline/online flow is the safe default either way.
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    return super.close();
  }

  Future<void> goOnline() async {
    emit(JobBoardLoading());
    try {
      await _api.setDriverStatus(true);
      _isOnline = true;
      await loadJobs();
      _startPolling();
      unawaited(LocationService.sendCurrentLocation(_api));
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
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _silentRefresh(),
    );
    // Light foreground location ping so admin's assign-driver distance
    // figure doesn't go stale during a long idle-online stretch — separate,
    // much slower cadence than the job-board poll, and a single GPS fix
    // each time, not a continuous stream.
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => LocationService.sendCurrentLocation(_api),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _silentRefresh() async {
    if (!_isOnline || isClosed) return;
    try {
      final results = await Future.wait([
        _api.getAvailableJobs(),
        _api.getCurrentDelivery(),
      ]);
      if (!isClosed) {
        emit(
          JobBoardLoaded(
            results[0],
            myActiveOrders: results[1],
            isOnline: _isOnline,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> loadJobs() async {
    emit(JobBoardLoading());
    try {
      final results = await Future.wait([
        _api.getAvailableJobs(),
        _api.getCurrentDelivery(),
      ]);
      emit(
        JobBoardLoaded(
          results[0],
          myActiveOrders: results[1],
          isOnline: _isOnline,
        ),
      );
    } on ApiException catch (e) {
      emit(JobBoardError(e.message));
    } catch (_) {
      emit(JobBoardError('Gagal memuat pekerjaan'));
    }
  }

  Future<Map<String, dynamic>?> acceptJob(String orderId) async {
    emit(JobBoardAccepting(orderId));
    try {
      final result = await _api.acceptDelivery(orderId);
      unawaited(LocationService.sendCurrentLocation(_api));
      // Stay on the board — accepting just moves this order from "assigned
      // to you" into "sedang kamu antar", not into a separate forced screen.
      await loadJobs();
      return result;
    } on ApiException catch (e) {
      emit(JobBoardError(e.message));
      return null;
    } catch (_) {
      emit(JobBoardError('Gagal menerima tugas'));
      return null;
    }
  }
}
