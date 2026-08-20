"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import {
  Call02Icon,
  CoffeeIcon,
  IceCreamIcon,
  NoodlesIcon,
  PizzaIcon,
  SquareLock01Icon,
  WhatsappIcon,
} from "@hugeicons/core-free-icons";
import { requestOtp, verifyOtp } from "@/lib/api/endpoints";
import { useAuthStore } from "@/lib/stores/auth";
import { ApiError } from "@/lib/api/client";

function normalizeDisplayPhone(raw: string) {
  return raw.replace(/[^\d+]/g, "");
}

// Rotates through these every few seconds in the hero, same food-forward,
// casual-Indonesian tone as customer_app's login boarding screen.
const TAGLINES = [
  "Lapar dikit, langsung meluncur.",
  "Warung favoritmu, tinggal klik.",
  "Kurir lokal, jajanan lokal, cepat sampai.",
  "Bayar cash atau online, sama gampangnya.",
];

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

  const [taglineIndex, setTaglineIndex] = useState(0);
  const [taglineVisible, setTaglineVisible] = useState(true);

  useEffect(() => {
    if (resendSeconds <= 0) return;
    const timer = setInterval(() => setResendSeconds((s) => s - 1), 1000);
    return () => clearInterval(timer);
  }, [resendSeconds]);

  useEffect(() => {
    const cycle = setInterval(() => {
      setTaglineVisible(false);
      setTimeout(() => {
        setTaglineIndex((i) => (i + 1) % TAGLINES.length);
        setTaglineVisible(true);
      }, 300);
    }, 2600);
    return () => clearInterval(cycle);
  }, []);

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
    <div className="flex min-h-screen items-center justify-center bg-(--color-surface) md:p-6">
      <div className="w-full max-w-md overflow-hidden md:rounded-[32px] md:shadow-xl">
        {/* Hero */}
        <div className="relative overflow-hidden bg-gradient-to-br from-(--color-accent-hover) to-(--color-accent) px-6 pt-14 pb-16 text-center">
          <HugeiconsIcon
            icon={PizzaIcon}
            size={56}
            className="absolute -top-2 -left-2 rotate-[-18deg] text-white/15"
          />
          <HugeiconsIcon
            icon={NoodlesIcon}
            size={52}
            className="absolute top-6 -right-3 rotate-[14deg] text-white/15"
          />
          <HugeiconsIcon
            icon={IceCreamIcon}
            size={44}
            className="absolute bottom-4 -left-4 rotate-[10deg] text-white/15"
          />
          <HugeiconsIcon
            icon={CoffeeIcon}
            size={44}
            className="absolute -right-2 bottom-10 rotate-[-12deg] text-white/15"
          />

          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/cocourir_food_logo.svg" alt="Cocourir" className="relative mx-auto h-16 w-auto" />

          <p
            className={`relative mt-4 text-sm text-white/90 transition-opacity duration-300 ${
              taglineVisible ? "opacity-100" : "opacity-0"
            }`}
          >
            {TAGLINES[taglineIndex]}
          </p>

          <span className="relative mt-4 inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-medium text-white backdrop-blur-sm">
            Bisa lihat ongkir sebelum order
          </span>
        </div>

        {/* Sheet */}
        <div className="relative z-10 -mt-6 rounded-t-[28px] bg-(--color-surface-raised) px-6 pt-6 pb-8">
          <div className="mx-auto mb-6 h-1 w-9 rounded-full bg-(--color-border)" />

          {step === "phone" && (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                requestMutation.mutate();
              }}
              className="flex flex-col gap-4"
            >
              <div>
                <p className="mb-1.5 text-sm font-semibold text-(--color-ink)">Masuk atau daftar</p>
                <p className="text-xs text-(--color-ink-faint)">Nomor baru otomatis terdaftar sebagai akun baru.</p>
              </div>
              <label className="flex flex-col gap-1.5">
                <span className="text-sm font-medium text-(--color-ink-soft)">Nomor WhatsApp</span>
                <div className="flex items-center gap-2.5 rounded-xl border border-(--color-border) px-4 py-3 focus-within:border-(--color-ink-faint)">
                  <HugeiconsIcon icon={Call02Icon} size={18} className="shrink-0 text-(--color-ink-faint)" />
                  <input
                    type="tel"
                    inputMode="tel"
                    required
                    placeholder="08xxxxxxxxxx"
                    value={phone}
                    onChange={(e) => setPhone(normalizeDisplayPhone(e.target.value))}
                    className="w-full text-base outline-none"
                  />
                </div>
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
              <p className="flex items-center gap-1.5 text-sm text-(--color-ink-soft)">
                <HugeiconsIcon icon={WhatsappIcon} size={16} className="shrink-0 text-(--color-accent)" />
                Kode dikirim lewat WhatsApp ke <strong className="text-(--color-ink)">{phone}</strong>
              </p>
              <label className="flex flex-col gap-1.5">
                <span className="text-sm font-medium text-(--color-ink-soft)">Kode OTP</span>
                <div className="flex items-center gap-2.5 rounded-xl border border-(--color-border) px-4 py-3 focus-within:border-(--color-ink-faint)">
                  <HugeiconsIcon icon={SquareLock01Icon} size={18} className="shrink-0 text-(--color-ink-faint)" />
                  <input
                    type="text"
                    inputMode="numeric"
                    required
                    maxLength={6}
                    placeholder="000000"
                    value={code}
                    onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                    className="w-full text-center text-lg font-bold tracking-[0.4em] outline-none"
                  />
                </div>
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
                {verifyMutation.isPending ? "Memverifikasi..." : "Masuk"}
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
    </div>
  );
}
