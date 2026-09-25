import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  ChatLoaded(this.messages);
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}

class ChatCubit extends Cubit<ChatState> {
  final ApiClient _api;
  final String orderId;
  final SseStream _stream;
  Timer? _fallbackTimer;

  ChatCubit(this._api, {required this.orderId})
    : _stream = SseStream(
        _api,
        path: '/merchant-orders/$orderId/chat/stream',
        eventName: 'chat_message',
      ),
      super(ChatInitial());

  /// SSE is the primary refresh trigger — every event is trigger-only (see
  /// backend ChatEvent), so it just re-runs the same refetch as a poll
  /// would. The periodic timer here is just a slow safety net for the rare
  /// case where the stream stalls without tripping its own reconnect.
  void start() {
    _load();
    _stream.start(onEvent: (_) => _silentRefresh());
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentRefresh(),
    );
  }

  Future<void> refreshNow() => _silentRefresh();

  Future<void> _load() async {
    emit(ChatLoading());
    try {
      final data = await _api.getMerchantOrderChat(orderId);
      final msgs = data.map((m) => ChatMessage.fromJson(m)).toList();
      emit(ChatLoaded(msgs));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await _api.getMerchantOrderChat(orderId);
      final msgs = data.map((m) => ChatMessage.fromJson(m)).toList();
      if (!isClosed) emit(ChatLoaded(msgs));
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    try {
      await _api.sendMerchantOrderChat(orderId, text);
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
