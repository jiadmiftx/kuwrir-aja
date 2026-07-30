"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, CheckmarkCircle02Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getWallet, withdrawWallet } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { ApiError } from "@/lib/api/client";

const BANKS = ["BCA", "BNI", "BRI", "MANDIRI", "CIMB", "PERMATA"];

function WithdrawContent() {
  const router = useRouter();
  const wallet = useQuery({ queryKey: ["wallet"], queryFn: getWallet });

  const [amount, setAmount] = useState("");
  const [bankCode, setBankCode] = useState(BANKS[0]);
  const [accountNumber, setAccountNumber] = useState("");
  const [accountName, setAccountName] = useState("");
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");

  const amountValue = Number(amount) || 0;
  const balance = wallet.data?.wallet.balance ?? 0;

  const submit = useMutation({
    mutationFn: () =>
      withdrawWallet({
        amount: amountValue,
        bank_code: bankCode,
        bank_account_number: accountNumber,
        bank_account_name: accountName,
      }),
    onSuccess: () => setSuccess(true),
    onError: (err) => setError(err instanceof ApiError ? err.message : "Gagal memproses penarikan"),
  });

  if (success) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-3 px-6 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-(--color-accent-soft) text-(--color-accent)">
          <HugeiconsIcon icon={CheckmarkCircle02Icon} size={30} strokeWidth={1.5} />
        </div>
        <p className="text-base font-semibold text-(--color-ink)">Penarikan Diproses</p>
        <p className="text-sm text-(--color-ink-soft)">
          Permintaan tarik dana {formatIDR(amountValue)} sedang diproses ke rekening {bankCode}.
        </p>
        <button
          onClick={() => router.replace("/wallet")}
          className="mt-2 rounded-full bg-(--color-accent) px-6 py-2.5 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
        >
          Kembali ke Wallet
        </button>
      </div>
    );
  }

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Tarik Dana</p>
      </div>

      <div className="mx-auto max-w-2xl px-4 py-4 md:px-0">
        <p className="text-xs text-(--color-ink-faint)">Saldo tersedia: {formatIDR(balance)}</p>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            setError("");
            if (amountValue > balance) {
              setError("Jumlah melebihi saldo tersedia");
              return;
            }
            submit.mutate();
          }}
          className="mt-3 flex flex-col gap-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4"
        >
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Jumlah</span>
            <input
              type="number"
              inputMode="numeric"
              required
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Masukkan nominal"
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Bank</span>
            <select
              value={bankCode}
              onChange={(e) => setBankCode(e.target.value)}
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            >
              {BANKS.map((b) => (
                <option key={b} value={b}>
                  {b}
                </option>
              ))}
            </select>
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Nomor Rekening</span>
            <input
              required
              value={accountNumber}
              onChange={(e) => setAccountNumber(e.target.value.replace(/\D/g, ""))}
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Nama Pemilik Rekening</span>
            <input
              required
              value={accountName}
              onChange={(e) => setAccountName(e.target.value)}
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </label>
          {error && <p className="text-sm text-(--color-danger)">{error}</p>}
          <button
            type="submit"
            disabled={submit.isPending || amountValue <= 0}
            className="mt-2 rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
          >
            {submit.isPending ? "Memproses..." : "Ajukan Penarikan"}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function WithdrawPage() {
  return (
    <AuthGuard>
      <WithdrawContent />
    </AuthGuard>
  );
}
