"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, Cancel01Icon, MinusSignIcon, PlusSignIcon, RiceBowl01Icon } from "@hugeicons/core-free-icons";
import { getMerchantProducts } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import type { Product, ProductVariant } from "@/lib/api/types";

interface Picked {
  product: Product;
  variants: ProductVariant[];
  quantity: number;
  estimatedTotal: number;
}

interface Props {
  merchantId: string;
  onConfirm: (picked: Picked) => void;
  onClose: () => void;
}

function groupVariants(variants: ProductVariant[]) {
  const groups = new Map<string, ProductVariant[]>();
  for (const v of variants) {
    if (!groups.has(v.group_name)) groups.set(v.group_name, []);
    groups.get(v.group_name)!.push(v);
  }
  return Array.from(groups.entries());
}

/// Free-browse replacement picker over the merchant's live menu — the
/// customer isn't limited to a merchant-suggested shortlist. Fetches the
/// same /merchants/:id/products endpoint the normal store page uses, but
/// hands the pick back to the caller instead of adding to the cart.
export function ReplacementPickerSheet({ merchantId, onConfirm, onClose }: Props) {
  const products = useQuery({
    queryKey: ["merchant-products", merchantId],
    queryFn: () => getMerchantProducts(merchantId),
  });
  const [product, setProduct] = useState<Product | null>(null);
  const [selected, setSelected] = useState<Record<string, string[]>>({});
  const [quantity, setQuantity] = useState(1);

  const groups = useMemo(() => groupVariants(product?.variants ?? []), [product]);
  const basePrice = product ? (product.discount_price && product.discount_price > 0 ? product.discount_price : product.price) : 0;
  const selectedVariantIds = Object.values(selected).flat();
  const selectedVariants = (product?.variants ?? []).filter((v) => selectedVariantIds.includes(v.id));
  const totalPrice = (basePrice + selectedVariants.reduce((s, v) => s + v.price, 0)) * quantity;
  const missingRequired = groups.some(([groupName, options]) => {
    if (!options[0]?.is_required) return false;
    return (selected[groupName]?.length ?? 0) === 0;
  });

  function toggleOption(groupName: string, option: ProductVariant, maxSelect: number) {
    setSelected((prev) => {
      const current = prev[groupName] ?? [];
      if (maxSelect <= 1) {
        return { ...prev, [groupName]: current.includes(option.id) ? [] : [option.id] };
      }
      if (current.includes(option.id)) {
        return { ...prev, [groupName]: current.filter((id) => id !== option.id) };
      }
      if (current.length >= maxSelect) return prev;
      return { ...prev, [groupName]: [...current, option.id] };
    });
  }

  function pick(p: Product) {
    if (!p.variants || p.variants.length === 0) {
      const price = p.discount_price && p.discount_price > 0 ? p.discount_price : p.price;
      onConfirm({ product: p, variants: [], quantity: 1, estimatedTotal: price });
      return;
    }
    setProduct(p);
    setSelected({});
    setQuantity(1);
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-(--color-ink)/45 md:items-center md:p-6" onClick={onClose}>
      <div
        className="mx-auto flex max-h-[85vh] w-full max-w-lg flex-col overflow-hidden rounded-t-3xl bg-(--color-surface-raised) md:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-(--color-border) px-5 py-4">
          <div className="flex items-center gap-2">
            {product && (
              <button
                onClick={() => setProduct(null)}
                className="flex h-8 w-8 items-center justify-center rounded-full text-(--color-ink-faint) hover:bg-(--color-border-soft)"
                aria-label="Kembali"
              >
                <HugeiconsIcon icon={ArrowLeft01Icon} size={18} strokeWidth={1.5} />
              </button>
            )}
            <p className="text-base font-semibold text-(--color-ink)">{product ? product.name : "Pilih Pengganti"}</p>
          </div>
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full text-(--color-ink-faint) hover:bg-(--color-border-soft)"
            aria-label="Tutup"
          >
            <HugeiconsIcon icon={Cancel01Icon} size={18} strokeWidth={1.5} />
          </button>
        </div>

        {!product ? (
          <div className="flex-1 overflow-y-auto px-5 py-4">
            {products.data?.categories.map((cat) => (
              <section key={cat.id} className="mb-6">
                <h3 className="mb-2.5 text-sm font-semibold text-(--color-ink)">{cat.name}</h3>
                <div className="flex flex-col gap-2">
                  {cat.products
                    .filter((p) => p.is_available)
                    .map((p) => {
                      const hasDiscount = !!p.discount_price && p.discount_price > 0;
                      return (
                        <button
                          key={p.id}
                          onClick={() => pick(p)}
                          className="flex items-center gap-3 rounded-2xl border border-(--color-border) p-2.5 text-left transition-shadow hover:shadow-md"
                        >
                          <div className="h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-(--color-border-soft)">
                            {p.image_url ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={p.image_url} alt={p.name} className="h-full w-full object-cover" />
                            ) : (
                              <div className="flex h-full items-center justify-center text-(--color-ink-faint)">
                                <HugeiconsIcon icon={RiceBowl01Icon} size={20} strokeWidth={1.5} />
                              </div>
                            )}
                          </div>
                          <div className="flex-1">
                            <p className="text-sm font-medium text-(--color-ink)">{p.name}</p>
                            {hasDiscount ? (
                              <div className="mt-0.5 flex items-center gap-1.5">
                                <span className="text-sm font-semibold text-(--color-accent)">
                                  {formatIDR(p.discount_price!)}
                                </span>
                                <span className="text-xs text-(--color-ink-faint) line-through">{formatIDR(p.price)}</span>
                              </div>
                            ) : (
                              <p className="mt-0.5 text-sm font-semibold text-(--color-ink)">{formatIDR(p.price)}</p>
                            )}
                          </div>
                        </button>
                      );
                    })}
                </div>
              </section>
            ))}
            {products.data && products.data.categories.length === 0 && (
              <p className="py-8 text-center text-sm text-(--color-ink-faint)">Menu tidak tersedia.</p>
            )}
          </div>
        ) : (
          <>
            <div className="flex-1 overflow-y-auto px-5 py-4">
              <p className="mb-5 text-base font-semibold text-(--color-accent)">{formatIDR(basePrice)}</p>
              {groups.map(([groupName, options]) => {
                const maxSelect = options[0]?.max_select ?? 1;
                const required = options[0]?.is_required;
                return (
                  <div key={groupName} className="mb-5">
                    <div className="mb-2 flex items-center justify-between">
                      <p className="text-sm font-medium text-(--color-ink)">{groupName}</p>
                      {required && <span className="text-xs text-(--color-danger)">Wajib pilih</span>}
                    </div>
                    <div className="flex flex-col gap-1.5">
                      {options.map((opt) => {
                        const checked = (selected[groupName] ?? []).includes(opt.id);
                        return (
                          <label
                            key={opt.id}
                            className={`flex items-center justify-between rounded-xl border px-3.5 py-2.5 text-sm transition-colors ${
                              checked ? "border-(--color-accent) bg-(--color-accent-soft)" : "border-(--color-border)"
                            }`}
                          >
                            <span className="flex items-center gap-2.5 text-(--color-ink)">
                              <input
                                type={maxSelect <= 1 ? "radio" : "checkbox"}
                                checked={checked}
                                onChange={() => toggleOption(groupName, opt, maxSelect)}
                                className="accent-(--color-accent)"
                              />
                              {opt.name}
                            </span>
                            {opt.price > 0 && <span className="text-(--color-ink-faint)">+{formatIDR(opt.price)}</span>}
                          </label>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="flex items-center gap-3 border-t border-(--color-border) px-5 py-4">
              <div className="flex items-center gap-3 rounded-full border border-(--color-border) px-2.5 py-1.5">
                <button
                  onClick={() => setQuantity((q) => Math.max(1, q - 1))}
                  className="flex h-6 w-6 items-center justify-center text-(--color-ink-soft)"
                  aria-label="Kurangi"
                >
                  <HugeiconsIcon icon={MinusSignIcon} size={15} strokeWidth={1.5} />
                </button>
                <span className="w-4 text-center text-sm font-semibold text-(--color-ink)">{quantity}</span>
                <button
                  onClick={() => setQuantity((q) => q + 1)}
                  className="flex h-6 w-6 items-center justify-center text-(--color-ink-soft)"
                  aria-label="Tambah"
                >
                  <HugeiconsIcon icon={PlusSignIcon} size={15} strokeWidth={1.5} />
                </button>
              </div>
              <button
                disabled={missingRequired}
                onClick={() =>
                  onConfirm({ product, variants: selectedVariants, quantity, estimatedTotal: totalPrice })
                }
                className="flex-1 rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
              >
                Pilih · {formatIDR(totalPrice)}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
