"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
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
        <p className="text-4xl">✅</p>
        <p className="text-base font-semibold text-gray-800">Penarikan Diproses</p>
        <p className="text-sm text-gray-500">
          Permintaan tarik dana {formatIDR(amountValue)} sedang diproses ke rekening {bankCode}.
        </p>
        <button
          onClick={() => router.replace("/wallet")}
          className="mt-2 rounded-full bg-emerald-600 px-6 py-2.5 text-sm font-semibold text-white"
        >
          Kembali ke Wallet
        </button>
      </div>
    );
  }

  return (
    <div className="pb-6">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Tarik Dana</p>
      </header>

      <p className="px-4 pt-3 text-xs text-gray-500">Saldo tersedia: {formatIDR(balance)}</p>

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
        className="flex flex-col gap-3 px-4 py-4"
      >
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Jumlah</span>
          <input
            type="number"
            inputMode="numeric"
            required
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="Masukkan nominal"
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Bank</span>
          <select
            value={bankCode}
            onChange={(e) => setBankCode(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          >
            {BANKS.map((b) => (
              <option key={b} value={b}>
                {b}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Nomor Rekening</span>
          <input
            required
            value={accountNumber}
            onChange={(e) => setAccountNumber(e.target.value.replace(/\D/g, ""))}
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Nama Pemilik Rekening</span>
          <input
            required
            value={accountName}
            onChange={(e) => setAccountName(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={submit.isPending || amountValue <= 0}
          className="mt-2 rounded-full bg-emerald-600 py-3 text-sm font-semibold text-white disabled:opacity-50"
        >
          {submit.isPending ? "Memproses..." : "Ajukan Penarikan"}
        </button>
      </form>
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
