"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
import { requestOtp, verifyOtp } from "@/lib/api/endpoints";
import { useAuthStore } from "@/lib/stores/auth";
import { ApiError } from "@/lib/api/client";

function normalizeDisplayPhone(raw: string) {
  return raw.replace(/[^\d+]/g, "");
}

export default function LoginPage() {
  const router = useRouter();
  const setAuth = useAuthStore((s) => s.setAuth);

  const [step, setStep] = useState<"phone" | "otp">("phone");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [agreeTerms, setAgreeTerms] = useState(false);
  const [error, setError] = useState("");

  const requestMutation = useMutation({
    mutationFn: () => requestOtp(phone),
    onSuccess: () => {
      setError("");
      setStep("otp");
    },
    onError: (err) => setError(err instanceof ApiError ? err.message : "Gagal mengirim kode OTP"),
  });

  const verifyMutation = useMutation({
    mutationFn: () => verifyOtp(phone, code, agreeTerms),
    onSuccess: (data) => {
      setAuth(data.token, data.refresh_token, data.user);
      router.replace("/");
    },
    onError: (err) => setError(err instanceof ApiError ? err.message : "Kode OTP salah atau kedaluwarsa"),
  });

  return (
    <div className="flex min-h-screen flex-col justify-center px-6 py-12">
      <div className="mb-10 text-center">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/images/cocourir_food_logo.svg" alt="Cocourir" className="mx-auto h-16 w-auto" />
        <p className="mt-2 text-sm text-gray-500">Pesan makanan & kebutuhan harian, diantar cepat.</p>
      </div>

      {step === "phone" && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            requestMutation.mutate();
          }}
          className="flex flex-col gap-4"
        >
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-gray-700">Nomor WhatsApp</span>
            <input
              type="tel"
              inputMode="tel"
              required
              placeholder="08xxxxxxxxxx"
              value={phone}
              onChange={(e) => setPhone(normalizeDisplayPhone(e.target.value))}
              className="rounded-lg border border-gray-300 px-4 py-3 text-base outline-none focus:border-emerald-500"
            />
          </label>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button
            type="submit"
            disabled={requestMutation.isPending || phone.length < 9}
            className="rounded-lg bg-emerald-600 py-3 font-semibold text-white disabled:opacity-50"
          >
            {requestMutation.isPending ? "Mengirim..." : "Kirim Kode OTP"}
          </button>
        </form>
      )}

      {step === "otp" && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            verifyMutation.mutate();
          }}
          className="flex flex-col gap-4"
        >
          <p className="text-sm text-gray-600">
            Kode OTP dikirim via WhatsApp ke <strong>{phone}</strong>.
          </p>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-gray-700">Kode OTP</span>
            <input
              type="text"
              inputMode="numeric"
              required
              maxLength={6}
              placeholder="123456"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              className="rounded-lg border border-gray-300 px-4 py-3 text-center text-lg tracking-widest outline-none focus:border-emerald-500"
            />
          </label>
          <label className="flex items-start gap-2 text-sm text-gray-600">
            <input
              type="checkbox"
              checked={agreeTerms}
              onChange={(e) => setAgreeTerms(e.target.checked)}
              className="mt-0.5"
            />
            Saya menyetujui{" "}
            <Link href="/terms" target="_blank" className="text-emerald-600 underline">
              Syarat &amp; Ketentuan
            </Link>{" "}
            Cocourir
          </label>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button
            type="submit"
            disabled={verifyMutation.isPending || code.length < 4 || !agreeTerms}
            className="rounded-lg bg-emerald-600 py-3 font-semibold text-white disabled:opacity-50"
          >
            {verifyMutation.isPending ? "Memverifikasi..." : "Verifikasi & Masuk"}
          </button>
          <button
            type="button"
            onClick={() => {
              setStep("phone");
              setCode("");
              setError("");
            }}
            className="text-sm text-gray-500 underline"
          >
            Ganti nomor
          </button>
        </form>
      )}
    </div>
  );
}
