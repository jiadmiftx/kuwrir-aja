import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Holds the logged-in user's profile, primarily so HomeScreen can check
/// `user?.isPhoneVerified` and gate access without re-fetching /auth/me
/// itself. `null` means "not loaded yet" — check `loading` to distinguish
/// that from "load failed".
class SessionState {
  final User? user;
  final bool loading;

  const SessionState({this.user, this.loading = false});
}

class SessionCubit extends Cubit<SessionState> {
  final ApiClient _api;

  SessionCubit(this._api) : super(const SessionState());

  Future<void> load() async {
    emit(SessionState(user: state.user, loading: true));
    try {
      final user = await _api.getMe();
      emit(SessionState(user: user, loading: false));
    } catch (_) {
      emit(SessionState(user: state.user, loading: false));
    }
  }
}
