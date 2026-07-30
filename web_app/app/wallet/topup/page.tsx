"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getPaymentMethods, topupWallet } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { ApiError } from "@/lib/api/client";

const PRESETS = [50_000, 100_000, 200_000, 500_000];

function TopupContent() {
  const router = useRouter();
  const [amount, setAmount] = useState(0);
  const [amountInput, setAmountInput] = useState("");
  const [method, setMethod] = useState("");
  const [error, setError] = useState("");

  const paymentMethods = useQuery({
    queryKey: ["payment-methods", amount],
    queryFn: () => getPaymentMethods(amount),
    enabled: amount >= 10_000,
  });

  const submit = useMutation({
    mutationFn: () => topupWallet(amount, method),
    onSuccess: (data) => {
      window.location.href = data.payment_url;
    },
    onError: (err) => setError(err instanceof ApiError ? err.message : "Gagal memproses top up"),
  });

  function setAmountValue(value: number) {
    setAmount(value);
    setAmountInput(value ? String(value) : "");
    setMethod("");
  }

  return (
    <div className="pb-28">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Top Up Wallet</p>
      </div>

      <div className="mx-auto max-w-2xl px-4 py-4 md:px-0">
        <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
          <p className="mb-3 text-sm font-medium text-(--color-ink)">Jumlah Top Up</p>
          <input
            type="number"
            inputMode="numeric"
            value={amountInput}
            onChange={(e) => setAmountValue(Number(e.target.value) || 0)}
            placeholder="Masukkan nominal"
            className="w-full rounded-xl border border-(--color-border) px-4 py-3 text-base outline-none focus:border-(--color-ink-faint)"
          />
          <div className="mt-3 flex flex-wrap gap-2">
            {PRESETS.map((p) => (
              <button
                key={p}
                onClick={() => setAmountValue(p)}
                className={`rounded-full border px-3.5 py-1.5 text-xs font-medium transition-colors ${
                  amount === p
                    ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)"
                    : "border-(--color-border) text-(--color-ink-soft)"
                }`}
              >
                {formatIDR(p)}
              </button>
            ))}
          </div>
        </section>

        {amount >= 10_000 && (
          <section className="mt-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <p className="mb-3 text-sm font-medium text-(--color-ink)">Metode Pembayaran</p>
            {paymentMethods.isLoading && <p className="text-xs text-(--color-ink-faint)">Memuat metode pembayaran...</p>}
            <div className="flex flex-col gap-2">
              {paymentMethods.data?.payment_methods.map((m) => (
                <label
                  key={m.paymentMethod}
                  className={`flex items-center gap-2.5 rounded-xl border p-3 text-sm transition-colors ${
                    method === m.paymentMethod
                      ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)"
                      : "border-(--color-border) text-(--color-ink-soft)"
                  }`}
                >
                  <input
                    type="radio"
                    checked={method === m.paymentMethod}
                    onChange={() => setMethod(m.paymentMethod)}
                    className="accent-(--color-accent)"
                  />
                  {m.paymentName}
                </label>
              ))}
            </div>
          </section>
        )}

        {amount > 0 && amount < 10_000 && <p className="mt-3 text-xs text-(--color-danger)">Minimal top up Rp10.000</p>}
        {error && <p className="mt-3 text-sm text-(--color-danger)">{error}</p>}
      </div>

      <div className="fixed bottom-16 left-0 right-0 z-20 mx-auto max-w-2xl border-t border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:mt-3 md:max-w-2xl md:rounded-2xl md:border md:px-5">
        <button
          disabled={amount < 10_000 || !method || submit.isPending}
          onClick={() => submit.mutate()}
          className="w-full rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
        >
          {submit.isPending ? "Memproses..." : `Top Up ${amount > 0 ? formatIDR(amount) : ""}`}
        </button>
      </div>
    </div>
  );
}

export default function TopupPage() {
  return (
    <AuthGuard>
      <TopupContent />
    </AuthGuard>
  );
}
