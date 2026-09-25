import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/chat_cubit.dart';
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  /// Which thread this screen shows — driver (default, existing behavior)
  /// or merchant. Also picks [counterpartLabel]'s default and which push
  /// `type` should trigger a refresh (see backend's SendChat/SendMerchantChat).
  final ChatChannel channel;

  /// Display name for the other party — "Driver" for the driver thread, or
  /// the merchant's own name for the merchant thread (more useful than a
  /// generic "Merchant" once the customer might be juggling multiple orders).
  final String counterpartLabel;

  /// Short item summary (e.g. "2x Nasi Goreng, 1x Es Teh") shown in a
  /// context card under the app bar — without this, a customer with
  /// several active orders open at once has no way to tell which order a
  /// chat is even about once they're a few messages in.
  final String? itemSummary;
  final double? total;
  final String? statusLabel;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.channel = ChatChannel.driver,
    String? counterpartLabel,
    this.itemSummary,
    this.total,
    this.statusLabel,
  }) : counterpartLabel = counterpartLabel ?? 'Driver';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatCubit _cubit;

  // Merchant channel starts locked (can't know yet whether the merchant has
  // ever replied until the first load completes); driver channel never
  // locks — see the `canChatMerchant`/`canChatDriver` split on Order.
  late bool _merchantHasReplied = widget.channel != ChatChannel.merchant;

  @override
  void initState() {
    super.initState();
    _cubit = ChatCubit(
      context.read<ApiClient>(),
      orderId: widget.orderId,
      channel: widget.channel,
    )..start();
    NotificationService.onPushData.addListener(_onPush);
  }

  void _onPush() {
    final data = NotificationService.onPushData.value;
    final expectedType = widget.channel == ChatChannel.merchant
        ? 'merchant_chat'
        : 'chat';
    if (data?['type'] == expectedType && data?['order_id'] == widget.orderId) {
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

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    try {
      await _cubit.sendMessage(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Gagal mengirim pesan',
            ),
          ),
        );
      }
      return;
    }
    // Scroll to bottom after send
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
        appBar: AppBar(
          title: Text(
            'Chat ${widget.counterpartLabel} - #${widget.orderNumber}',
          ),
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
                    _merchantHasReplied =
                        widget.channel != ChatChannel.merchant ||
                        state.messages.any((m) => m.senderRole == 'merchant');
                    if (state.messages.isEmpty) {
                      return Center(
                        child: Text(
                          widget.channel == ChatChannel.merchant
                              ? 'Toko akan menghubungi kamu di sini jika ada info soal pesananmu.'
                              : 'Belum ada pesan. Mulai chat dengan ${widget.counterpartLabel}!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: state.messages[i],
                        counterpartLabel: widget.counterpartLabel,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            _InputBar(
              controller: _textCtrl,
              onSend: _send,
              enabled: _merchantHasReplied,
              lockedHint: widget.channel == ChatChannel.merchant
                  ? 'Menunggu toko membalas dulu...'
                  : null,
            ),
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
              'Rp ${_fmt(total!)}',
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
  final String counterpartLabel;
  const _MessageBubble({required this.msg, required this.counterpartLabel});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isFromCustomer;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? KuwrirColors.primary : Colors.grey.shade200,
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
              isMe ? 'Kamu' : counterpartLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              msg.text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
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
  final bool enabled;
  final String? lockedHint;

  const _InputBar({
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.lockedHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: enabled ? 'Ketik pesan...' : (lockedHint ?? ''),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: enabled
                ? KuwrirColors.primary
                : KuwrirColors.textHint,
            child: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSent,
                color: Colors.white,
                size: 20,
              ),
              onPressed: enabled ? onSend : null,
            ),
          ),
        ],
      ),
    );
  }
}
