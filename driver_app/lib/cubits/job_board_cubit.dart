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

class JobBoardError extends JobBoardState {
  final String message;
  JobBoardError(this.message);
}

class JobBoardCubit extends Cubit<JobBoardState> {
  final ApiClient _api;
  bool _isOnline = false;
  Timer? _pollTimer;

  JobBoardCubit(this._api) : super(JobBoardOffline());

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
      _isOnline = false;
      emit(JobBoardOffline());
      return result;
    } on ApiException catch (e) {
      _startPolling();
      emit(JobBoardError(e.message));
      return null;
    } catch (_) {
      _startPolling();
      emit(JobBoardError('Gagal mengambil pesanan'));
      return null;
    }
  }
}
