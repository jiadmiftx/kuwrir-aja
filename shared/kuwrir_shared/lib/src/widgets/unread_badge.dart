import 'package:flutter/material.dart';
import '../theme/kuwrir_colors.dart';

/// Small numeric badge (e.g. "3", or "9+" past 9) — renders nothing when
/// [count] is 0 so call sites can always include it unconditionally.
/// Caller positions it, typically via `Stack`/`Positioned` wrapping an icon.
class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: KuwrirColors.error,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KuwrirColors.surface, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}
