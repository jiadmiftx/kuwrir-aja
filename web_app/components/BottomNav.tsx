"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCartStore, cartItemCount } from "@/lib/stores/cart";

const TABS = [
  { href: "/", label: "Beranda", icon: "🏠" },
  { href: "/search", label: "Cari", icon: "🔍" },
  { href: "/cart", label: "Keranjang", icon: "🛒" },
  { href: "/orders", label: "Pesanan", icon: "🧾" },
  { href: "/profile", label: "Profil", icon: "👤" },
] as const;

export function BottomNav() {
  const pathname = usePathname();
  const count = useCartStore((s) => cartItemCount(s.lines));

  if (pathname === "/login") return null;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 border-t border-gray-200 bg-white">
      <div className="mx-auto flex max-w-[480px] items-stretch justify-between">
        {TABS.map((tab) => {
          const active = pathname === tab.href;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`relative flex flex-1 flex-col items-center gap-0.5 py-2 text-xs ${
                active ? "text-emerald-600" : "text-gray-500"
              }`}
            >
              <span className="text-lg leading-none">{tab.icon}</span>
              {tab.label}
              {tab.href === "/cart" && count > 0 && (
                <span className="absolute right-6 top-1 rounded-full bg-emerald-600 px-1.5 text-[10px] font-semibold text-white">
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
