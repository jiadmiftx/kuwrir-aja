import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../cubits/order_tracking_cubit.dart';

/// Renders a Duitku payment link in-app instead of handing off to an
/// external browser. Reached via a plain Navigator.push, so both the AppBar
/// back arrow and the system back gesture just pop this route — no custom
/// interception needed for "close payment -> back to the order it's for".
///
/// [orderId] is used to detect when Duitku's page navigates to our
/// configured return URL (CreatePayment appends "/" + orderId to it
/// server-side) — nothing actually serves a real page there, so instead of
/// rendering whatever raw response lands on it (looks like a server error),
/// this screen intercepts that navigation and shows a brief confirming
/// state instead.
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _confirming = false;
  final _watcher = PaymentStatusWatcher(ApiClient());

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (request.url.contains(widget.orderId)) {
              _onReturnDetected();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Duitku's return-URL navigation can race its own async webhook — the
  /// callback that actually flips payment_status to "paid" may not have
  /// landed yet the instant the WebView redirects back. Wait on the SSE
  /// stream (capped at a few seconds) instead of refreshing once and
  /// hoping, so the order screen we pop back to already shows the right
  /// status rather than a stale "pending" until the next fallback poll.
  Future<void> _onReturnDetected() async {
    if (!mounted) return;
    setState(() => _confirming = true);
    final tracking = context.read<OrderTrackingCubit>();
    await _watcher.watch(
      widget.orderId,
      onStatus: (_) {},
      timeout: const Duration(seconds: 8),
    );
    if (!mounted) return;
    tracking.refreshNow(widget.orderId);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _watcher.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: KuwrirColors.background,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading && !_confirming)
            const Center(child: CircularProgressIndicator()),
          if (_confirming)
            Container(
              color: KuwrirColors.background.withValues(alpha: 0.94),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: KuwrirColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: KuwrirColors.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KuwrirColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: KuwrirColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Mengonfirmasi pembayaran',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: KuwrirColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sebentar, kami sedang memeriksa status pembayaranmu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: KuwrirColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
