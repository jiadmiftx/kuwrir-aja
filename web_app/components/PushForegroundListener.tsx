"use client";

import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { subscribeForegroundMessages } from "@/lib/firebase/messaging";
import { useAuthStore } from "@/lib/stores/auth";

// Refetches whatever order/chat queries are on screen when a push arrives
// while the tab is focused — mirrors how the Flutter apps use push as the
// primary refresh trigger with polling only as a slow fallback.
export function PushForegroundListener() {
  const token = useAuthStore((s) => s.token);
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!token || typeof Notification === "undefined" || Notification.permission !== "granted") return;
    let unsubscribe: (() => void) | undefined;
    subscribeForegroundMessages(() => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
      queryClient.invalidateQueries({ predicate: (q) => q.queryKey[0] === "order" || q.queryKey[0] === "order-chat" });
    }).then((unsub) => {
      unsubscribe = unsub;
    });
    return () => unsubscribe?.();
  }, [token, queryClient]);

  return null;
}
