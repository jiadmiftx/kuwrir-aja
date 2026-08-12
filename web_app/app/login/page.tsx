"use client";

import { useEffect, useState } from "react";
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
  // Mirrors the 60s cooldown the backend itself enforces on
  // POST /auth/otp/request (see backend otpResendCooldown) — kept in sync
  // so the button doesn't invite a 429 the server would reject anyway.
  const [resendSeconds, setResendSeconds] = useState(0);

  useEffect(() => {
    if (resendSeconds <= 0) return;
    const timer = setInterval(() => setResendSeconds((s) => s - 1), 1000);
    return () => clearInterval(timer);
  }, [resendSeconds]);

  const requestMutation = useMutation({
    mutationFn: () => requestOtp(phone),
    onSuccess: () => {
      setError("");
      setStep("otp");
      setResendSeconds(60);
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
      <div className="mx-auto w-full max-w-sm">
        <div className="mb-10 text-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/cocourir_food_logo.svg" alt="Cocourir" className="mx-auto h-16 w-auto" />
          <p className="mt-2 text-sm text-(--color-ink-faint)">Pesan makanan & kebutuhan harian, diantar cepat.</p>
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
              <span className="text-sm font-medium text-(--color-ink-soft)">Nomor WhatsApp</span>
              <input
                type="tel"
                inputMode="tel"
                required
                placeholder="08xxxxxxxxxx"
                value={phone}
                onChange={(e) => setPhone(normalizeDisplayPhone(e.target.value))}
                className="rounded-xl border border-(--color-border) px-4 py-3 text-base outline-none focus:border-(--color-ink-faint)"
              />
            </label>
            {error && <p className="text-sm text-(--color-danger)">{error}</p>}
            <button
              type="submit"
              disabled={requestMutation.isPending || phone.length < 9}
              className="rounded-xl bg-(--color-accent) py-3 font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
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
            <p className="text-sm text-(--color-ink-soft)">
              Kode OTP dikirim via WhatsApp ke <strong>{phone}</strong>.
            </p>
            <label className="flex flex-col gap-1.5">
              <span className="text-sm font-medium text-(--color-ink-soft)">Kode OTP</span>
              <input
                type="text"
                inputMode="numeric"
                required
                maxLength={6}
                placeholder="123456"
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                className="rounded-xl border border-(--color-border) px-4 py-3 text-center text-lg tracking-widest outline-none focus:border-(--color-ink-faint)"
              />
            </label>
            <label className="flex items-start gap-2 text-sm text-(--color-ink-soft)">
              <input
                type="checkbox"
                checked={agreeTerms}
                onChange={(e) => setAgreeTerms(e.target.checked)}
                className="mt-0.5 accent-(--color-accent)"
              />
              Saya menyetujui{" "}
              <Link href="/terms" target="_blank" className="text-(--color-accent) underline">
                Syarat &amp; Ketentuan
              </Link>{" "}
              Cocourir
            </label>
            {error && <p className="text-sm text-(--color-danger)">{error}</p>}
            <button
              type="submit"
              disabled={verifyMutation.isPending || code.length < 4 || !agreeTerms}
              className="rounded-xl bg-(--color-accent) py-3 font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
            >
              {verifyMutation.isPending ? "Memverifikasi..." : "Verifikasi & Masuk"}
            </button>
            <div className="flex items-center justify-center gap-4 text-sm">
              <button
                type="button"
                disabled={resendSeconds > 0 || requestMutation.isPending}
                onClick={() => {
                  setCode("");
                  requestMutation.mutate();
                }}
                className="text-(--color-accent) underline disabled:text-(--color-ink-faint) disabled:no-underline"
              >
                {resendSeconds > 0
                  ? `Kirim ulang dalam ${resendSeconds}s`
                  : requestMutation.isPending
                    ? "Mengirim..."
                    : "Kirim ulang kode"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setStep("phone");
                  setCode("");
                  setError("");
                  setResendSeconds(0);
                }}
                className="text-(--color-ink-faint) underline"
              >
                Ganti nomor
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
