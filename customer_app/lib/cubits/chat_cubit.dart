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
  Timer? _pollTimer;

  ChatCubit(this._api, {required this.orderId}) : super(ChatInitial());

  void start() {
    _load();
    // Push (see NotificationService.onPushData) is the primary refresh
    // trigger now — this is just a fallback for missed/delayed pushes.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
  }

  Future<void> refreshNow() => _silentRefresh();

  Future<void> _load() async {
    emit(ChatLoading());
    try {
      final data = await _api.getOrderChat(orderId);
      final msgs = data.map((m) => ChatMessage.fromJson(m)).toList();
      emit(ChatLoaded(msgs));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await _api.getOrderChat(orderId);
      final msgs = data.map((m) => ChatMessage.fromJson(m)).toList();
      if (!isClosed) emit(ChatLoaded(msgs));
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    try {
      await _api.sendChatMessage(orderId, text);
      await _silentRefresh();
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
