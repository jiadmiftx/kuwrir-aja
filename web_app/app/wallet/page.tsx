"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
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
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Wallet</p>
      </header>

      <div className="m-4 rounded-2xl bg-emerald-600 p-5 text-white">
        <p className="text-xs opacity-80">Saldo Wallet</p>
        <p className="mt-1 text-2xl font-bold">{wallet ? formatIDR(wallet.balance) : "—"}</p>
        <p className="mt-2 text-xs opacity-70">Wallet tidak dipakai untuk bayar pesanan langsung — hanya top up & tarik dana.</p>
        <div className="mt-4 flex gap-2">
          <Link
            href="/wallet/topup"
            className="flex-1 rounded-full bg-white py-2 text-center text-sm font-semibold text-emerald-700"
          >
            + Top Up
          </Link>
          <Link
            href="/wallet/withdraw"
            className="flex-1 rounded-full border border-white/60 py-2 text-center text-sm font-semibold text-white"
          >
            Tarik Dana
          </Link>
        </div>
      </div>

      <section className="px-4">
        <p className="mb-2 text-sm font-bold text-gray-800">Riwayat Transaksi</p>
        <div className="flex flex-col gap-2">
          {transactions.map((tx) => (
            <div key={tx.id} className="flex items-center justify-between rounded-xl border border-gray-100 p-3">
              <div>
                <p className="text-sm font-medium text-gray-800">{walletCategoryLabel(tx.category)}</p>
                <p className="text-xs text-gray-400">{new Date(tx.created_at).toLocaleString("id-ID")}</p>
                {tx.notes && <p className="text-xs text-gray-400">{tx.notes}</p>}
              </div>
              <p className={`text-sm font-bold ${tx.type === "credit" ? "text-emerald-600" : "text-red-500"}`}>
                {tx.type === "credit" ? "+" : "-"}
                {formatIDR(tx.amount)}
              </p>
            </div>
          ))}
          {transactions.length === 0 && !data.isLoading && (
            <p className="py-8 text-center text-sm text-gray-400">Belum ada transaksi.</p>
          )}
        </div>
      </section>
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
