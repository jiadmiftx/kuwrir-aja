"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowRight01Icon, ShoppingBag02Icon } from "@hugeicons/core-free-icons";
import { useCartStore, cartItemCount, cartSubtotal } from "@/lib/stores/cart";
import { formatIDR } from "@/lib/format";

/// Mirrors customer_app's FloatingCartButton: a pill that appears once the
/// cart has items, showing item count + subtotal, one tap to /cart. Only
/// shown while actively browsing (home, search) — BottomNav's own small
/// cart-count badge on the "Keranjang" tab already covers every other
/// screen, and floating this over order detail/checkout/etc. would just be
/// visual noise on top of screens that aren't about adding more items.
const SHOW_ON_PATHS = ["/", "/search"];

export function FloatingCartButton() {
  const pathname = usePathname();
  const lines = useCartStore((s) => s.lines);
  const merchantName = useCartStore((s) => s.merchantName);

  if (lines.length === 0 || !SHOW_ON_PATHS.includes(pathname)) return null;

  const count = cartItemCount(lines);
  const subtotal = cartSubtotal(lines);

  return (
    <Link
      href="/cart"
      className="floating-cart fixed left-4 right-4 z-30 mx-auto flex max-w-(--content-width) items-center gap-3 rounded-full bg-(--color-accent) px-4 py-3 text-(--color-accent-contrast) shadow-[0_10px_28px_-8px_rgba(0,0,0,0.35)] transition-transform active:scale-[0.98] md:left-auto md:right-6 md:w-80"
    >
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white/20">
        <HugeiconsIcon icon={ShoppingBag02Icon} size={18} strokeWidth={1.5} />
      </span>
      <span className="flex flex-1 flex-col overflow-hidden text-left">
        <span className="truncate text-xs opacity-85">{count} item{merchantName ? ` · ${merchantName}` : ""}</span>
        <span className="text-sm font-semibold">{formatIDR(subtotal)}</span>
      </span>
      <span className="flex shrink-0 items-center gap-1 text-sm font-semibold">
        Lihat
        <HugeiconsIcon icon={ArrowRight01Icon} size={16} strokeWidth={2} />
      </span>
    </Link>
  );
}
