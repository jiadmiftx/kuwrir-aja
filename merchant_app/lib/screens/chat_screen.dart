import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/chat_cubit.dart';
import '../services/notification_service.dart';

/// Merchant side of the customer↔merchant chat thread — mirrors
/// customer_app/driver_app's chat_screen.dart, just pointed at the
/// merchant-order endpoints and always merchant-branded (no channel param
/// needed here, merchant_app only ever has this one thread).
class ChatScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String customerName;

  /// Short item summary shown in a context card under the app bar — a
  /// merchant fielding several chats at once has no other way to tell
  /// which order this thread is about once they're a few messages in.
  final String? itemSummary;
  final double? total;
  final String? statusLabel;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    this.itemSummary,
    this.total,
    this.statusLabel,
  });

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
    _cubit = ChatCubit(context.read<ApiClient>(), orderId: widget.orderId)
      ..start();
    NotificationService.onPushData.addListener(_onPush);
  }

  void _onPush() {
    final data = NotificationService.onPushData.value;
    if (data?['type'] == 'merchant_chat' &&
        data?['order_id'] == widget.orderId) {
      _cubit.refreshNow();
    }
  }

  @override
  void dispose() {
    NotificationService.onPushData.removeListener(_onPush);
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
        appBar: AppBar(
          title: Text('Chat ${widget.customerName} · #${widget.orderNumber}'),
          backgroundColor: KuwrirColors.background,
        ),
        body: Column(
          children: [
            if (widget.itemSummary != null)
              _OrderContextCard(
                orderNumber: widget.orderNumber,
                itemSummary: widget.itemSummary!,
                total: widget.total,
                statusLabel: widget.statusLabel,
              ),
            Expanded(
              child: BlocBuilder<ChatCubit, ChatState>(
                bloc: _cubit,
                builder: (context, state) {
                  if (state is ChatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ChatError) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  if (state is ChatLoaded) {
                    if (state.messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada pesan. Mulai chat dengan ${widget.customerName}!',
                          style: TextStyle(color: KuwrirColors.textHint),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: state.messages[i],
                        customerName: widget.customerName,
                      ),
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

class _OrderContextCard extends StatelessWidget {
  final String orderNumber;
  final String itemSummary;
  final double? total;
  final String? statusLabel;

  const _OrderContextCard({
    required this.orderNumber,
    required this.itemSummary,
    this.total,
    this.statusLabel,
  });

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: KuwrirColors.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInvoice01,
            size: 15,
            color: KuwrirColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderNumber${statusLabel != null ? ' · $statusLabel' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  itemSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: KuwrirColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (total != null) ...[
            const SizedBox(width: 8),
            Text(
              'IDR ${_fmt(total!)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: KuwrirColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String customerName;
  const _MessageBubble({required this.msg, required this.customerName});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isFromMerchant;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? KuwrirColors.primary : KuwrirColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: KuwrirColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMe ? 'Kamu' : customerName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : KuwrirColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : KuwrirColors.textPrimary,
              ),
            ),
            if (isMe) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: msg.isRead
                        ? HugeIcons.strokeRoundedCheckmarkCircle02
                        : HugeIcons.strokeRoundedTick01,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    msg.isRead ? 'Dibaca' : 'Terkirim',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: KuwrirColors.background,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: KuwrirColors.primary,
            child: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSent,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
