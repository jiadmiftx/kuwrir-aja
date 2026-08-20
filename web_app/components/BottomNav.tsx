"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { Chatting01Icon, Home01Icon, ShoppingBag02Icon, Invoice01Icon } from "@hugeicons/core-free-icons";
import { useCartStore, cartItemCount } from "@/lib/stores/cart";
import { useAuthStore } from "@/lib/stores/auth";
import { getChatUnreadCount } from "@/lib/api/endpoints";

// No dedicated search tab — the homepage's own search bar (app/page.tsx)
// is already a one-tap link to /search, and Beranda itself is always one
// tap away from every other tab, so a 5th tab just for that was redundant.
// Profil isn't a tab either (mirrors customer_app) — its icon now sits
// next to the notification bell in the header instead; Chat takes the slot.
const TABS = [
  { href: "/", label: "Beranda", icon: Home01Icon },
  { href: "/cart", label: "Keranjang", icon: ShoppingBag02Icon },
  { href: "/orders", label: "Pesanan", icon: Invoice01Icon },
  { href: "/chat", label: "Chat", icon: Chatting01Icon },
] as const;

export function BottomNav() {
  const pathname = usePathname();
  const count = useCartStore((s) => cartItemCount(s.lines));
  const token = useAuthStore((s) => s.token);
  const unread = useQuery({
    queryKey: ["chat-unread"],
    queryFn: getChatUnreadCount,
    enabled: !!token,
    refetchInterval: 30_000,
  });

  if (pathname === "/login") return null;

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-30 border-t border-(--color-border) bg-(--color-surface-raised) md:hidden"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
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
              {tab.href === "/chat" && (unread.data?.total ?? 0) > 0 && (
                <span className="absolute right-6 top-1 rounded-full bg-(--color-danger) px-1.5 text-[10px] font-semibold text-(--color-accent-contrast)">
                  {(unread.data?.total ?? 0) > 9 ? "9+" : unread.data?.total}
                </span>
              )}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
