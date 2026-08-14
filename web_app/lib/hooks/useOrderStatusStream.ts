"use client";

import { useEffect } from "react";
import { fetchEventSource } from "@microsoft/fetch-event-source";
import { API_BASE_URL } from "@/lib/api/config";
import { useAuthStore } from "@/lib/stores/auth";

interface OrderStatusEvent {
  order_id: string;
  status: string;
}

/**
 * Watches an order's status over SSE instead of polling for it — same
 * pattern as usePaymentStream, but long-lived: an order can sit in flight
 * for tens of minutes, not the few seconds a payment confirmation takes.
 * fetch-event-source's default retry-with-backoff handles reconnects on its
 * own; the page's existing (much slower) poll on the order query is only a
 * safety net if SSE can't connect at all.
 */
export function useOrderStatusStream(orderId: string | undefined, enabled: boolean, onStatus: (status: string) => void) {
  useEffect(() => {
    if (!enabled || !orderId) return;
    const token = useAuthStore.getState().token;
    if (!token) return;

    const controller = new AbortController();

    fetchEventSource(`${API_BASE_URL}/orders/${orderId}/stream`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: controller.signal,
      openWhenHidden: true,
      async onopen(res) {
        if (!res.ok) throw new Error(`SSE handshake failed (${res.status})`);
      },
      onmessage(ev) {
        if (ev.event !== "order_status") return;
        try {
          const data: OrderStatusEvent = JSON.parse(ev.data);
          onStatus(data.status);
        } catch {
          // ignore malformed event
        }
      },
    }).catch(() => {});

    return () => controller.abort();
  }, [orderId, enabled, onStatus]);
}
