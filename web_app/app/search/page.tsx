"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
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
    <div className="pb-4">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <form
          className="flex-1"
          onSubmit={(e) => {
            e.preventDefault();
            setSubmitted(query.trim());
          }}
        >
          <input
            autoFocus
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Cari toko atau produk..."
            className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 text-sm outline-none focus:border-emerald-500"
          />
        </form>
      </header>

      {submitted === "" && <p className="mt-10 text-center text-sm text-gray-400">Ketik untuk mencari toko atau produk</p>}

      {submitted !== "" && (
        <div className="mt-4 flex flex-col gap-6">
          <section>
            <h2 className="px-4 text-sm font-bold text-gray-800">Toko</h2>
            {merchants.isLoading && <p className="px-4 pt-2 text-xs text-gray-400">Mencari...</p>}
            {merchants.data && merchants.data.merchants.length === 0 && (
              <p className="px-4 pt-2 text-xs text-gray-400">Tidak ada toko ditemukan.</p>
            )}
            <div className="mt-2 flex gap-3 overflow-x-auto px-4 pb-1">
              {merchants.data?.merchants.map((m) => (
                <MerchantCard key={m.id} merchant={m} />
              ))}
            </div>
          </section>

          <section>
            <h2 className="px-4 text-sm font-bold text-gray-800">Produk</h2>
            {products.isLoading && <p className="px-4 pt-2 text-xs text-gray-400">Mencari...</p>}
            {products.data && products.data.products.length === 0 && (
              <p className="px-4 pt-2 text-xs text-gray-400">Tidak ada produk ditemukan.</p>
            )}
            <div className="mt-2 flex flex-wrap gap-3 px-4 pb-1">
              {products.data?.products.map((p) => (
                <ProductCard key={p.id} product={p} />
              ))}
            </div>
          </section>
        </div>
      )}
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
