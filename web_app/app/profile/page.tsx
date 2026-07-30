"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useMutation } from "@tanstack/react-query";
import { AuthGuard } from "@/components/AuthGuard";
import { useAuthStore } from "@/lib/stores/auth";
import { requestPushToken } from "@/lib/firebase/messaging";
import { saveDeviceToken } from "@/lib/api/endpoints";

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
    return <p className="px-4 py-3 text-xs text-emerald-600">🔔 Notifikasi pesanan aktif di perangkat ini.</p>;
  }

  return (
    <div className="px-4 py-3">
      <button
        onClick={() => enable.mutate()}
        disabled={enable.isPending}
        className="w-full rounded-full border border-emerald-600 py-2.5 text-sm font-semibold text-emerald-600 disabled:opacity-50"
      >
        {enable.isPending ? "Mengaktifkan..." : "🔔 Aktifkan Notifikasi Pesanan"}
      </button>
      {status === "denied" && (
        <p className="mt-1.5 text-xs text-red-500">
          Izin notifikasi ditolak — aktifkan lewat pengaturan browser/perangkat.
        </p>
      )}
      {status === "unsupported" && (
        <p className="mt-1.5 text-xs text-gray-400">
          Perangkat/browser ini belum mendukung notifikasi push. Di iPhone, install dulu ke Layar Utama lewat tombol
          Bagikan.
        </p>
      )}
      {status === "unconfigured" && (
        <p className="mt-1.5 text-xs text-gray-400">Notifikasi push belum dikonfigurasi untuk versi web ini.</p>
      )}
    </div>
  );
}

function ProfileContent() {
  const router = useRouter();
  const { user, clear } = useAuthStore();

  return (
    <div className="pb-6">
      <header className="sticky top-0 z-20 border-b border-gray-100 bg-white px-4 py-3">
        <p className="text-base font-bold text-gray-800">Profil</p>
      </header>

      <div className="flex items-center gap-3 border-b border-gray-100 px-4 py-4">
        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100 text-2xl">👤</div>
        <div>
          <p className="text-base font-semibold text-gray-800">{user?.name || "Pengguna"}</p>
          <p className="text-sm text-gray-500">{user?.phone}</p>
        </div>
      </div>

      <div className="flex flex-col divide-y divide-gray-100">
        <Link href="/profile/edit" className="flex items-center justify-between px-4 py-3 text-sm text-gray-700">
          Edit Profil <span className="text-gray-300">›</span>
        </Link>
        <Link href="/addresses" className="flex items-center justify-between px-4 py-3 text-sm text-gray-700">
          Alamat Tersimpan <span className="text-gray-300">›</span>
        </Link>
        <Link href="/orders" className="flex items-center justify-between px-4 py-3 text-sm text-gray-700">
          Riwayat Pesanan <span className="text-gray-300">›</span>
        </Link>
        <Link href="/wallet" className="flex items-center justify-between px-4 py-3 text-sm text-gray-700">
          Wallet <span className="text-gray-300">›</span>
        </Link>
        <Link href="/support" className="flex items-center justify-between px-4 py-3 text-sm text-gray-700">
          Chat Admin / Bantuan <span className="text-gray-300">›</span>
        </Link>
        <Link href="/terms" className="flex items-center justify-between px-4 py-3 text-sm text-gray-700">
          Syarat &amp; Ketentuan <span className="text-gray-300">›</span>
        </Link>
      </div>

      <NotificationSettings />

      <div className="px-4 py-6">
        <button
          onClick={() => {
            clear();
            router.replace("/login");
          }}
          className="w-full rounded-full border border-red-500 py-3 text-sm font-semibold text-red-500"
        >
          Keluar
        </button>
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
