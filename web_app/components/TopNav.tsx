"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { HugeiconsIcon } from "@hugeicons/react";
import { Home01Icon, Search01Icon, ShoppingBag02Icon, Invoice01Icon, UserCircleIcon } from "@hugeicons/core-free-icons";
import { useCartStore, cartItemCount } from "@/lib/stores/cart";
import { NotificationBell } from "@/components/NotificationBell";

const LINKS = [
  { href: "/", label: "Beranda", icon: Home01Icon },
  { href: "/search", label: "Cari", icon: Search01Icon },
  { href: "/orders", label: "Pesanan", icon: Invoice01Icon },
] as const;

export function TopNav() {
  const pathname = usePathname();
  const count = useCartStore((s) => cartItemCount(s.lines));

  if (pathname === "/login") return null;

  return (
    <header className="sticky top-0 z-40 hidden border-b border-(--color-border) bg-(--color-surface-raised)/95 backdrop-blur md:block">
      <div className="mx-auto flex max-w-(--content-width) items-center gap-8 px-8 py-3.5">
        <Link href="/" className="shrink-0">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/logo_cocourir.svg" alt="Cocourir" className="h-7 w-auto" />
        </Link>

        <nav className="flex items-center gap-1">
          {LINKS.map((link) => {
            const active = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`flex items-center gap-2 rounded-full px-3.5 py-2 text-sm font-medium transition-colors ${
                  active ? "bg-(--color-accent-soft) text-(--color-accent)" : "text-(--color-ink-soft) hover:bg-(--color-border-soft)"
                }`}
              >
                <HugeiconsIcon icon={link.icon} size={18} strokeWidth={active ? 2 : 1.5} />
                {link.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-1.5">
          <NotificationBell className="h-9 w-9 rounded-full text-(--color-ink-soft) transition-colors hover:bg-(--color-border-soft)" />
          <Link
            href="/cart"
            className="relative flex items-center gap-2 rounded-full px-3.5 py-2 text-sm font-medium text-(--color-ink-soft) transition-colors hover:bg-(--color-border-soft)"
          >
            <HugeiconsIcon icon={ShoppingBag02Icon} size={18} strokeWidth={1.5} />
            Keranjang
            {count > 0 && (
              <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-(--color-accent) px-1 text-[11px] font-semibold text-(--color-accent-contrast)">
                {count}
              </span>
            )}
          </Link>
          <Link
            href="/profile"
            className="flex items-center gap-2 rounded-full px-3.5 py-2 text-sm font-medium text-(--color-ink-soft) transition-colors hover:bg-(--color-border-soft)"
          >
            <HugeiconsIcon icon={UserCircleIcon} size={18} strokeWidth={1.5} />
            Profil
          </Link>
        </div>
      </div>
    </header>
  );
}
