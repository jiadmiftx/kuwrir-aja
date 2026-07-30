"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard } from "@/components/AuthGuard";
import { getMerchant, getMerchantProducts } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { ProductSheet } from "@/components/ProductSheet";
import type { Product } from "@/lib/api/types";

function StoreContent() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const merchantId = params.id;

  const merchant = useQuery({ queryKey: ["merchant", merchantId], queryFn: () => getMerchant(merchantId) });
  const products = useQuery({
    queryKey: ["merchant-products", merchantId],
    queryFn: () => getMerchantProducts(merchantId),
  });

  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);

  const m = merchant.data?.merchant;

  return (
    <div className="pb-6">
      <div className="relative h-40 w-full bg-gray-200">
        {m?.banner_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={m.banner_url} alt={m.name} className="h-full w-full object-cover" />
        )}
        <button
          onClick={() => router.back()}
          className="absolute left-3 top-3 flex h-9 w-9 items-center justify-center rounded-full bg-white/90 text-lg shadow"
        >
          ←
        </button>
      </div>

      {m && (
        <div className="px-4 py-3">
          <div className="flex items-start gap-3">
            {m.logo_url && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={m.logo_url} alt={m.name} className="h-14 w-14 rounded-xl border border-gray-100 object-cover" />
            )}
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <p className="text-lg font-bold text-gray-800">{m.name}</p>
                {!m.is_open && (
                  <span className="rounded bg-gray-200 px-1.5 py-0.5 text-[10px] font-semibold text-gray-600">
                    Tutup
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-500">{m.address}</p>
              <div className="mt-1 flex items-center gap-2 text-xs text-gray-500">
                <span>⭐ {m.rating.toFixed(1)}</span>
                <span>({m.total_reviews} ulasan)</span>
                {m.is_free_delivery && <span className="text-emerald-600">Gratis Ongkir</span>}
              </div>
            </div>
          </div>
          {m.description && <p className="mt-2 text-sm text-gray-600">{m.description}</p>}
        </div>
      )}

      <div className="mt-2 flex flex-col gap-5 px-4">
        {products.data?.categories.map((cat) => (
          <section key={cat.id}>
            <h2 className="mb-2 text-sm font-bold text-gray-800">{cat.name}</h2>
            <div className="flex flex-col gap-2">
              {cat.products.map((p) => {
                const hasDiscount = !!p.discount_price && p.discount_price > 0;
                return (
                  <button
                    key={p.id}
                    onClick={() => setSelectedProduct(p)}
                    className="flex items-center gap-3 rounded-xl border border-gray-100 p-2.5 text-left shadow-sm"
                  >
                    <div className="h-16 w-16 flex-shrink-0 overflow-hidden rounded-lg bg-gray-100">
                      {p.image_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={p.image_url} alt={p.name} className="h-full w-full object-cover" />
                      ) : (
                        <div className="flex h-full items-center justify-center text-xl">🍽️</div>
                      )}
                    </div>
                    <div className="flex-1">
                      <p className="text-sm font-semibold text-gray-800">{p.name}</p>
                      {p.description && <p className="line-clamp-1 text-xs text-gray-500">{p.description}</p>}
                      {hasDiscount ? (
                        <div className="mt-1 flex items-center gap-1.5">
                          <span className="text-sm font-bold text-emerald-600">{formatIDR(p.discount_price!)}</span>
                          <span className="text-xs text-gray-400 line-through">{formatIDR(p.price)}</span>
                        </div>
                      ) : (
                        <p className="mt-1 text-sm font-bold text-gray-800">{formatIDR(p.price)}</p>
                      )}
                    </div>
                    <span className="text-2xl text-emerald-600">+</span>
                  </button>
                );
              })}
            </div>
          </section>
        ))}
        {products.data && products.data.categories.length === 0 && (
          <p className="py-8 text-center text-sm text-gray-400">Belum ada produk di toko ini.</p>
        )}
      </div>

      {selectedProduct && m && (
        <ProductSheet
          product={selectedProduct}
          merchantId={m.id}
          merchantName={m.name}
          onClose={() => setSelectedProduct(null)}
        />
      )}
    </div>
  );
}

export default function StorePage() {
  return (
    <AuthGuard>
      <StoreContent />
    </AuthGuard>
  );
}
