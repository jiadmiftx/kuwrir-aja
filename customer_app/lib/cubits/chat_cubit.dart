import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Which order-chat thread this cubit drives — customer↔driver (the
/// original thread) or customer↔merchant. The two are entirely separate
/// backend endpoints/channels (see backend's ChatMessage.Channel); this
/// enum just picks which pair of ApiClient methods/paths to use rather than
/// duplicating this whole class for the second thread.
enum ChatChannel { driver, merchant }

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
  final ChatChannel channel;
  final SseStream _stream;
  Timer? _fallbackTimer;

  ChatCubit(
    this._api, {
    required this.orderId,
    this.channel = ChatChannel.driver,
  }) : _stream = SseStream(
         _api,
         path: channel == ChatChannel.merchant
             ? '/orders/$orderId/merchant-chat/stream'
             : '/orders/$orderId/chat/stream',
         eventName: 'chat_message',
       ),
       super(ChatInitial());

  /// SSE is the primary refresh trigger now — every event is trigger-only
  /// (see backend ChatEvent), so it just re-runs the same refetch as the
  /// old poll. The periodic timer here is just a slow safety net for the
  /// rare case where the stream stalls without tripping its own reconnect.
  void start() {
    _load();
    _stream.start(onEvent: (_) => _silentRefresh());
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentRefresh(),
    );
  }

  Future<void> refreshNow() => _silentRefresh();

  Future<List<Map<String, dynamic>>> _fetch() => channel == ChatChannel.merchant
      ? _api.getOrderMerchantChat(orderId)
      : _api.getOrderChat(orderId);

  Future<void> _load() async {
    emit(ChatLoading());
    try {
      final data = await _fetch();
      final msgs = data.map((m) => ChatMessage.fromJson(m)).toList();
      emit(ChatLoaded(msgs));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await _fetch();
      final msgs = data.map((m) => ChatMessage.fromJson(m)).toList();
      if (!isClosed) emit(ChatLoaded(msgs));
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    try {
      if (channel == ChatChannel.merchant) {
        await _api.sendOrderMerchantChat(orderId, text);
      } else {
        await _api.sendChatMessage(orderId, text);
      }
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
