"use client";

import { useMemo, useState } from "react";
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
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/40" onClick={onClose}>
      <div
        className="mx-auto flex max-h-[85vh] w-full max-w-(--shell-width) flex-col overflow-hidden rounded-t-2xl bg-white"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
          <p className="text-base font-bold text-gray-800">{product.name}</p>
          <button onClick={onClose} className="text-xl text-gray-400">
            ✕
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-4 py-3">
          {product.description && <p className="mb-3 text-sm text-gray-500">{product.description}</p>}
          <p className="mb-4 text-base font-bold text-emerald-600">{formatIDR(basePrice)}</p>

          {groups.map(([groupName, options]) => {
            const maxSelect = options[0]?.max_select ?? 1;
            const required = options[0]?.is_required;
            return (
              <div key={groupName} className="mb-4">
                <div className="mb-1.5 flex items-center justify-between">
                  <p className="text-sm font-semibold text-gray-800">{groupName}</p>
                  {required && <span className="text-xs text-red-500">Wajib pilih</span>}
                </div>
                <div className="flex flex-col gap-1.5">
                  {options.map((opt) => {
                    const checked = (selected[groupName] ?? []).includes(opt.id);
                    return (
                      <label
                        key={opt.id}
                        className={`flex items-center justify-between rounded-lg border px-3 py-2 text-sm ${
                          checked ? "border-emerald-500 bg-emerald-50" : "border-gray-200"
                        }`}
                      >
                        <span className="flex items-center gap-2">
                          <input
                            type={maxSelect <= 1 ? "radio" : "checkbox"}
                            checked={checked}
                            onChange={() => toggleOption(groupName, opt, maxSelect)}
                          />
                          {opt.name}
                        </span>
                        {opt.price > 0 && <span className="text-gray-500">+{formatIDR(opt.price)}</span>}
                      </label>
                    );
                  })}
                </div>
              </div>
            );
          })}

          <div className="mb-4">
            <p className="mb-1.5 text-sm font-semibold text-gray-800">Catatan</p>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Contoh: tidak pedas"
              rows={2}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
            />
          </div>
        </div>

        <div className="flex items-center gap-3 border-t border-gray-100 px-4 py-3">
          <div className="flex items-center gap-3 rounded-full border border-gray-200 px-3 py-1.5">
            <button onClick={() => setQuantity((q) => Math.max(1, q - 1))} className="text-lg text-gray-600">
              −
            </button>
            <span className="w-4 text-center text-sm font-semibold">{quantity}</span>
            <button onClick={() => setQuantity((q) => q + 1)} className="text-lg text-gray-600">
              +
            </button>
          </div>
          <button
            disabled={missingRequired}
            onClick={() => {
              addItem(merchantId, merchantName, product, selectedVariants, quantity, notes);
              onClose();
            }}
            className="flex-1 rounded-full bg-emerald-600 py-2.5 text-sm font-semibold text-white disabled:opacity-50"
          >
            Tambah · {formatIDR(totalPrice)}
          </button>
        </div>
      </div>
    </div>
  );
}
