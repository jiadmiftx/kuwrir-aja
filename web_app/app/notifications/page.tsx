"use client";

import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, Notification03Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getMyNotifications, markNotificationRead } from "@/lib/api/endpoints";

function timeAgo(iso: string) {
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60_000);
  if (minutes < 1) return "Baru saja";
  if (minutes < 60) return `${minutes} menit lalu`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} jam lalu`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} hari lalu`;
  return new Date(iso).toLocaleDateString("id-ID");
}

function NotificationsContent() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const notifications = useQuery({ queryKey: ["notifications"], queryFn: getMyNotifications });

  const markRead = useMutation({
    mutationFn: (id: string) => markNotificationRead(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["notifications"] }),
  });

  const list = notifications.data?.notifications ?? [];

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Notifikasi</p>
      </div>

      <div className="mx-auto max-w-2xl px-4 py-4 md:px-0">
        {notifications.isLoading && <p className="py-8 text-center text-sm text-(--color-ink-faint)">Memuat...</p>}

        {list.length === 0 && !notifications.isLoading && (
          <div className="flex flex-col items-center gap-4 py-20 text-center">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-(--color-accent-soft)">
              <HugeiconsIcon icon={Notification03Icon} size={32} strokeWidth={1.5} className="text-(--color-accent)" />
            </div>
            <p className="text-sm font-semibold text-(--color-ink)">Belum ada notifikasi</p>
          </div>
        )}

        <div className="flex flex-col gap-2">
          {list.map((n) => (
            <button
              key={n.id}
              onClick={() => !n.is_read && markRead.mutate(n.id)}
              className={`flex items-start gap-3 rounded-2xl border p-4 text-left transition-colors ${
                n.is_read
                  ? "border-(--color-border) bg-(--color-surface-raised)"
                  : "border-(--color-accent-soft) bg-(--color-accent-soft)"
              }`}
            >
              <span
                className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${n.is_read ? "bg-transparent" : "bg-(--color-accent)"}`}
              />
              <div className="flex-1">
                <p className="text-sm font-semibold text-(--color-ink)">{n.title}</p>
                <p className="mt-0.5 text-sm text-(--color-ink-soft)">{n.body}</p>
                <p className="mt-1.5 text-xs text-(--color-ink-faint)">{timeAgo(n.created_at)}</p>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function NotificationsPage() {
  return (
    <AuthGuard>
      <NotificationsContent />
    </AuthGuard>
  );
}
