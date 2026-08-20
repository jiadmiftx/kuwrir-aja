import Link from "next/link";
import { HugeiconsIcon } from "@hugeicons/react";
import { Store01Icon, StarIcon } from "@hugeicons/core-free-icons";
import type { Merchant } from "@/lib/api/types";

export function MerchantCard({ merchant }: { merchant: Merchant }) {
  return (
    <Link
      href={`/store/${merchant.id}`}
      className="group flex min-w-[168px] max-w-[168px] flex-col gap-2 rounded-[20px] border border-(--color-border) bg-(--color-surface-raised) p-2.5 shadow-[0_4px_14px_-6px_rgba(0,0,0,0.1)] transition-shadow hover:shadow-[0_8px_20px_-6px_rgba(0,0,0,0.16)] md:min-w-0 md:max-w-none md:w-full"
    >
      <div className="relative aspect-square w-full overflow-hidden rounded-xl bg-(--color-border-soft)">
        {merchant.logo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={merchant.logo_url}
            alt={merchant.name}
            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-(--color-ink-faint)">
            <HugeiconsIcon icon={Store01Icon} size={28} strokeWidth={1.5} />
          </div>
        )}
        {!merchant.is_open && (
          <div className="absolute inset-0 flex items-center justify-center bg-(--color-ink)/55 text-xs font-medium text-(--color-accent-contrast)">
            Tutup
          </div>
        )}
      </div>
      <p className="truncate text-sm font-medium text-(--color-ink)">{merchant.name}</p>
      <div className="flex items-center gap-1 text-xs text-(--color-ink-faint)">
        <HugeiconsIcon icon={StarIcon} size={13} strokeWidth={1.5} className="text-(--color-warning)" />
        <span>{merchant.rating.toFixed(1)}</span>
        {typeof merchant.distance_km === "number" && <span>· {merchant.distance_km.toFixed(1)} km</span>}
        {merchant.is_free_delivery && <span className="text-(--color-accent)">· Gratis Ongkir</span>}
      </div>
    </Link>
  );
}
