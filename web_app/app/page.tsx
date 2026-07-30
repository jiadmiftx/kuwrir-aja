"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard } from "@/components/AuthGuard";
import { MerchantCard } from "@/components/MerchantCard";
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
    <div className="pb-4">
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-gray-100 bg-white px-4 py-3">
        <div>
          <p className="text-xs text-gray-500">Halo{user ? `, ${user.name || "kamu"}` : ""} 👋</p>
          <p className="text-sm font-semibold text-gray-800">Mau pesan apa hari ini?</p>
        </div>
        <Link href="/profile" className="text-2xl">
          👤
        </Link>
      </header>

      <Link
        href="/search"
        className="mx-4 mt-3 flex items-center gap-2 rounded-full border border-gray-200 bg-gray-50 px-4 py-2.5 text-sm text-gray-400"
      >
        🔍 Cari toko atau produk...
      </Link>

      {banners.data && banners.data.banners.length > 0 && (
        <div className="mt-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1">
          {banners.data.banners.map((b) => (
            <div
              key={b.id}
              className="relative flex min-w-[85%] snap-center flex-col justify-end overflow-hidden rounded-xl bg-emerald-600 text-white"
              style={{ aspectRatio: "16/7" }}
            >
              {b.image_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={b.image_url} alt={b.title} className="absolute inset-0 h-full w-full object-cover" />
              )}
              <div className="relative z-10 bg-gradient-to-t from-black/70 to-transparent p-3">
                <p className="text-sm font-bold">{b.title}</p>
                {b.subtitle && <p className="text-xs opacity-90">{b.subtitle}</p>}
              </div>
            </div>
          ))}
        </div>
      )}

      {categories.data && categories.data.food_categories.length > 0 && (
        <div className="mt-4 flex gap-2 overflow-x-auto px-4 pb-1">
          <button
            onClick={() => setActiveCategory(null)}
            className={`whitespace-nowrap rounded-full border px-3 py-1.5 text-xs font-medium ${
              activeCategory === null ? "border-emerald-600 bg-emerald-50 text-emerald-700" : "border-gray-200 text-gray-600"
            }`}
          >
            Semua
          </button>
          {categories.data.food_categories.map((c) => (
            <button
              key={c.id}
              onClick={() => setActiveCategory(c.id)}
              className={`whitespace-nowrap rounded-full border px-3 py-1.5 text-xs font-medium ${
                activeCategory === c.id ? "border-emerald-600 bg-emerald-50 text-emerald-700" : "border-gray-200 text-gray-600"
              }`}
            >
              {c.icon ? `${c.icon} ` : ""}
              {c.name}
            </button>
          ))}
        </div>
      )}

      {geo.status === "granted" && nearbyMerchants.data && nearbyMerchants.data.merchants.length > 0 && (
        <section className="mt-5">
          <h2 className="px-4 text-sm font-bold text-gray-800">Terdekat dari kamu</h2>
          <div className="mt-2 flex gap-3 overflow-x-auto px-4 pb-1">
            {nearbyMerchants.data.merchants.map((m) => (
              <MerchantCard key={m.id} merchant={m} />
            ))}
          </div>
        </section>
      )}
      {geo.status === "denied" && (
        <p className="mx-4 mt-4 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-700">
          Izinkan akses lokasi di browser untuk melihat toko terdekat.
        </p>
      )}

      {popularProducts.data && popularProducts.data.products.length > 0 && (
        <section className="mt-5">
          <h2 className="px-4 text-sm font-bold text-gray-800">Sedang Rame</h2>
          <div className="mt-2 flex gap-3 overflow-x-auto px-4 pb-1">
            {popularProducts.data.products.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      <section className="mt-5">
        <h2 className="px-4 text-sm font-bold text-gray-800">Rating Tertinggi</h2>
        <div className="mt-2 flex gap-3 overflow-x-auto px-4 pb-1">
          {popularMerchants.isLoading && <p className="px-4 text-xs text-gray-400">Memuat...</p>}
          {popularMerchants.data?.merchants.map((m) => (
            <MerchantCard key={m.id} merchant={m} />
          ))}
          {popularMerchants.data && popularMerchants.data.merchants.length === 0 && (
            <p className="px-4 text-xs text-gray-400">Belum ada toko untuk kategori ini.</p>
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
