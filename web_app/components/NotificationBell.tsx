"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { Notification03Icon } from "@hugeicons/core-free-icons";
import { getMyNotifications } from "@/lib/api/endpoints";
import { useAuthStore } from "@/lib/stores/auth";

/// Small bell icon + unread-count dot, used in both TopNav (desktop) and
/// the home page header (mobile, where TopNav is hidden) — shares the same
/// ["notifications"] query key as /notifications itself, so the count and
/// the list never disagree and navigating there is instant from cache.
export function NotificationBell({ className }: { className?: string }) {
  const token = useAuthStore((s) => s.token);
  const notifications = useQuery({
    queryKey: ["notifications"],
    queryFn: getMyNotifications,
    enabled: !!token,
  });
  const unread = notifications.data?.notifications.filter((n) => !n.is_read).length ?? 0;

  return (
    <Link href="/notifications" className={`relative flex items-center justify-center ${className ?? ""}`} aria-label="Notifikasi">
      <HugeiconsIcon icon={Notification03Icon} size={20} strokeWidth={1.5} />
      {unread > 0 && (
        <span className="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full bg-(--color-danger) ring-2 ring-(--color-surface-raised)" />
      )}
    </Link>
  );
}
