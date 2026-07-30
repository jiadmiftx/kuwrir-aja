import Link from "next/link";
import { formatIDR } from "@/lib/format";
import type { ProductSearchItem } from "@/lib/api/types";

export function ProductCard({ product }: { product: ProductSearchItem }) {
  const hasDiscount = !!product.discount_price && product.discount_price > 0;
  return (
    <Link
      href={`/store/${product.merchant_id}`}
      className="flex min-w-[150px] max-w-[150px] flex-col gap-1 rounded-xl border border-gray-100 bg-white p-2 shadow-sm"
    >
      <div className="relative aspect-square w-full overflow-hidden rounded-lg bg-gray-100">
        {product.image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={product.image_url} alt={product.name} className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full items-center justify-center text-2xl">🍱</div>
        )}
      </div>
      <p className="truncate text-sm font-medium text-gray-800">{product.name}</p>
      <p className="truncate text-xs text-gray-500">{product.merchant_name}</p>
      {hasDiscount ? (
        <div className="flex items-center gap-1.5">
          <span className="text-sm font-semibold text-emerald-600">{formatIDR(product.discount_price!)}</span>
          <span className="text-xs text-gray-400 line-through">{formatIDR(product.price)}</span>
        </div>
      ) : (
        <span className="text-sm font-semibold text-gray-800">{formatIDR(product.price)}</span>
      )}
    </Link>
  );
}
