"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { AuthGuard } from "@/components/AuthGuard";
import { useCartStore, cartSubtotal } from "@/lib/stores/cart";
import { formatIDR } from "@/lib/format";

function CartContent() {
  const router = useRouter();
  const { merchantName, lines, updateQuantity, removeItem, clear } = useCartStore();
  const subtotal = cartSubtotal(lines);

  return (
    <div className="pb-24">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Keranjang</p>
      </header>

      {lines.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-20">
          <p className="text-4xl">🛒</p>
          <p className="text-sm text-gray-500">Keranjang kamu masih kosong</p>
          <Link href="/" className="rounded-full bg-emerald-600 px-5 py-2 text-sm font-semibold text-white">
            Mulai Belanja
          </Link>
        </div>
      ) : (
        <div className="px-4 py-3">
          <div className="mb-3 flex items-center justify-between">
            <p className="text-sm font-semibold text-gray-800">{merchantName}</p>
            <button onClick={clear} className="text-xs text-red-500">
              Kosongkan
            </button>
          </div>

          <div className="flex flex-col gap-2">
            {lines.map((line) => (
              <div key={line.key} className="flex items-start gap-3 rounded-xl border border-gray-100 p-3">
                <div className="h-14 w-14 flex-shrink-0 overflow-hidden rounded-lg bg-gray-100">
                  {line.imageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={line.imageUrl} alt={line.name} className="h-full w-full object-cover" />
                  ) : (
                    <div className="flex h-full items-center justify-center text-xl">🍽️</div>
                  )}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-gray-800">{line.name}</p>
                  {line.variantLabel && <p className="text-xs text-gray-500">{line.variantLabel}</p>}
                  {line.notes && <p className="text-xs italic text-gray-400">&quot;{line.notes}&quot;</p>}
                  <div className="mt-2 flex items-center justify-between">
                    <p className="text-sm font-bold text-gray-800">{formatIDR(line.unitPrice * line.quantity)}</p>
                    <div className="flex items-center gap-2 rounded-full border border-gray-200 px-2 py-1">
                      <button
                        onClick={() => updateQuantity(line.key, line.quantity - 1)}
                        className="text-base text-gray-600"
                      >
                        −
                      </button>
                      <span className="w-4 text-center text-sm font-semibold">{line.quantity}</span>
                      <button
                        onClick={() => updateQuantity(line.key, line.quantity + 1)}
                        className="text-base text-gray-600"
                      >
                        +
                      </button>
                    </div>
                  </div>
                </div>
                <button onClick={() => removeItem(line.key)} className="text-gray-300">
                  ✕
                </button>
              </div>
            ))}
          </div>

          <div className="fixed bottom-16 left-0 right-0 z-20 mx-auto max-w-[480px] border-t border-gray-100 bg-white px-4 py-3">
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="text-gray-500">Subtotal</span>
              <span className="font-bold text-gray-800">{formatIDR(subtotal)}</span>
            </div>
            <button
              onClick={() => router.push("/checkout")}
              className="w-full rounded-full bg-emerald-600 py-3 text-sm font-semibold text-white"
            >
              Lanjut ke Checkout
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default function CartPage() {
  return (
    <AuthGuard>
      <CartContent />
    </AuthGuard>
  );
}
