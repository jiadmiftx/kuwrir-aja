import Link from "next/link";
import type { Merchant } from "@/lib/api/types";

export function MerchantCard({ merchant }: { merchant: Merchant }) {
  return (
    <Link
      href={`/store/${merchant.id}`}
      className="flex min-w-[160px] max-w-[160px] flex-col gap-1.5 rounded-xl border border-gray-100 bg-white p-2 shadow-sm md:min-w-0 md:max-w-none md:w-full"
    >
      <div className="relative aspect-square w-full overflow-hidden rounded-lg bg-gray-100">
        {merchant.logo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={merchant.logo_url} alt={merchant.name} className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full items-center justify-center text-2xl">🍽️</div>
        )}
        {!merchant.is_open && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/50 text-xs font-semibold text-white">
            Tutup
          </div>
        )}
      </div>
      <p className="truncate text-sm font-semibold text-gray-800">{merchant.name}</p>
      <div className="flex items-center gap-1 text-xs text-gray-500">
        <span>⭐ {merchant.rating.toFixed(1)}</span>
        {typeof merchant.distance_km === "number" && <span>· {merchant.distance_km.toFixed(1)} km</span>}
        {merchant.is_free_delivery && <span className="text-emerald-600">· Gratis Ongkir</span>}
      </div>
    </Link>
  );
}
