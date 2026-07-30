"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, ShoppingBag02Icon, RiceBowl01Icon, MinusSignIcon, PlusSignIcon, Delete02Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { useCartStore, cartSubtotal } from "@/lib/stores/cart";
import { formatIDR } from "@/lib/format";

function CartContent() {
  const router = useRouter();
  const { merchantName, lines, updateQuantity, removeItem, clear } = useCartStore();
  const subtotal = cartSubtotal(lines);

  return (
    <div className="pb-28">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-(--content-width) md:border-none md:bg-transparent md:px-8 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Keranjang</p>
      </div>

      {lines.length === 0 ? (
        <div className="flex flex-col items-center gap-4 py-24">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-(--color-border-soft) text-(--color-ink-faint)">
            <HugeiconsIcon icon={ShoppingBag02Icon} size={28} strokeWidth={1.5} />
          </div>
          <p className="text-sm text-(--color-ink-soft)">Keranjang kamu masih kosong</p>
          <Link
            href="/"
            className="rounded-full bg-(--color-accent) px-5 py-2.5 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
          >
            Mulai Belanja
          </Link>
        </div>
      ) : (
        <div className="mx-auto max-w-(--content-width) px-4 py-4 md:px-8">
          <div className="mb-3 flex items-center justify-between">
            <p className="text-sm font-medium text-(--color-ink)">{merchantName}</p>
            <button onClick={clear} className="text-xs font-medium text-(--color-danger)">
              Kosongkan
            </button>
          </div>

          <div className="flex flex-col gap-2.5 md:max-w-2xl">
            {lines.map((line) => (
              <div key={line.key} className="flex items-start gap-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-3">
                <div className="h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-(--color-border-soft)">
                  {line.imageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={line.imageUrl} alt={line.name} className="h-full w-full object-cover" />
                  ) : (
                    <div className="flex h-full items-center justify-center text-(--color-ink-faint)">
                      <HugeiconsIcon icon={RiceBowl01Icon} size={20} strokeWidth={1.5} />
                    </div>
                  )}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-(--color-ink)">{line.name}</p>
                  {line.variantLabel && <p className="text-xs text-(--color-ink-faint)">{line.variantLabel}</p>}
                  {line.notes && <p className="text-xs italic text-(--color-ink-faint)">&quot;{line.notes}&quot;</p>}
                  <div className="mt-2 flex items-center justify-between">
                    <p className="text-sm font-semibold text-(--color-ink)">{formatIDR(line.unitPrice * line.quantity)}</p>
                    <div className="flex items-center gap-2.5 rounded-full border border-(--color-border) px-2 py-1">
                      <button
                        onClick={() => updateQuantity(line.key, line.quantity - 1)}
                        className="flex h-5 w-5 items-center justify-center text-(--color-ink-soft)"
                        aria-label="Kurangi"
                      >
                        <HugeiconsIcon icon={MinusSignIcon} size={13} strokeWidth={1.5} />
                      </button>
                      <span className="w-4 text-center text-sm font-semibold text-(--color-ink)">{line.quantity}</span>
                      <button
                        onClick={() => updateQuantity(line.key, line.quantity + 1)}
                        className="flex h-5 w-5 items-center justify-center text-(--color-ink-soft)"
                        aria-label="Tambah"
                      >
                        <HugeiconsIcon icon={PlusSignIcon} size={13} strokeWidth={1.5} />
                      </button>
                    </div>
                  </div>
                </div>
                <button onClick={() => removeItem(line.key)} className="text-(--color-ink-faint) hover:text-(--color-danger)" aria-label="Hapus">
                  <HugeiconsIcon icon={Delete02Icon} size={17} strokeWidth={1.5} />
                </button>
              </div>
            ))}
          </div>

          <div className="fixed bottom-16 left-0 right-0 z-20 mx-auto max-w-2xl border-t border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mt-6 md:max-w-2xl md:rounded-2xl md:border md:px-5">
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="text-(--color-ink-faint)">Subtotal</span>
              <span className="font-semibold text-(--color-ink)">{formatIDR(subtotal)}</span>
            </div>
            <button
              onClick={() => router.push("/checkout")}
              className="w-full rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
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
