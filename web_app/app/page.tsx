"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { Search01Icon, LocationOffline01Icon, UserIcon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { MerchantCard } from "@/components/MerchantCard";
import { NotificationBell } from "@/components/NotificationBell";
import { ProductCard } from "@/components/ProductCard";
import { useGeolocation } from "@/lib/hooks/useGeolocation";
import {
  getActiveBanners,
  getFoodCategories,
  getNearbyMerchants,
  getPopularMerchants,
  getPopularProducts,
} from "@/lib/api/endpoints";
import { useAuthStore } from "@/lib/stores/auth";
import { useState } from "react";

function HomeContent() {
  const user = useAuthStore((s) => s.user);
  const geo = useGeolocation();
  const [activeCategory, setActiveCategory] = useState<string | null>(null);

  const banners = useQuery({ queryKey: ["banners"], queryFn: getActiveBanners });
  const categories = useQuery({ queryKey: ["food-categories"], queryFn: getFoodCategories });
  const popularMerchants = useQuery({
    queryKey: ["merchants-popular", activeCategory],
    queryFn: () => getPopularMerchants(activeCategory ?? undefined),
  });
  const nearbyMerchants = useQuery({
    queryKey: ["merchants-nearby", geo.lat, geo.lng, activeCategory],
    queryFn: () => getNearbyMerchants(geo.lat!, geo.lng!, 10, activeCategory ?? undefined),
    enabled: geo.status === "granted",
  });
  const popularProducts = useQuery({ queryKey: ["products-popular"], queryFn: getPopularProducts });

  return (
    <div className="mx-auto max-w-(--content-width) px-4 pb-6 md:px-8">
      <header className="flex items-start justify-between pt-5 md:pt-8">
        <div>
          <p className="text-sm text-(--color-ink-faint)">Halo{user ? `, ${user.name || "kamu"}` : ""}</p>
          <h1 className="mt-0.5 text-xl font-semibold tracking-tight text-(--color-ink) md:text-2xl">
            Mau pesan apa hari ini?
          </h1>
        </div>
        <div className="mt-1 flex shrink-0 items-center gap-2 md:hidden">
          <NotificationBell className="h-10 w-10 rounded-full border border-(--color-border) bg-(--color-surface-raised) text-(--color-ink-soft)" />
          <Link
            href="/profile"
            className="flex h-10 w-10 items-center justify-center rounded-full border border-(--color-border) bg-(--color-surface-raised) text-(--color-ink-soft)"
            aria-label="Profil"
          >
            <HugeiconsIcon icon={UserIcon} size={18} strokeWidth={1.5} />
          </Link>
        </div>
      </header>

      <Link
        href="/search"
        className="mt-4 flex items-center gap-2.5 rounded-full border border-(--color-border) bg-(--color-surface-raised) px-4 py-3 text-sm text-(--color-ink-faint) shadow-[0_2px_10px_-4px_rgba(0,0,0,0.08)] transition-colors hover:border-(--color-ink-faint) md:max-w-md"
      >
        <HugeiconsIcon icon={Search01Icon} size={18} strokeWidth={1.5} />
        Cari toko atau produk...
      </Link>

      {banners.data && banners.data.banners.length > 0 && (
        <div className="mt-6 flex snap-x gap-3 overflow-x-auto pb-1 md:grid md:grid-cols-2 md:overflow-visible lg:grid-cols-3">
          {banners.data.banners.map((b) => (
            <div
              key={b.id}
              className="relative flex min-w-[85%] snap-center flex-col justify-end overflow-hidden rounded-[24px] bg-(--color-ink) text-(--color-accent-contrast) shadow-[0_6px_18px_-6px_rgba(0,0,0,0.2)] md:min-w-0"
              style={{ aspectRatio: "16/7" }}
            >
              {b.image_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={b.image_url} alt={b.title} className="absolute inset-0 h-full w-full object-cover" />
              )}
              <div className="relative z-10 bg-gradient-to-t from-black/75 to-transparent p-4">
                <p className="text-sm font-semibold">{b.title}</p>
                {b.subtitle && <p className="mt-0.5 text-xs opacity-85">{b.subtitle}</p>}
              </div>
            </div>
          ))}
        </div>
      )}

      {categories.data && categories.data.food_categories.length > 0 && (
        <div className="mt-6 flex gap-2 overflow-x-auto pb-1">
          <button
            onClick={() => setActiveCategory(null)}
            className={`whitespace-nowrap rounded-full border px-4 py-2.5 text-xs font-semibold transition-colors ${
              activeCategory === null
                ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)"
                : "border-(--color-border) text-(--color-ink-soft)"
            }`}
          >
            Semua
          </button>
          {categories.data.food_categories.map((c) => (
            <button
              key={c.id}
              onClick={() => setActiveCategory(c.id)}
              className={`whitespace-nowrap rounded-full border px-4 py-2.5 text-xs font-semibold transition-colors ${
                activeCategory === c.id
                  ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)"
                  : "border-(--color-border) text-(--color-ink-soft)"
              }`}
            >
              {c.name}
            </button>
          ))}
        </div>
      )}

      {geo.status === "granted" && nearbyMerchants.data && nearbyMerchants.data.merchants.length > 0 && (
        <section className="mt-9">
          <h2 className="text-base font-bold text-(--color-ink)">Terdekat dari kamu</h2>
          <div className="mt-3 flex gap-3 overflow-x-auto pb-1 md:grid md:grid-cols-3 md:overflow-visible lg:grid-cols-4">
            {nearbyMerchants.data.merchants.map((m) => (
              <MerchantCard key={m.id} merchant={m} />
            ))}
          </div>
        </section>
      )}
      {geo.status === "denied" && (
        <p className="mt-6 flex items-center gap-2 rounded-xl bg-(--color-warning-soft) px-4 py-3 text-xs text-(--color-warning)">
          <HugeiconsIcon icon={LocationOffline01Icon} size={16} strokeWidth={1.5} className="shrink-0" />
          Izinkan akses lokasi di browser untuk melihat toko terdekat.
        </p>
      )}

      {popularProducts.data && popularProducts.data.products.length > 0 && (
        <section className="mt-8">
          <h2 className="text-base font-bold text-(--color-ink)">Sedang Rame</h2>
          <div className="mt-3 flex gap-3 overflow-x-auto pb-1 md:grid md:grid-cols-3 md:overflow-visible lg:grid-cols-4">
            {popularProducts.data.products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      <section className="mt-9">
        <h2 className="text-base font-bold text-(--color-ink)">Rating Tertinggi</h2>
        <div className="mt-3 flex gap-3 overflow-x-auto pb-1 md:grid md:grid-cols-3 md:overflow-visible lg:grid-cols-4">
          {popularMerchants.isLoading && <p className="text-xs text-(--color-ink-faint)">Memuat...</p>}
          {popularMerchants.data?.merchants.map((m) => (
            <MerchantCard key={m.id} merchant={m} />
          ))}
          {popularMerchants.data && popularMerchants.data.merchants.length === 0 && (
            <p className="text-xs text-(--color-ink-faint)">Belum ada toko untuk kategori ini.</p>
          )}
        </div>
      </section>
    </div>
  );
}

export default function HomePage() {
  return (
    <AuthGuard>
      <HomeContent />
    </AuthGuard>
  );
}
