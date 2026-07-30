"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, PlusSignIcon, ArrowDown01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getWalletTransactions } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { walletCategoryLabel } from "@/lib/wallet-category";

function WalletContent() {
  const router = useRouter();
  const data = useQuery({ queryKey: ["wallet-transactions"], queryFn: getWalletTransactions });

  const wallet = data.data?.wallet;
  const transactions = data.data?.transactions ?? [];

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Wallet</p>
      </div>

      <div className="mx-auto max-w-2xl px-4 py-4 md:px-0">
        <div className="rounded-2xl bg-(--color-accent) p-5 text-(--color-accent-contrast)">
          <p className="text-xs opacity-80">Saldo Wallet</p>
          <p className="mt-1 text-2xl font-semibold">{wallet ? formatIDR(wallet.balance) : "—"}</p>
          <p className="mt-2 text-xs opacity-70">Wallet tidak dipakai untuk bayar pesanan langsung — hanya top up & tarik dana.</p>
          <div className="mt-4 flex gap-2">
            <Link
              href="/wallet/topup"
              className="flex flex-1 items-center justify-center gap-1.5 rounded-full bg-(--color-surface-raised) py-2 text-sm font-semibold text-(--color-accent)"
            >
              <HugeiconsIcon icon={PlusSignIcon} size={15} strokeWidth={2} />
              Top Up
            </Link>
            <Link
              href="/wallet/withdraw"
              className="flex flex-1 items-center justify-center gap-1.5 rounded-full border border-(--color-accent-contrast)/50 py-2 text-sm font-semibold text-(--color-accent-contrast)"
            >
              <HugeiconsIcon icon={ArrowDown01Icon} size={15} strokeWidth={2} />
              Tarik Dana
            </Link>
          </div>
        </div>

        <section className="mt-6">
          <p className="mb-3 text-sm font-medium text-(--color-ink-soft)">Riwayat Transaksi</p>
          <div className="flex flex-col gap-2">
            {transactions.map((tx) => (
              <div key={tx.id} className="flex items-center justify-between rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-3.5">
                <div>
                  <p className="text-sm font-medium text-(--color-ink)">{walletCategoryLabel(tx.category)}</p>
                  <p className="text-xs text-(--color-ink-faint)">{new Date(tx.created_at).toLocaleString("id-ID")}</p>
                  {tx.notes && <p className="text-xs text-(--color-ink-faint)">{tx.notes}</p>}
                </div>
                <p className={`text-sm font-semibold ${tx.type === "credit" ? "text-(--color-accent)" : "text-(--color-danger)"}`}>
                  {tx.type === "credit" ? "+" : "-"}
                  {formatIDR(tx.amount)}
                </p>
              </div>
            ))}
            {transactions.length === 0 && !data.isLoading && (
              <p className="py-8 text-center text-sm text-(--color-ink-faint)">Belum ada transaksi.</p>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

export default function WalletPage() {
  return (
    <AuthGuard>
      <WalletContent />
    </AuthGuard>
  );
}
