"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AuthGuard } from "@/components/AuthGuard";
import { cancelOrder, getOrder, getOrderChat, requestRefund, sendOrderChat } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { orderStatusLabel, isActiveOrder } from "@/lib/order-status";
import { useAuthStore } from "@/lib/stores/auth";
import { ApiError } from "@/lib/api/client";

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
  if (!o) return <div className="p-4 text-sm text-gray-400">Memuat...</div>;

  const canCancel = o.status === "pending";
  const canRefund = o.status === "delivered" || o.status === "cancelled";

  return (
    <div className="pb-6">
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">#{o.order_number}</p>
      </header>

      <section className="border-b border-gray-100 px-4 py-4">
        <div className="mb-2 flex items-center justify-between">
          <span className="rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-700">
            {orderStatusLabel(o.status)}
          </span>
          {o.payment_type !== "cash" && (
            <span
              className={`rounded-full px-3 py-1 text-xs font-semibold ${
                o.payment_status === "paid" ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-700"
              }`}
            >
              {o.payment_status === "paid" ? "Sudah Dibayar" : "Menunggu Pembayaran"}
            </span>
          )}
        </div>
        <p className="text-sm text-gray-600">{o.merchant?.name}</p>
        <p className="text-xs text-gray-400">{o.dropoff_address}</p>
      </section>

      {o.payment_type !== "cash" && o.payment_status !== "paid" && o.payment_url && (
        <section className="border-b border-gray-100 px-4 py-3">
          <a
            href={o.payment_url}
            className="block w-full rounded-full bg-amber-500 py-2.5 text-center text-sm font-semibold text-white"
          >
            Lanjutkan Pembayaran
          </a>
          <p className="mt-1.5 text-center text-xs text-gray-400">
            Link pembayaran masih berlaku, klik untuk menyelesaikan pembayaran.
          </p>
        </section>
      )}

      {o.items && o.items.length > 0 && (
        <section className="border-b border-gray-100 px-4 py-3">
          <p className="mb-2 text-sm font-bold text-gray-800">Item Pesanan</p>
          <div className="flex flex-col gap-1.5">
            {o.items.map((it) => (
              <div key={it.id} className="flex justify-between text-sm">
                <span className="text-gray-600">
                  {it.quantity}x {it.item_name}
                </span>
                <span className="text-gray-800">{formatIDR(it.total_price)}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      <section className="border-b border-gray-100 px-4 py-3">
        <div className="flex flex-col gap-1.5 text-sm">
          <div className="flex justify-between text-gray-600">
            <span>Subtotal</span>
            <span>{formatIDR(o.subtotal)}</span>
          </div>
          <div className="flex justify-between text-gray-600">
            <span>Ongkos Kirim</span>
            <span>{formatIDR(o.delivery_fee)}</span>
          </div>
          {o.discount_amount > 0 && (
            <div className="flex justify-between text-emerald-600">
              <span>Diskon {o.promo_code && `(${o.promo_code})`}</span>
              <span>-{formatIDR(o.discount_amount)}</span>
            </div>
          )}
          <div className="mt-1 flex justify-between border-t border-gray-100 pt-1.5 text-base font-bold text-gray-800">
            <span>Total {o.payment_type === "cash" ? "(Bayar di Tempat)" : ""}</span>
            <span>{formatIDR(o.total)}</span>
          </div>
        </div>
      </section>

      <div className="flex gap-2 px-4 py-3">
        <button
          onClick={() => setShowChat((v) => !v)}
          className="flex-1 rounded-full border border-emerald-600 py-2.5 text-sm font-semibold text-emerald-600"
        >
          💬 Chat
        </button>
        {canCancel && (
          <button
            onClick={() => {
              if (confirm("Batalkan pesanan ini?")) cancel.mutate();
            }}
            disabled={cancel.isPending}
            className="flex-1 rounded-full border border-red-500 py-2.5 text-sm font-semibold text-red-500"
          >
            Batalkan
          </button>
        )}
        {canRefund && !refundResult && (
          <button
            onClick={() => setShowRefundForm((v) => !v)}
            className="flex-1 rounded-full border border-amber-500 py-2.5 text-sm font-semibold text-amber-600"
          >
            Ajukan Refund
          </button>
        )}
      </div>

      {refundResult && (
        <section className="border-b border-gray-100 px-4 py-3">
          <p className={`text-xs ${refundResult.ok ? "text-emerald-600" : "text-red-500"}`}>{refundResult.message}</p>
        </section>
      )}

      {showRefundForm && (
        <section className="border-b border-gray-100 px-4 py-3">
          <p className="mb-2 text-sm font-semibold text-gray-800">Alasan Refund</p>
          <textarea
            value={refundReason}
            onChange={(e) => setRefundReason(e.target.value)}
            rows={3}
            placeholder="Jelaskan alasan pengajuan refund..."
            className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <button
            onClick={() => refund.mutate()}
            disabled={refund.isPending || !refundReason.trim()}
            className="mt-2 w-full rounded-full bg-amber-500 py-2.5 text-sm font-semibold text-white disabled:opacity-50"
          >
            {refund.isPending ? "Mengirim..." : "Kirim Pengajuan"}
          </button>
          <p className="mt-1.5 text-xs text-gray-400">Refund sebesar {formatIDR(o.total)} akan ditinjau admin dalam 1-2 hari kerja.</p>
        </section>
      )}

      {showChat && (
        <section className="border-t border-gray-100 px-4 py-3">
          <div className="mb-3 flex max-h-60 flex-col gap-2 overflow-y-auto">
            {chat.data?.messages.map((m) => (
              <div
                key={m.id}
                className={`max-w-[75%] rounded-lg px-3 py-2 text-sm ${
                  m.sender_id === userId ? "self-end bg-emerald-600 text-white" : "self-start bg-gray-100 text-gray-800"
                }`}
              >
                {m.text}
              </div>
            ))}
            {chat.data && chat.data.messages.length === 0 && (
              <p className="text-center text-xs text-gray-400">Belum ada percakapan.</p>
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
              className="flex-1 rounded-full border border-gray-200 px-4 py-2 text-sm outline-none focus:border-emerald-500"
            />
            <button
              type="submit"
              disabled={sendChat.isPending}
              className="rounded-full bg-emerald-600 px-4 text-sm font-semibold text-white"
            >
              Kirim
            </button>
          </form>
        </section>
      )}
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
