import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../cubits/cart_cubit.dart';

/// Gojek-style floating pill shown above screens whenever the cart has
/// items — tapping it jumps straight to `/cart`. Meant to be placed as the
/// last child of a [Stack] (it positions itself via [Positioned]) so it can
/// float over any screen's content without taking up permanent layout
/// space the way a `bottomNavigationBar` bar does.
///
/// Renders nothing when the cart is empty. The bottom offset always adds
/// [MediaQuery]'s bottom safe-area inset plus a fixed margin, so the pill
/// clears the gesture bar / bottom nav on every device instead of sitting
/// flush against it.
class FloatingCartButton extends StatelessWidget {
  const FloatingCartButton({super.key});

  static String _formatPrice(double price) => price
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        if (cart.isEmpty) return const SizedBox.shrink();
        final bottomInset = MediaQuery.of(context).padding.bottom + 16;
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottomInset,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/cart'),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: KuwrirColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedShoppingBag01,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${cart.totalQuantity} item',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 1,
                      height: 16,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'IDR ${_formatPrice(cart.subtotal)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lihat Keranjang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: Colors.white,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
