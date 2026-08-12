"use client";

import { useEffect } from "react";
import Link from "next/link";
import { HugeiconsIcon } from "@hugeicons/react";
import { Alert02Icon } from "@hugeicons/core-free-icons";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 px-6 text-center">
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-(--color-danger-soft) text-(--color-danger)">
        <HugeiconsIcon icon={Alert02Icon} size={28} strokeWidth={1.5} />
      </div>
      <div>
        <p className="text-base font-semibold text-(--color-ink)">Terjadi kesalahan</p>
        <p className="mt-1 text-sm text-(--color-ink-faint)">
          Halaman gagal dimuat. Coba lagi, atau kembali ke beranda.
        </p>
      </div>
      <div className="mt-2 flex gap-3">
        <button
          onClick={() => reset()}
          className="rounded-full bg-(--color-accent) px-5 py-2.5 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
        >
          Coba Lagi
        </button>
        <Link
          href="/"
          className="rounded-full border border-(--color-border) px-5 py-2.5 text-sm font-semibold text-(--color-ink-soft)"
        >
          Ke Beranda
        </Link>
      </div>
    </div>
  );
}
