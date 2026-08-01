"use client";

import { useCallback, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, Message01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { cancelOrder, getOrder, getOrderChat, requestRefund, sendOrderChat } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { orderStatusLabel, isActiveOrder } from "@/lib/order-status";
import { useAuthStore } from "@/lib/stores/auth";
import { ApiError } from "@/lib/api/client";
import { usePaymentStream } from "@/lib/hooks/usePaymentStream";

function OrderDetailContent() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();
  const userId = useAuthStore((s) => s.user?.id);
  const [showChat, setShowChat] = useState(false);
  const [chatText, setChatText] = useState("");
  const [showRefundForm, setShowRefundForm] = useState(false);
  const [refundReason, setRefundReason] = useState("");
  const [refundResult, setRefundResult] = useState<{ ok: boolean; message: string } | null>(null);

  const order = useQuery({
    queryKey: ["order", params.id],
    queryFn: () => getOrder(params.id),
    refetchInterval: (query) => (query.state.data && isActiveOrder(query.state.data.order.status) ? 10_000 : false),
  });

  // SSE instead of polling for the one thing that's actually latency-sensitive
  // here: finding out the instant Duitku confirms payment. The 10s poll above
  // keeps covering the rest of the order lifecycle (preparing/ready/etc).
  const awaitingPayment =
    !!order.data && order.data.order.payment_type !== "cash" && order.data.order.payment_status !== "paid";
  const onPaymentStatus = useCallback(
    (status: string) => {
      if (status === "paid" || status === "failed") {
        queryClient.invalidateQueries({ queryKey: ["order", params.id] });
      }
    },
    [queryClient, params.id]
  );
  usePaymentStream(params.id, awaitingPayment, onPaymentStatus);

  const chat = useQuery({
    queryKey: ["order-chat", params.id],
    queryFn: () => getOrderChat(params.id),
    enabled: showChat,
    refetchInterval: showChat ? 20_000 : false,
  });

  const sendChat = useMutation({
    mutationFn: () => sendOrderChat(params.id, chatText),
    onSuccess: () => {
      setChatText("");
      queryClient.invalidateQueries({ queryKey: ["order-chat", params.id] });
    },
  });

  const cancel = useMutation({
    mutationFn: () => cancelOrder(params.id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["order", params.id] }),
  });

  const refund = useMutation({
    mutationFn: () => requestRefund(params.id, refundReason),
    onSuccess: (data) => {
      setShowRefundForm(false);
      setRefundResult({ ok: true, message: data.message });
    },
    onError: (err) =>
      setRefundResult({
        ok: false,
        message: err instanceof ApiError ? err.message : "Gagal mengajukan refund",
      }),
  });

  const o = order.data?.order;
  if (!o) return <div className="p-4 text-sm text-(--color-ink-faint)">Memuat...</div>;

  const canCancel = o.status === "pending";
  const canRefund = o.status === "delivered" || o.status === "cancelled";

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">#{o.order_number}</p>
      </div>

      <div className="mx-auto flex max-w-2xl flex-col gap-3 px-4 py-4 md:px-0">
        <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
          <div className="mb-2 flex items-center justify-between">
            <span className="rounded-full bg-(--color-accent-soft) px-3 py-1 text-sm font-medium text-(--color-accent)">
              {orderStatusLabel(o.status)}
            </span>
            {o.payment_type !== "cash" && (
              <span
                className={`rounded-full px-3 py-1 text-xs font-medium ${
                  o.payment_status === "paid"
                    ? "bg-(--color-accent-soft) text-(--color-accent)"
                    : "bg-(--color-warning-soft) text-(--color-warning)"
                }`}
              >
                {o.payment_status === "paid" ? "Sudah Dibayar" : "Menunggu Pembayaran"}
              </span>
            )}
          </div>
          <p className="text-sm text-(--color-ink-soft)">{o.merchant?.name}</p>
          <p className="text-xs text-(--color-ink-faint)">{o.dropoff_address}</p>
        </section>

        {o.payment_type !== "cash" && o.payment_status !== "paid" && o.payment_url && (
          <section className="rounded-2xl border border-(--color-warning-soft) bg-(--color-warning-soft) p-4">
            <a
              href={o.payment_url}
              className="block w-full rounded-full bg-(--color-warning) py-2.5 text-center text-sm font-semibold text-(--color-accent-contrast)"
            >
              Lanjutkan Pembayaran
            </a>
            <p className="mt-2 text-center text-xs text-(--color-warning)">
              Link pembayaran masih berlaku, klik untuk menyelesaikan pembayaran.
            </p>
          </section>
        )}

        {o.items && o.items.length > 0 && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <p className="mb-2.5 text-sm font-medium text-(--color-ink)">Item Pesanan</p>
            <div className="flex flex-col gap-1.5">
              {o.items.map((it) => (
                <div key={it.id} className="flex justify-between text-sm">
                  <span className="text-(--color-ink-soft)">
                    {it.quantity}x {it.item_name}
                  </span>
                  <span className="text-(--color-ink)">{formatIDR(it.total_price)}</span>
                </div>
              ))}
            </div>
          </section>
        )}

        <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
          <div className="flex flex-col gap-2 text-sm">
            <div className="flex justify-between text-(--color-ink-soft)">
              <span>Subtotal</span>
              <span>{formatIDR(o.subtotal)}</span>
            </div>
            <div className="flex justify-between text-(--color-ink-soft)">
              <span>Ongkos Kirim</span>
              <span>{formatIDR(o.delivery_fee)}</span>
            </div>
            {o.discount_amount > 0 && (
              <div className="flex justify-between text-(--color-accent)">
                <span>Diskon {o.promo_code && `(${o.promo_code})`}</span>
                <span>-{formatIDR(o.discount_amount)}</span>
              </div>
            )}
            <div className="mt-1 flex justify-between border-t border-(--color-border) pt-2 text-base font-semibold text-(--color-ink)">
              <span>Total {o.payment_type === "cash" ? "(Bayar di Tempat)" : ""}</span>
              <span>{formatIDR(o.total)}</span>
            </div>
          </div>
        </section>

        <div className="flex gap-2">
          <button
            onClick={() => setShowChat((v) => !v)}
            className="flex flex-1 items-center justify-center gap-2 rounded-full border border-(--color-accent) py-2.5 text-sm font-semibold text-(--color-accent)"
          >
            <HugeiconsIcon icon={Message01Icon} size={16} strokeWidth={1.5} />
            Chat
          </button>
          {canCancel && (
            <button
              onClick={() => {
                if (confirm("Batalkan pesanan ini?")) cancel.mutate();
              }}
              disabled={cancel.isPending}
              className="flex-1 rounded-full border border-(--color-danger) py-2.5 text-sm font-semibold text-(--color-danger)"
            >
              Batalkan
            </button>
          )}
          {canRefund && !refundResult && (
            <button
              onClick={() => setShowRefundForm((v) => !v)}
              className="flex-1 rounded-full border border-(--color-warning) py-2.5 text-sm font-semibold text-(--color-warning)"
            >
              Ajukan Refund
            </button>
          )}
        </div>

        {refundResult && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <p className={`text-xs ${refundResult.ok ? "text-(--color-accent)" : "text-(--color-danger)"}`}>
              {refundResult.message}
            </p>
          </section>
        )}

        {showRefundForm && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <p className="mb-2 text-sm font-medium text-(--color-ink)">Alasan Refund</p>
            <textarea
              value={refundReason}
              onChange={(e) => setRefundReason(e.target.value)}
              rows={3}
              placeholder="Jelaskan alasan pengajuan refund..."
              className="w-full rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
            <button
              onClick={() => refund.mutate()}
              disabled={refund.isPending || !refundReason.trim()}
              className="mt-2 w-full rounded-full bg-(--color-warning) py-2.5 text-sm font-semibold text-(--color-accent-contrast) disabled:opacity-50"
            >
              {refund.isPending ? "Mengirim..." : "Kirim Pengajuan"}
            </button>
            <p className="mt-2 text-xs text-(--color-ink-faint)">
              Refund sebesar {formatIDR(o.total)} akan ditinjau admin dalam 1-2 hari kerja.
            </p>
          </section>
        )}

        {showChat && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <div className="mb-3 flex max-h-60 flex-col gap-2 overflow-y-auto">
              {chat.data?.messages.map((m) => (
                <div
                  key={m.id}
                  className={`max-w-[75%] rounded-2xl px-3.5 py-2 text-sm ${
                    m.sender_id === userId
                      ? "self-end bg-(--color-accent) text-(--color-accent-contrast)"
                      : "self-start bg-(--color-border-soft) text-(--color-ink)"
                  }`}
                >
                  {m.text}
                </div>
              ))}
              {chat.data && chat.data.messages.length === 0 && (
                <p className="text-center text-xs text-(--color-ink-faint)">Belum ada percakapan.</p>
              )}
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (chatText.trim()) sendChat.mutate();
              }}
              className="flex gap-2"
            >
              <input
                value={chatText}
                onChange={(e) => setChatText(e.target.value)}
                placeholder="Tulis pesan..."
                className="flex-1 rounded-full border border-(--color-border) px-4 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
              />
              <button
                type="submit"
                disabled={sendChat.isPending}
                className="rounded-full bg-(--color-accent) px-4 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
              >
                Kirim
              </button>
            </form>
          </section>
        )}
      </div>
    </div>
  );
}

export default function OrderDetailPage() {
  return (
    <AuthGuard>
      <OrderDetailContent />
    </AuthGuard>
  );
}
