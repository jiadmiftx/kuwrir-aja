import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class SupportChatState {}

class SupportChatInitial extends SupportChatState {}

class SupportChatLoading extends SupportChatState {}

class SupportChatLoaded extends SupportChatState {
  final List<SupportMessage> messages;
  SupportChatLoaded(this.messages);
}

class SupportChatError extends SupportChatState {
  final String message;
  SupportChatError(this.message);
}

class SupportChatCubit extends Cubit<SupportChatState> {
  final ApiClient _api;
  final SseStream _stream;
  Timer? _fallbackTimer;

  SupportChatCubit(this._api)
    : _stream = SseStream(
        _api,
        path: '/support/messages/stream',
        eventName: 'support_message',
      ),
      super(SupportChatInitial());

  void start() {
    _load();
    _stream.start(onEvent: (_) => _silentRefresh());
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _load() async {
    emit(SupportChatLoading());
    try {
      final msgs = await _api.getSupportMessages();
      emit(SupportChatLoaded(msgs));
    } catch (e) {
      emit(SupportChatError(e.toString()));
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final msgs = await _api.getSupportMessages();
      if (!isClosed) emit(SupportChatLoaded(msgs));
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    try {
      await _api.sendSupportMessage(text);
      await _silentRefresh();
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _fallbackTimer?.cancel();
    _stream.stop();
    return super.close();
  }
}
