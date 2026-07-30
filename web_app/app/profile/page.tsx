"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useMutation } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import {
  UserIcon,
  PencilEdit01Icon,
  Location01Icon,
  Invoice01Icon,
  Wallet01Icon,
  Message01Icon,
  Shield01Icon,
  ArrowRight01Icon,
  Notification01Icon,
  Logout01Icon,
} from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { useAuthStore } from "@/lib/stores/auth";
import { requestPushToken } from "@/lib/firebase/messaging";
import { saveDeviceToken } from "@/lib/api/endpoints";

const MENU = [
  { href: "/profile/edit", label: "Edit Profil", icon: PencilEdit01Icon },
  { href: "/addresses", label: "Alamat Tersimpan", icon: Location01Icon },
  { href: "/orders", label: "Riwayat Pesanan", icon: Invoice01Icon },
  { href: "/wallet", label: "Wallet", icon: Wallet01Icon },
  { href: "/support", label: "Chat Admin / Bantuan", icon: Message01Icon },
  { href: "/terms", label: "Syarat & Ketentuan", icon: Shield01Icon },
] as const;

function NotificationSettings() {
  const [status, setStatus] = useState<"idle" | "granted" | "denied" | "unsupported" | "unconfigured">(
    typeof Notification !== "undefined" ? (Notification.permission === "granted" ? "granted" : "idle") : "idle"
  );

  const enable = useMutation({
    mutationFn: async () => {
      const { token, result } = await requestPushToken();
      if (token) await saveDeviceToken(token);
      return result;
    },
    onSuccess: setStatus,
  });

  if (status === "granted") {
    return (
      <p className="mt-4 flex items-center gap-2 text-xs text-(--color-accent)">
        <HugeiconsIcon icon={Notification01Icon} size={14} strokeWidth={1.5} />
        Notifikasi pesanan aktif di perangkat ini.
      </p>
    );
  }

  return (
    <div className="mt-4">
      <button
        onClick={() => enable.mutate()}
        disabled={enable.isPending}
        className="flex w-full items-center justify-center gap-2 rounded-full border border-(--color-accent) py-2.5 text-sm font-semibold text-(--color-accent) disabled:opacity-50"
      >
        <HugeiconsIcon icon={Notification01Icon} size={16} strokeWidth={1.5} />
        {enable.isPending ? "Mengaktifkan..." : "Aktifkan Notifikasi Pesanan"}
      </button>
      {status === "denied" && (
        <p className="mt-2 text-xs text-(--color-danger)">
          Izin notifikasi ditolak — aktifkan lewat pengaturan browser/perangkat.
        </p>
      )}
      {status === "unsupported" && (
        <p className="mt-2 text-xs text-(--color-ink-faint)">
          Perangkat/browser ini belum mendukung notifikasi push. Di iPhone, install dulu ke Layar Utama lewat tombol
          Bagikan.
        </p>
      )}
      {status === "unconfigured" && (
        <p className="mt-2 text-xs text-(--color-ink-faint)">Notifikasi push belum dikonfigurasi untuk versi web ini.</p>
      )}
    </div>
  );
}

function ProfileContent() {
  const router = useRouter();
  const { user, clear } = useAuthStore();

  return (
    <div className="mx-auto max-w-(--content-width) px-4 pb-6 md:px-8">
      <header className="pt-5 md:pt-8">
        <h1 className="text-xl font-semibold tracking-tight text-(--color-ink) md:text-2xl">Profil</h1>
      </header>

      <div className="mx-auto max-w-2xl">
        <div className="mt-4 flex items-center gap-3.5 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-(--color-accent-soft) text-(--color-accent)">
            <HugeiconsIcon icon={UserIcon} size={26} strokeWidth={1.5} />
          </div>
          <div>
            <p className="text-base font-semibold text-(--color-ink)">{user?.name || "Pengguna"}</p>
            <p className="text-sm text-(--color-ink-faint)">{user?.phone}</p>
          </div>
        </div>

        <div className="mt-3 flex flex-col divide-y divide-(--color-border) overflow-hidden rounded-2xl border border-(--color-border) bg-(--color-surface-raised)">
          {MENU.map((item) => (
            <Link key={item.href} href={item.href} className="flex items-center gap-3 px-4 py-3.5 text-sm text-(--color-ink)">
              <HugeiconsIcon icon={item.icon} size={18} strokeWidth={1.5} className="text-(--color-ink-faint)" />
              <span className="flex-1">{item.label}</span>
              <HugeiconsIcon icon={ArrowRight01Icon} size={16} strokeWidth={1.5} className="text-(--color-ink-faint)" />
            </Link>
          ))}
        </div>

        <NotificationSettings />

        <div className="mt-6">
          <button
            onClick={() => {
              clear();
              router.replace("/login");
            }}
            className="flex w-full items-center justify-center gap-2 rounded-full border border-(--color-danger) py-3 text-sm font-semibold text-(--color-danger)"
          >
            <HugeiconsIcon icon={Logout01Icon} size={17} strokeWidth={1.5} />
            Keluar
          </button>
        </div>
      </div>
    </div>
  );
}

export default function ProfilePage() {
  return (
    <AuthGuard>
      <ProfileContent />
    </AuthGuard>
  );
}
