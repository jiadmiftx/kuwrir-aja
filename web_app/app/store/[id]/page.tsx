"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, StarIcon, PlusSignIcon, RiceBowl01Icon } from "@hugeicons/core-free-icons";
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
      <div className="relative h-44 w-full bg-(--color-border-soft) md:h-64">
        {m?.banner_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={m.banner_url} alt={m.name} className="h-full w-full object-cover" />
        )}
        <button
          onClick={() => router.back()}
          className="absolute left-4 top-4 flex h-9 w-9 items-center justify-center rounded-full bg-(--color-surface-raised)/90 text-(--color-ink) shadow-sm backdrop-blur"
          aria-label="Kembali"
        >
          <HugeiconsIcon icon={ArrowLeft01Icon} size={19} strokeWidth={1.5} />
        </button>
      </div>

      <div className="mx-auto max-w-(--content-width) px-4 md:px-8">
        {m && (
          <div className="py-4">
            <div className="flex items-start gap-3.5">
              {m.logo_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={m.logo_url}
                  alt={m.name}
                  className="h-16 w-16 shrink-0 rounded-2xl border border-(--color-border) object-cover"
                />
              )}
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-lg font-semibold text-(--color-ink)">{m.name}</p>
                  {!m.is_open && (
                    <span className="rounded-md bg-(--color-border-soft) px-1.5 py-0.5 text-[10px] font-medium text-(--color-ink-soft)">
                      Tutup
                    </span>
                  )}
                </div>
                <p className="text-xs text-(--color-ink-faint)">{m.address}</p>
                <div className="mt-1.5 flex items-center gap-1.5 text-xs text-(--color-ink-soft)">
                  <HugeiconsIcon icon={StarIcon} size={13} strokeWidth={1.5} className="text-(--color-warning)" />
                  <span>{m.rating.toFixed(1)}</span>
                  <span className="text-(--color-ink-faint)">({m.total_reviews} ulasan)</span>
                  {m.is_free_delivery && <span className="text-(--color-accent)">· Gratis Ongkir</span>}
                </div>
              </div>
            </div>
            {m.description && <p className="mt-3 text-sm text-(--color-ink-soft)">{m.description}</p>}
          </div>
        )}

        <div className="flex flex-col gap-7">
          {products.data?.categories.map((cat) => (
            <section key={cat.id}>
              <h2 className="mb-3 text-base font-semibold text-(--color-ink)">{cat.name}</h2>
              <div className="flex flex-col gap-2.5 md:grid md:grid-cols-2 lg:grid-cols-3">
                {cat.products.map((p) => {
                  const hasDiscount = !!p.discount_price && p.discount_price > 0;
                  return (
                    <button
                      key={p.id}
                      onClick={() => setSelectedProduct(p)}
                      className="flex items-center gap-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-2.5 text-left transition-shadow hover:shadow-md"
                    >
                      <div className="h-16 w-16 shrink-0 overflow-hidden rounded-xl bg-(--color-border-soft)">
                        {p.image_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={p.image_url} alt={p.name} className="h-full w-full object-cover" />
                        ) : (
                          <div className="flex h-full items-center justify-center text-(--color-ink-faint)">
                            <HugeiconsIcon icon={RiceBowl01Icon} size={22} strokeWidth={1.5} />
                          </div>
                        )}
                      </div>
                      <div className="flex-1">
                        <p className="text-sm font-medium text-(--color-ink)">{p.name}</p>
                        {p.description && (
                          <p className="line-clamp-1 text-xs text-(--color-ink-faint)">{p.description}</p>
                        )}
                        {hasDiscount ? (
                          <div className="mt-1 flex items-center gap-1.5">
                            <span className="text-sm font-semibold text-(--color-accent)">
                              {formatIDR(p.discount_price!)}
                            </span>
                            <span className="text-xs text-(--color-ink-faint) line-through">{formatIDR(p.price)}</span>
                          </div>
                        ) : (
                          <p className="mt-1 text-sm font-semibold text-(--color-ink)">{formatIDR(p.price)}</p>
                        )}
                      </div>
                      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-(--color-accent-soft) text-(--color-accent)">
                        <HugeiconsIcon icon={PlusSignIcon} size={16} strokeWidth={1.5} />
                      </span>
                    </button>
                  );
                })}
              </div>
            </section>
          ))}
          {products.data && products.data.categories.length === 0 && (
            <p className="py-8 text-center text-sm text-(--color-ink-faint)">Belum ada produk di toko ini.</p>
          )}
        </div>
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
