import Link from "next/link";
import { HugeiconsIcon } from "@hugeicons/react";
import { RiceBowl01Icon } from "@hugeicons/core-free-icons";
import { formatIDR } from "@/lib/format";
import type { ProductSearchItem } from "@/lib/api/types";

export function ProductCard({ product }: { product: ProductSearchItem }) {
  const hasDiscount = !!product.discount_price && product.discount_price > 0;
  return (
    <Link
      href={`/store/${product.merchant_id}`}
      className="group flex min-w-[156px] max-w-[156px] flex-col gap-1.5 rounded-[20px] border border-(--color-border) bg-(--color-surface-raised) p-2.5 shadow-[0_4px_14px_-6px_rgba(0,0,0,0.1)] transition-shadow hover:shadow-[0_8px_20px_-6px_rgba(0,0,0,0.16)] md:min-w-0 md:max-w-none md:w-full"
    >
      <div className="relative aspect-square w-full overflow-hidden rounded-xl bg-(--color-border-soft)">
        {product.image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={product.image_url}
            alt={product.name}
            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-(--color-ink-faint)">
            <HugeiconsIcon icon={RiceBowl01Icon} size={26} strokeWidth={1.5} />
          </div>
        )}
      </div>
      <p className="truncate text-sm font-medium text-(--color-ink)">{product.name}</p>
      <p className="truncate text-xs text-(--color-ink-faint)">{product.merchant_name}</p>
      {hasDiscount ? (
        <div className="flex items-center gap-1.5">
          <span className="text-sm font-semibold text-(--color-accent)">{formatIDR(product.discount_price!)}</span>
          <span className="text-xs text-(--color-ink-faint) line-through">{formatIDR(product.price)}</span>
        </div>
      ) : (
        <span className="text-sm font-semibold text-(--color-ink)">{formatIDR(product.price)}</span>
      )}
    </Link>
  );
}
