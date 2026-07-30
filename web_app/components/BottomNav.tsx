"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { HugeiconsIcon } from "@hugeicons/react";
import { Home01Icon, Search01Icon, ShoppingBag02Icon, Invoice01Icon, UserIcon } from "@hugeicons/core-free-icons";
import { useCartStore, cartItemCount } from "@/lib/stores/cart";

const TABS = [
  { href: "/", label: "Beranda", icon: Home01Icon },
  { href: "/search", label: "Cari", icon: Search01Icon },
  { href: "/cart", label: "Keranjang", icon: ShoppingBag02Icon },
  { href: "/orders", label: "Pesanan", icon: Invoice01Icon },
  { href: "/profile", label: "Profil", icon: UserIcon },
] as const;

export function BottomNav() {
  const pathname = usePathname();
  const count = useCartStore((s) => cartItemCount(s.lines));

  if (pathname === "/login") return null;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 border-t border-(--color-border) bg-(--color-surface-raised) md:hidden">
      <div className="mx-auto flex max-w-(--content-width) items-stretch justify-between">
        {TABS.map((tab) => {
          const active = pathname === tab.href;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`relative flex flex-1 flex-col items-center gap-1 py-2.5 text-[11px] transition-colors ${
                active ? "text-(--color-accent)" : "text-(--color-ink-faint)"
              }`}
            >
              <HugeiconsIcon icon={tab.icon} size={22} strokeWidth={active ? 2 : 1.5} />
              {tab.label}
              {tab.href === "/cart" && count > 0 && (
                <span className="absolute right-6 top-1 rounded-full bg-(--color-accent) px-1.5 text-[10px] font-semibold text-(--color-accent-contrast)">
                  {count}
                </span>
              )}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
