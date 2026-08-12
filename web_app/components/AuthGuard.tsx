"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/stores/auth";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const token = useAuthStore((s) => s.token);
  const hasHydrated = useAuthStore((s) => s.hasHydrated);

  useEffect(() => {
    // Wait for the persisted session to finish loading from localStorage
    // before deciding — reading `token` before hydration completes always
    // sees the pre-load default (null), which would otherwise bounce a
    // genuinely logged-in visitor to /login on every fresh mount (cold
    // load, and remounts triggered by browser back/forward).
    if (hasHydrated && !token) router.replace("/login");
  }, [hasHydrated, token, router]);

  if (!hasHydrated || !token) return null;
  return <>{children}</>;
}
