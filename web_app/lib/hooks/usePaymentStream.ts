"use client";

import { useEffect } from "react";
import { fetchEventSource } from "@microsoft/fetch-event-source";
import { API_BASE_URL } from "@/lib/api/config";
import { useAuthStore } from "@/lib/stores/auth";

interface PaymentStatusEvent {
  order_id: string;
  payment_status: string;
}

/**
 * Watches an order's payment_status over SSE instead of polling for it —
 * only meant to be enabled for the narrow window between "order placed,
 * non-cash" and "payment_status reaches paid/failed". Browser EventSource
 * can't set the Authorization header this API requires, hence
 * fetch-event-source instead of the native EventSource class.
 */
export function usePaymentStream(orderId: string | undefined, enabled: boolean, onStatus: (status: string) => void) {
  useEffect(() => {
    if (!enabled || !orderId) return;
    const token = useAuthStore.getState().token;
    if (!token) return;

    const controller = new AbortController();

    fetchEventSource(`${API_BASE_URL}/payment/${orderId}/stream`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: controller.signal,
      openWhenHidden: true, // keep watching even if the tab is backgrounded mid-payment
      async onopen(res) {
        if (!res.ok) throw new Error(`SSE handshake failed (${res.status})`);
      },
      onmessage(ev) {
        if (ev.event !== "payment_status") return;
        try {
          const data: PaymentStatusEvent = JSON.parse(ev.data);
          onStatus(data.payment_status);
        } catch {
          // ignore malformed event
        }
      },
      // no onerror override — fetch-event-source's default retry-with-backoff
      // is what we want here (self-healing reconnect); the page's existing
      // poll on the order query is the fallback if SSE can't connect at all.
    }).catch(() => {});

    return () => controller.abort();
  }, [orderId, enabled, onStatus]);
}
