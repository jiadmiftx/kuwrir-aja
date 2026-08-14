"use client";

import { useEffect } from "react";
import { fetchEventSource } from "@microsoft/fetch-event-source";
import { API_BASE_URL } from "@/lib/api/config";
import { useAuthStore } from "@/lib/stores/auth";

/**
 * Generic trigger-only SSE subscription — for streams where the event
 * carries no payload worth parsing beyond "something changed" (chat,
 * support messages), unlike usePaymentStream/useOrderStatusStream which
 * decode a specific field. fetch-event-source's default retry-with-backoff
 * handles reconnects on its own; the caller's existing poll on the
 * underlying query is the fallback if SSE can't connect at all.
 */
export function useSseSignal(path: string | undefined, eventName: string, enabled: boolean, onSignal: () => void) {
  useEffect(() => {
    if (!enabled || !path) return;
    const token = useAuthStore.getState().token;
    if (!token) return;

    const controller = new AbortController();

    fetchEventSource(`${API_BASE_URL}${path}`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: controller.signal,
      openWhenHidden: true,
      async onopen(res) {
        if (!res.ok) throw new Error(`SSE handshake failed (${res.status})`);
      },
      onmessage(ev) {
        if (ev.event !== eventName) return;
        onSignal();
      },
    }).catch(() => {});

    return () => controller.abort();
  }, [path, eventName, enabled, onSignal]);
}
