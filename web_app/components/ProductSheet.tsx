"use client";

import { useMemo, useState } from "react";
import { HugeiconsIcon } from "@hugeicons/react";
import { Cancel01Icon, MinusSignIcon, PlusSignIcon } from "@hugeicons/core-free-icons";
import { formatIDR } from "@/lib/format";
import { useCartStore } from "@/lib/stores/cart";
import type { Product, ProductVariant } from "@/lib/api/types";

interface Props {
  product: Product;
  merchantId: string;
  merchantName: string;
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

export function ProductSheet({ product, merchantId, merchantName, onClose }: Props) {
  const addItem = useCartStore((s) => s.addItem);
  const [selected, setSelected] = useState<Record<string, string[]>>({});
  const [quantity, setQuantity] = useState(1);
  const [notes, setNotes] = useState("");

  const groups = useMemo(() => groupVariants(product.variants ?? []), [product.variants]);
  const basePrice = product.discount_price && product.discount_price > 0 ? product.discount_price : product.price;

  const selectedVariantIds = Object.values(selected).flat();
  const selectedVariants = (product.variants ?? []).filter((v) => selectedVariantIds.includes(v.id));
  const totalPrice = (basePrice + selectedVariants.reduce((s, v) => s + v.price, 0)) * quantity;

  const missingRequired = groups.some(([groupName, options]) => {
    const required = options[0]?.is_required;
    if (!required) return false;
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

  return (
    <div
      className="fixed inset-0 z-40 flex items-end justify-center bg-(--color-ink)/45 md:items-center md:p-6"
      onClick={onClose}
    >
      <div
        className="mx-auto flex max-h-[85vh] w-full max-w-lg flex-col overflow-hidden rounded-t-3xl bg-(--color-surface-raised) md:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-(--color-border) px-5 py-4">
          <p className="text-base font-semibold text-(--color-ink)">{product.name}</p>
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full text-(--color-ink-faint) hover:bg-(--color-border-soft)"
            aria-label="Tutup"
          >
            <HugeiconsIcon icon={Cancel01Icon} size={18} strokeWidth={1.5} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4">
          {product.description && <p className="mb-3 text-sm text-(--color-ink-soft)">{product.description}</p>}
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
                          checked
                            ? "border-(--color-accent) bg-(--color-accent-soft)"
                            : "border-(--color-border)"
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

          <div className="mb-2">
            <p className="mb-2 text-sm font-medium text-(--color-ink)">Catatan</p>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Contoh: tidak pedas"
              rows={2}
              className="w-full rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </div>
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
            onClick={() => {
              addItem(merchantId, merchantName, product, selectedVariants, quantity, notes);
              onClose();
            }}
            className="flex-1 rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
          >
            Tambah · {formatIDR(totalPrice)}
          </button>
        </div>
      </div>
    </div>
  );
}
