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
/// this screen intercepts that navigation, closes itself, and refreshes the
/// order status immediately.
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
              context.read<OrderTrackingCubit>().refreshNow(widget.orderId);
              Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
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
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
