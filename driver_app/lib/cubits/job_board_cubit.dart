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

  JobBoardCubit(this._api) : super(JobBoardOffline());

  Future<void> goOnline() async {
    emit(JobBoardLoading());
    try {
      await _api.setDriverStatus(true);
      _isOnline = true;
      await loadJobs();
    } on ApiException catch (e) {
      emit(JobBoardError(e.message));
    } catch (_) {
      emit(JobBoardError('Gagal mengubah status'));
    }
  }

  Future<void> goOffline() async {
    try {
      await _api.setDriverStatus(false);
      _isOnline = false;
      emit(JobBoardOffline());
    } catch (_) {
      emit(JobBoardOffline());
    }
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
    emit(JobBoardAccepting(orderId));
    try {
      final result = await _api.acceptDelivery(orderId);
      await loadJobs();
      return result;
    } on ApiException catch (e) {
      emit(JobBoardError(e.message));
      return null;
    } catch (_) {
      emit(JobBoardError('Gagal mengambil pesanan'));
      return null;
    }
  }
}
