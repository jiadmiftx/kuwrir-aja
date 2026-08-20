"use client";

import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { Cancel01Icon, StarIcon } from "@hugeicons/core-free-icons";
import { submitOrderReview } from "@/lib/api/endpoints";

interface Props {
  orderId: string;
  hasDriver: boolean;
  onClose: () => void;
  onSubmitted: () => void;
}

function StarPicker({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  return (
    <div className="flex gap-1">
      {[1, 2, 3, 4, 5].map((i) => (
        <button key={i} type="button" onClick={() => onChange(i)} aria-label={`${i} bintang`}>
          <HugeiconsIcon
            icon={StarIcon}
            size={32}
            strokeWidth={1.5}
            className={i <= value ? "text-(--color-warning)" : "text-(--color-border)"}
          />
        </button>
      ))}
    </div>
  );
}

/// Combined post-delivery rating — one Review row per order (merchant/product
/// quality + driver), matching the backend schema. Same sheet shape as
/// ReplacementPickerSheet: bottom sheet on mobile, centered card on desktop.
export function ReviewSheet({ orderId, hasDriver, onClose, onSubmitted }: Props) {
  const [merchantRating, setMerchantRating] = useState(0);
  const [driverRating, setDriverRating] = useState(0);
  const [comment, setComment] = useState("");
  const [error, setError] = useState("");

  const submit = useMutation({
    mutationFn: () =>
      submitOrderReview(orderId, {
        merchant_rating: merchantRating > 0 ? merchantRating : undefined,
        driver_rating: hasDriver && driverRating > 0 ? driverRating : undefined,
        comment: comment.trim() || undefined,
      }),
    onSuccess: () => onSubmitted(),
    onError: () => setError("Gagal mengirim rating, coba lagi"),
  });

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-(--color-ink)/45 md:items-center md:p-6" onClick={onClose}>
      <div
        className="mx-auto flex w-full max-w-md flex-col overflow-hidden rounded-t-3xl bg-(--color-surface-raised) md:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-(--color-border) px-5 py-4">
          <p className="text-base font-semibold text-(--color-ink)">Beri Rating Pesanan</p>
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full text-(--color-ink-faint) hover:bg-(--color-border-soft)"
            aria-label="Tutup"
          >
            <HugeiconsIcon icon={Cancel01Icon} size={18} strokeWidth={1.5} />
          </button>
        </div>

        <div className="flex flex-col gap-5 px-5 py-5">
          <div>
            <p className="mb-2 text-sm font-medium text-(--color-ink-soft)">Rating Toko &amp; Produk</p>
            <StarPicker value={merchantRating} onChange={setMerchantRating} />
          </div>
          {hasDriver && (
            <div>
              <p className="mb-2 text-sm font-medium text-(--color-ink-soft)">Rating Driver</p>
              <StarPicker value={driverRating} onChange={setDriverRating} />
            </div>
          )}
          <textarea
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            rows={3}
            placeholder="Tulis komentar (opsional)"
            className="w-full rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
          />
          {error && <p className="text-sm text-(--color-danger)">{error}</p>}
          <button
            onClick={() => {
              if (merchantRating === 0 && driverRating === 0) {
                setError("Beri rating minimal satu");
                return;
              }
              setError("");
              submit.mutate();
            }}
            disabled={submit.isPending}
            className="rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-50"
          >
            {submit.isPending ? "Mengirim..." : "Kirim Rating"}
          </button>
        </div>
      </div>
    </div>
  );
}
