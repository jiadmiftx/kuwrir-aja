import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/chat_cubit.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  const ChatScreen({super.key, required this.orderId, required this.orderNumber});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ChatCubit(context.read<ApiClient>(), orderId: widget.orderId)..start();
  }

  @override
  void dispose() {
    _cubit.close();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _cubit.sendMessage(text);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: KuwrirColors.background,
        appBar: AppBar(title: Text('Chat - #${widget.orderNumber}')),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatCubit, ChatState>(
                bloc: _cubit,
                builder: (context, state) {
                  if (state is ChatLoading) return const Center(child: CircularProgressIndicator());
                  if (state is ChatError) {
                    return Center(
                      child: Text('Error: ${state.message}', style: TextStyle(color: KuwrirColors.error)),
                    );
                  }
                  if (state is ChatLoaded) {
                    if (state.messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: KuwrirColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chat_bubble_outline, size: 30, color: KuwrirColors.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada pesan',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: KuwrirColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chat dengan customer!',
                                style: TextStyle(color: KuwrirColors.textHint, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _MessageBubble(msg: state.messages[i]),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            _InputBar(controller: _textCtrl, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isFromDriver;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? KuwrirColors.primary : KuwrirColors.surface,
          border: isMe ? null : Border.all(color: KuwrirColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMe ? 'Kamu' : 'Customer',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white70 : KuwrirColors.textHint,
              ),
            ),
            const SizedBox(height: 2),
            Text(msg.text, style: TextStyle(color: isMe ? Colors.white : KuwrirColors.textPrimary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: KuwrirColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: KuwrirColors.border),
              ),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ketik pesan...',
                  hintStyle: TextStyle(color: KuwrirColors.textHint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: false,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: KuwrirColors.primary,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
