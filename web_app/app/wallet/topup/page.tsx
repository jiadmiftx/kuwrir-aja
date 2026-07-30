"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
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
    <div className="pb-24">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Top Up Wallet</p>
      </header>

      <div className="px-4 py-4">
        <p className="mb-2 text-sm font-semibold text-gray-800">Jumlah Top Up</p>
        <input
          type="number"
          inputMode="numeric"
          value={amountInput}
          onChange={(e) => setAmountValue(Number(e.target.value) || 0)}
          placeholder="Masukkan nominal"
          className="w-full rounded-lg border border-gray-300 px-4 py-3 text-base outline-none focus:border-emerald-500"
        />
        <div className="mt-2 flex flex-wrap gap-2">
          {PRESETS.map((p) => (
            <button
              key={p}
              onClick={() => setAmountValue(p)}
              className={`rounded-full border px-3 py-1.5 text-xs font-medium ${
                amount === p ? "border-emerald-500 bg-emerald-50 text-emerald-700" : "border-gray-200 text-gray-600"
              }`}
            >
              {formatIDR(p)}
            </button>
          ))}
        </div>
      </div>

      {amount >= 10_000 && (
        <div className="border-t border-gray-100 px-4 py-4">
          <p className="mb-2 text-sm font-semibold text-gray-800">Metode Pembayaran</p>
          {paymentMethods.isLoading && <p className="text-xs text-gray-400">Memuat metode pembayaran...</p>}
          <div className="flex flex-col gap-2">
            {paymentMethods.data?.payment_methods.map((m) => (
              <label
                key={m.paymentMethod}
                className={`flex items-center gap-2 rounded-lg border p-3 text-sm ${
                  method === m.paymentMethod ? "border-emerald-500 bg-emerald-50 text-emerald-700" : "border-gray-200 text-gray-700"
                }`}
              >
                <input type="radio" checked={method === m.paymentMethod} onChange={() => setMethod(m.paymentMethod)} />
                {m.paymentName}
              </label>
            ))}
          </div>
        </div>
      )}

      {amount > 0 && amount < 10_000 && (
        <p className="px-4 text-xs text-red-500">Minimal top up Rp10.000</p>
      )}
      {error && <p className="px-4 text-sm text-red-600">{error}</p>}

      <div className="fixed bottom-16 left-0 right-0 z-20 mx-auto max-w-(--shell-width) border-t border-gray-100 bg-white px-4 py-3">
        <button
          disabled={amount < 10_000 || !method || submit.isPending}
          onClick={() => submit.mutate()}
          className="w-full rounded-full bg-emerald-600 py-3 text-sm font-semibold text-white disabled:opacity-50"
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
