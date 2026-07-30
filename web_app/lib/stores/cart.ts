import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Product, ProductVariant } from "@/lib/api/types";

export interface CartLine {
  key: string; // product.id + sorted variant ids, so distinct variant picks stay separate lines
  productId: string;
  name: string;
  imageUrl?: string;
  unitPrice: number; // product price (with markup) + sum of selected variant prices
  packagingFee: number;
  quantity: number;
  notes: string;
  variantIds: string[];
  variantLabel: string; // human-readable summary, e.g. "Large, Extra Cheese"
}

interface CartState {
  merchantId: string | null;
  merchantName: string | null;
  lines: CartLine[];
  addItem: (
    merchantId: string,
    merchantName: string,
    product: Product,
    selectedVariants: ProductVariant[],
    quantity: number,
    notes: string
  ) => void;
  updateQuantity: (key: string, quantity: number) => void;
  removeItem: (key: string) => void;
  clear: () => void;
}

function lineKey(productId: string, variantIds: string[]) {
  return `${productId}:${[...variantIds].sort().join(",")}`;
}

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      merchantId: null,
      merchantName: null,
      lines: [],
      addItem: (merchantId, merchantName, product, selectedVariants, quantity, notes) => {
        const state = get();
        // Single-store cart rule: adding from a different merchant replaces the cart.
        if (state.merchantId && state.merchantId !== merchantId) {
          set({ merchantId, merchantName, lines: [] });
        }
        const variantIds = selectedVariants.map((v) => v.id);
        const key = lineKey(product.id, variantIds);
        const basePrice = product.discount_price && product.discount_price > 0 ? product.discount_price : product.price;
        const unitPrice = basePrice + selectedVariants.reduce((sum, v) => sum + v.price, 0);
        const variantLabel = selectedVariants.map((v) => v.name).join(", ");

        set((s) => {
          const existing = s.lines.find((l) => l.key === key);
          if (existing) {
            return {
              merchantId,
              merchantName,
              lines: s.lines.map((l) =>
                l.key === key ? { ...l, quantity: l.quantity + quantity, notes: notes || l.notes } : l
              ),
            };
          }
          return {
            merchantId,
            merchantName,
            lines: [
              ...s.lines,
              {
                key,
                productId: product.id,
                name: product.name,
                imageUrl: product.image_url,
                unitPrice,
                packagingFee: product.packaging_fee,
                quantity,
                notes,
                variantIds,
                variantLabel,
              },
            ],
          };
        });
      },
      updateQuantity: (key, quantity) =>
        set((s) => ({
          lines:
            quantity <= 0
              ? s.lines.filter((l) => l.key !== key)
              : s.lines.map((l) => (l.key === key ? { ...l, quantity } : l)),
        })),
      removeItem: (key) => set((s) => ({ lines: s.lines.filter((l) => l.key !== key) })),
      clear: () => set({ merchantId: null, merchantName: null, lines: [] }),
    }),
    { name: "kuwrir-cart" }
  )
);

export function cartSubtotal(lines: CartLine[]) {
  return lines.reduce((sum, l) => sum + (l.unitPrice + l.packagingFee) * l.quantity, 0);
}

export function cartItemCount(lines: CartLine[]) {
  return lines.reduce((sum, l) => sum + l.quantity, 0);
}
