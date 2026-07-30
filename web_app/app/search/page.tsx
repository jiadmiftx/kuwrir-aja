"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, Search01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { MerchantCard } from "@/components/MerchantCard";
import { ProductCard } from "@/components/ProductCard";
import { searchMerchants, searchProducts } from "@/lib/api/endpoints";

function SearchContent() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [submitted, setSubmitted] = useState("");

  const merchants = useQuery({
    queryKey: ["search-merchants", submitted],
    queryFn: () => searchMerchants(submitted),
    enabled: submitted.length > 0,
  });
  const products = useQuery({
    queryKey: ["search-products", submitted],
    queryFn: () => searchProducts({ q: submitted }),
    enabled: submitted.length > 0,
  });

  return (
    <div>
      <div className="sticky top-0 z-20 border-b border-(--color-border) bg-(--color-surface-raised) md:static md:border-none md:bg-transparent">
        <div className="mx-auto flex max-w-(--content-width) items-center gap-2 px-4 py-3 md:px-8 md:pt-8">
          <button
            onClick={() => router.back()}
            className="flex h-9 w-9 shrink-0 items-center justify-center text-(--color-ink-soft) md:hidden"
            aria-label="Kembali"
          >
            <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
          </button>
          <form
            className="flex-1 md:max-w-lg"
            onSubmit={(e) => {
              e.preventDefault();
              setSubmitted(query.trim());
            }}
          >
            <label className="flex items-center gap-2.5 rounded-full border border-(--color-border) bg-(--color-surface) px-4 py-2.5 text-sm focus-within:border-(--color-ink-faint)">
              <HugeiconsIcon icon={Search01Icon} size={17} strokeWidth={1.5} className="shrink-0 text-(--color-ink-faint)" />
              <input
                autoFocus
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Cari toko atau produk..."
                className="w-full bg-transparent outline-none placeholder:text-(--color-ink-faint)"
              />
            </label>
          </form>
        </div>
      </div>

      <div className="mx-auto max-w-(--content-width) px-4 md:px-8">
        {submitted === "" && (
          <p className="mt-12 text-center text-sm text-(--color-ink-faint)">Ketik untuk mencari toko atau produk</p>
        )}

        {submitted !== "" && (
          <div className="mt-5 flex flex-col gap-8">
            <section>
              <h2 className="text-base font-semibold text-(--color-ink)">Toko</h2>
              {merchants.isLoading && <p className="pt-2 text-xs text-(--color-ink-faint)">Mencari...</p>}
              {merchants.data && merchants.data.merchants.length === 0 && (
                <p className="pt-2 text-xs text-(--color-ink-faint)">Tidak ada toko ditemukan.</p>
              )}
              <div className="mt-3 flex gap-3 overflow-x-auto pb-1 md:grid md:grid-cols-3 md:overflow-visible lg:grid-cols-4">
                {merchants.data?.merchants.map((m) => (
                  <MerchantCard key={m.id} merchant={m} />
                ))}
              </div>
            </section>

            <section>
              <h2 className="text-base font-semibold text-(--color-ink)">Produk</h2>
              {products.isLoading && <p className="pt-2 text-xs text-(--color-ink-faint)">Mencari...</p>}
              {products.data && products.data.products.length === 0 && (
                <p className="pt-2 text-xs text-(--color-ink-faint)">Tidak ada produk ditemukan.</p>
              )}
              <div className="mt-3 flex flex-wrap gap-3 pb-1 md:grid md:grid-cols-3 lg:grid-cols-4">
                {products.data?.products.map((p) => (
                  <ProductCard key={p.id} product={p} />
                ))}
              </div>
            </section>
          </div>
        )}
      </div>
    </div>
  );
}

export default function SearchPage() {
  return (
    <AuthGuard>
      <SearchContent />
    </AuthGuard>
  );
}
