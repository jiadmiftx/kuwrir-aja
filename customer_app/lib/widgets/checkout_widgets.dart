import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Shared building blocks for the cart → checkout → payment flow, so the
/// three screens read as one continuous surface instead of three separately
/// hand-rolled layouts. Previously `cart_screen.dart` and
/// `order_summary_screen.dart` each kept their own near-identical
/// `_PriceRow`/`_SoftPanel`/currency formatter — consolidated here.

/// Thousands-formatted Rupiah, without the currency symbol repeated at every
/// call site (screens prefix "Rp" themselves where it reads better bold).
String formatRupiah(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Uppercase eyebrow label above a section, e.g. "PESANAN". Deliberately
/// plain text, no icon or box — the flow reads top-to-bottom like a single
/// receipt rather than a stack of separately-chromed cards.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: KuwrirColors.textHint,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A quiet content surface: tinted fill instead of a hard 1px border, so
/// adjacent sections separate by color/spacing rather than by drawing a box
/// around every single one of them.
class SoftPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KuwrirColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// One line of a price breakdown. `emphasis` renders the total row: larger,
/// bolder, primary-colored amount — the one number on the screen that should
/// actually draw the eye, per Gojek/Grab-style receipts.
class PriceRow extends StatelessWidget {
  final String label;
  final num amount;
  final bool emphasis;
  final bool isDiscount;
  const PriceRow({
    super.key,
    required this.label,
    required this.amount,
    this.emphasis = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDiscount
        ? KuwrirColors.success
        : emphasis
        ? KuwrirColors.textPrimary
        : KuwrirColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasis ? 15 : 13.5,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              color: emphasis
                  ? KuwrirColors.textPrimary
                  : KuwrirColors.textSecondary,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}Rp ${formatRupiah(amount)}',
            style: TextStyle(
              fontSize: emphasis ? 19 : 13.5,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact quantity stepper button used in the cart's item rows.
class QtyStepButton extends StatelessWidget {
  final List<List<dynamic>> icon;
  final VoidCallback? onTap;
  const QtyStepButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: enabled
              ? KuwrirColors.primary.withValues(alpha: 0.09)
              : KuwrirColors.divider,
          borderRadius: BorderRadius.circular(8),
        ),
        child: HugeIcon(
          icon: icon,
          size: 16,
          color: enabled ? KuwrirColors.primary : KuwrirColors.textHint,
        ),
      ),
    );
  }
}
