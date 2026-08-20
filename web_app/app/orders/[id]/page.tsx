"use client";

import { useCallback, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import {
  Alert02Icon,
  ArrowLeft01Icon,
  ArrowRight01Icon,
  Location01Icon,
  Message01Icon,
  Motorbike01Icon,
  Refresh01Icon,
  StarIcon,
  Store01Icon,
  UserIcon,
} from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { OrderProgressTracker } from "@/components/OrderProgressTracker";
import { ReplacementPickerSheet } from "@/components/ReplacementPickerSheet";
import { ReviewSheet } from "@/components/ReviewSheet";
import {
  cancelOrder,
  cancelViaModificationRequest,
  getChatUnreadCount,
  getMerchantProducts,
  getModificationRequest,
  getOrder,
  getOrderDriverChat,
  getOrderMerchantChat,
  replaceOrderItem,
  requestRefund,
  sendOrderDriverChat,
  sendOrderMerchantChat,
} from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { canChatDriver, canChatMerchant, orderStatusLabel, orderStatusToneClasses, isActiveOrder } from "@/lib/order-status";
import { useAuthStore } from "@/lib/stores/auth";
import { useCartStore } from "@/lib/stores/cart";
import { ApiError } from "@/lib/api/client";
import { usePaymentStream } from "@/lib/hooks/usePaymentStream";
import { useOrderStatusStream } from "@/lib/hooks/useOrderStatusStream";
import { useSseSignal } from "@/lib/hooks/useSseSignal";
import type { Product, ProductVariant } from "@/lib/api/types";

// Refund request is built and working end-to-end but disabled in the UI
// for now (business decision, not ready to expose) — flip this back to
// true to bring the button/form back rather than re-deriving them.
const REFUND_ACTION_ENABLED = false;

const MODIFICATION_REASON_LABELS: Record<string, string> = {
  stok_habis: "Stok habis",
  toko_tutup: "Toko tutup",
  item_tidak_tersedia: "Item tidak tersedia",
  lainnya: "Lainnya",
};

function modificationReasonLabel(category: string, reason?: string) {
  const label = MODIFICATION_REASON_LABELS[category] ?? category;
  return reason ? `${label} — ${reason}` : label;
}

type ChatChannel = "merchant" | "driver";

type DialogState = {
  title: string;
  message: string;
  danger?: boolean;
  confirmLabel?: string;
  onConfirm?: () => void;
} | null;

function OrderDetailContent() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const userId = useAuthStore((s) => s.user?.id);
  // Deep-link from the order list card's chat chips (?openChat=merchant|driver)
  // straight into the right panel on first render — read once via the lazy
  // initializer rather than an effect+setState (which the linter flags as
  // a cascading-render footgun); eligibility is re-checked below via
  // `effectiveChat` once the order itself has loaded.
  const [activeChat, setActiveChat] = useState<ChatChannel | null>(() => {
    const requested = searchParams.get("openChat");
    return requested === "merchant" || requested === "driver" ? requested : null;
  });
  const [chatText, setChatText] = useState("");
  const [showRefundForm, setShowRefundForm] = useState(false);
  const [refundReason, setRefundReason] = useState("");
  const [refundResult, setRefundResult] = useState<{ ok: boolean; message: string } | null>(null);
  const [showPicker, setShowPicker] = useState(false);
  const [showReview, setShowReview] = useState(false);
  const [reordering, setReordering] = useState(false);
  const [dialog, setDialog] = useState<DialogState>(null);
  const cartAddItem = useCartStore((s) => s.addItem);
  const cartMerchantId = useCartStore((s) => s.merchantId);
  const cartLines = useCartStore((s) => s.lines);

  const order = useQuery({
    queryKey: ["order", params.id],
    queryFn: () => getOrder(params.id),
    // SSE (useOrderStatusStream, below) is the primary refresh trigger now —
    // this is just a slow safety net for the rare case where the stream
    // can't connect at all (fetch-event-source handles reconnects itself
    // otherwise, so this doesn't need to be a tight poll).
    refetchInterval: (query) => (query.state.data && isActiveOrder(query.state.data.order.status) ? 45_000 : false),
  });

  const onOrderStatus = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ["order", params.id] });
  }, [queryClient, params.id]);
  useOrderStatusStream(params.id, !!order.data && isActiveOrder(order.data.order.status), onOrderStatus);

  // Merchant flagged an item unavailable on this already-accepted order —
  // only worth polling while the order is in a status where that can
  // happen (confirmed/preparing); a 404 here just means nothing pending.
  const o0 = order.data?.order;

  // The ?openChat= deep-link (read into initial state above) shouldn't win
  // over reality once the order's loaded — e.g. a stale link to a driver
  // thread for an order whose driver hasn't accepted yet. Clamped here
  // rather than in an effect+setState (unnecessary, and a cascading-render
  // footgun); `activeChat` itself still tracks manual toggling.
  const chatMerchantEligible = !!o0 && canChatMerchant(o0.status);
  const chatDriverEligible = !!o0 && canChatDriver(o0);
  const effectiveChat: ChatChannel | null =
    (activeChat === "merchant" && !chatMerchantEligible) || (activeChat === "driver" && !chatDriverEligible)
      ? null
      : activeChat;

  const modificationEnabled = o0?.status === "confirmed" || o0?.status === "preparing";
  const modification = useQuery({
    queryKey: ["order-modification", params.id],
    queryFn: () => getModificationRequest(params.id),
    enabled: modificationEnabled,
    refetchInterval: modificationEnabled ? 10_000 : false,
    retry: false,
  });
  const modReq = modification.data?.modification_request;
  const removedItem = modification.data?.removed_item;

  const replace = useMutation({
    mutationFn: (picked: { product: Product; variants: ProductVariant[]; quantity: number }) =>
      replaceOrderItem(params.id, modReq!.id, {
        product_id: picked.product.id,
        quantity: picked.quantity,
        variant_ids: picked.variants.map((v) => v.id),
      }),
    onSuccess: (data) => {
      setShowPicker(false);
      if (data.topup_payment_url) {
        window.location.href = data.topup_payment_url;
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["order", params.id] });
      queryClient.invalidateQueries({ queryKey: ["order-modification", params.id] });
    },
  });

  const cancelModification = useMutation({
    mutationFn: () => cancelViaModificationRequest(params.id, modReq!.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["order", params.id] });
      queryClient.invalidateQueries({ queryKey: ["order-modification", params.id] });
    },
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

  // Two separate threads (never mixed, matches the backend's channel split
  // and customer_app's two distinct chat buttons) — each only fetched while
  // its own panel is open.
  const driverChat = useQuery({
    queryKey: ["order-chat-driver", params.id],
    queryFn: () => getOrderDriverChat(params.id),
    enabled: effectiveChat === "driver",
    refetchInterval: effectiveChat === "driver" ? 60_000 : false,
  });
  const merchantChat = useQuery({
    queryKey: ["order-chat-merchant", params.id],
    queryFn: () => getOrderMerchantChat(params.id),
    enabled: effectiveChat === "merchant",
    refetchInterval: effectiveChat === "merchant" ? 60_000 : false,
  });
  const onDriverChatSignal = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ["order-chat-driver", params.id] });
    queryClient.invalidateQueries({ queryKey: ["chat-unread"] });
  }, [queryClient, params.id]);
  const onMerchantChatSignal = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ["order-chat-merchant", params.id] });
    queryClient.invalidateQueries({ queryKey: ["chat-unread"] });
  }, [queryClient, params.id]);
  useSseSignal(`/orders/${params.id}/chat/stream`, "chat_message", effectiveChat === "driver", onDriverChatSignal);
  useSseSignal(
    `/orders/${params.id}/merchant-chat/stream`,
    "chat_message",
    effectiveChat === "merchant",
    onMerchantChatSignal
  );

  const sendDriverChat = useMutation({
    mutationFn: () => sendOrderDriverChat(params.id, chatText),
    onSuccess: () => {
      setChatText("");
      queryClient.invalidateQueries({ queryKey: ["order-chat-driver", params.id] });
    },
  });
  const [merchantChatError, setMerchantChatError] = useState("");
  const sendMerchantChat = useMutation({
    mutationFn: () => sendOrderMerchantChat(params.id, chatText),
    onSuccess: () => {
      setChatText("");
      setMerchantChatError("");
      queryClient.invalidateQueries({ queryKey: ["order-chat-merchant", params.id] });
    },
    // The client-side lock (see merchantHasReplied) normally prevents this,
    // but it's only a UX nicety — the backend is the real gate (403 if the
    // merchant hasn't sent the first message yet), so surface it for real
    // rather than swallowing it.
    onError: (err) => setMerchantChatError(err instanceof ApiError ? err.message : "Gagal mengirim pesan"),
  });

  const chatChattable = !!o0 && (canChatMerchant(o0.status) || canChatDriver(o0));
  const unread = useQuery({
    queryKey: ["chat-unread"],
    queryFn: getChatUnreadCount,
    enabled: chatChattable,
    refetchInterval: chatChattable ? 30_000 : false,
  });
  const merchantUnread = unread.data?.orders?.[params.id]?.merchant ?? 0;
  const driverUnread = unread.data?.orders?.[params.id]?.driver ?? 0;

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
  const canRefund =
    REFUND_ACTION_ENABLED && (o.status === "delivered" || o.status === "cancelled");
  const isDelivered = o.status === "delivered";
  const hasReview = order.data?.has_review ?? false;
  const merchantHasReplied = merchantChat.data?.messages.some((m) => m.sender_role === "merchant") ?? false;

  function toggleChat(channel: ChatChannel) {
    setActiveChat((cur) => (cur === channel ? null : channel));
  }

  // Re-adds this order's items to the cart from the merchant's *current*
  // live menu (not a blind replay of the old snapshot) — an item may have
  // since gone unavailable or been removed entirely, so each is matched by
  // product id against a fresh menu fetch and silently skipped (with a
  // summary dialog) rather than added stale. Mirrors customer_app's reorder.
  async function handleReorder() {
    const merchantId = o!.merchant_id;
    if (!merchantId) return;

    if (cartMerchantId && cartMerchantId !== merchantId && cartLines.length > 0) {
      setDialog({
        title: "Ganti keranjang?",
        message: `Keranjang kamu saat ini berisi pesanan dari toko lain. Memesan lagi dari ${
          o!.merchant?.name ?? "toko ini"
        } akan mengganti isi keranjang.`,
        confirmLabel: "Ganti",
        onConfirm: () => doReorder(merchantId),
      });
      return;
    }
    doReorder(merchantId);
  }

  async function doReorder(merchantId: string) {
    setReordering(true);
    try {
      const { categories } = await getMerchantProducts(merchantId);
      const liveProducts = new Map<string, Product>();
      for (const cat of categories) for (const p of cat.products) liveProducts.set(p.id, p);

      let skipped = 0;
      for (const item of o!.items ?? []) {
        const product = item.product_id ? liveProducts.get(item.product_id) : undefined;
        if (!product || !product.is_available) {
          skipped++;
          continue;
        }
        cartAddItem(merchantId, o!.merchant?.name ?? "", product, [], item.quantity, "");
      }

      if (skipped > 0) {
        setDialog({ title: "Sebagian item dilewati", message: `${skipped} item tidak lagi tersedia dan dilewati.` });
      }
      router.push("/cart");
    } catch {
      setDialog({ title: "Gagal memuat menu toko", message: "Coba lagi dalam beberapa saat.", danger: true });
    } finally {
      setReordering(false);
    }
  }

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
          <div className="flex items-start gap-3">
            <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${orderStatusToneClasses(o.status)}`}>
              <HugeiconsIcon
                icon={o.status === "picked_up" ? Motorbike01Icon : Store01Icon}
                size={20}
                strokeWidth={1.5}
              />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between gap-2">
                <span className={`rounded-full px-3 py-1 text-sm font-medium ${orderStatusToneClasses(o.status)}`}>
                  {orderStatusLabel(o.status)}
                </span>
                {o.payment_type !== "cash" && (
                  <span
                    className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-medium ${
                      o.payment_status === "paid"
                        ? "bg-(--color-accent-soft) text-(--color-accent)"
                        : "bg-(--color-warning-soft) text-(--color-warning)"
                    }`}
                  >
                    {o.payment_status === "paid" ? "Sudah Dibayar" : "Menunggu Pembayaran"}
                  </span>
                )}
              </div>
              <p className="mt-1.5 truncate text-sm text-(--color-ink-soft)">{o.merchant?.name}</p>
              {o.status === "cancelled" && o.cancellation_reason && (
                <p className="mt-1 text-xs text-(--color-ink-faint)">{o.cancellation_reason}</p>
              )}
            </div>
          </div>
        </section>

        {o.status !== "cancelled" && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <OrderProgressTracker status={o.status} />
          </section>
        )}

        {modReq && removedItem && (
          <section className="rounded-2xl border border-(--color-warning-soft) bg-(--color-warning-soft) p-4">
            <button onClick={() => setShowPicker(true)} className="flex w-full items-center gap-3 text-left">
              <HugeiconsIcon icon={Alert02Icon} size={20} strokeWidth={1.5} className="shrink-0 text-(--color-warning)" />
              <div className="flex-1">
                <p className="text-sm font-semibold text-(--color-ink)">
                  {removedItem.quantity}x {removedItem.item_name} tidak tersedia
                </p>
                <p className="text-xs text-(--color-ink-soft)">{modificationReasonLabel(modReq.reason_category, modReq.reason)}</p>
              </div>
              <HugeiconsIcon icon={ArrowRight01Icon} size={16} strokeWidth={1.5} className="shrink-0 text-(--color-ink-faint)" />
            </button>
            <button
              onClick={() =>
                setDialog({
                  title: "Batalkan pesanan ini?",
                  message: "Pembayaran (jika ada) akan direfund ke wallet.",
                  danger: true,
                  confirmLabel: "Ya, Batalkan",
                  onConfirm: () => cancelModification.mutate(),
                })
              }
              disabled={cancelModification.isPending}
              className="mt-3 text-xs font-semibold text-(--color-danger)"
            >
              Batalkan pesanan ini
            </button>
          </section>
        )}

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

        {(o.dropoff_address || o.receiver_name) && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <p className="mb-2.5 text-sm font-medium text-(--color-ink)">Informasi Pengiriman</p>
            <div className="flex flex-col gap-2.5">
              {o.dropoff_address && (
                <div className="flex items-start gap-2.5">
                  <HugeiconsIcon icon={Location01Icon} size={16} strokeWidth={1.5} className="mt-0.5 shrink-0 text-(--color-ink-faint)" />
                  <div>
                    <p className="text-xs text-(--color-ink-faint)">Alamat</p>
                    <p className="text-sm text-(--color-ink)">{o.dropoff_address}</p>
                  </div>
                </div>
              )}
              {o.receiver_name && (
                <div className="flex items-start gap-2.5">
                  <HugeiconsIcon icon={UserIcon} size={16} strokeWidth={1.5} className="mt-0.5 shrink-0 text-(--color-ink-faint)" />
                  <div>
                    <p className="text-xs text-(--color-ink-faint)">Penerima</p>
                    <p className="text-sm text-(--color-ink)">{o.receiver_name}</p>
                  </div>
                </div>
              )}
            </div>
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
          <p className="mb-2.5 text-sm font-medium text-(--color-ink)">Rincian Pembayaran</p>
          <div className="flex flex-col gap-2 text-sm">
            <div className="flex justify-between text-(--color-ink-soft)">
              <span>Subtotal</span>
              <span>{formatIDR(o.subtotal)}</span>
            </div>
            {o.tax_amount > 0 && (
              <div className="flex justify-between text-(--color-ink-soft)">
                <span>Pajak (PPN)</span>
                <span>{formatIDR(o.tax_amount)}</span>
              </div>
            )}
            <div className="flex justify-between text-(--color-ink-soft)">
              <span>Ongkos Kirim</span>
              <span>{formatIDR(o.delivery_fee)}</span>
            </div>
            {o.app_service_fee > 0 && (
              <div className="flex justify-between text-(--color-ink-soft)">
                <span>Biaya Layanan</span>
                <span>{formatIDR(o.app_service_fee)}</span>
              </div>
            )}
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

        {(chatMerchantEligible || chatDriverEligible) && (
          <div className="flex gap-2">
            {chatMerchantEligible && (
              <ChatToggleButton
                label="Chat Toko"
                active={activeChat === "merchant"}
                unread={merchantUnread}
                onClick={() => toggleChat("merchant")}
              />
            )}
            {chatDriverEligible && (
              <ChatToggleButton
                label="Chat Driver"
                active={activeChat === "driver"}
                unread={driverUnread}
                onClick={() => toggleChat("driver")}
              />
            )}
          </div>
        )}

        <div className="flex gap-2">
          {canCancel && (
            <button
              onClick={() =>
                setDialog({
                  title: "Batalkan pesanan ini?",
                  message:
                    o.payment_type !== "cash" && o.payment_status === "paid"
                      ? `Pesanan #${o.order_number} akan dibatalkan dan dana akan dikembalikan ke wallet kamu.`
                      : `Pesanan #${o.order_number} akan dibatalkan. Tindakan ini tidak bisa dibatalkan.`,
                  danger: true,
                  confirmLabel: "Ya, Batalkan",
                  onConfirm: () => cancel.mutate(),
                })
              }
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

        {isDelivered && (
          <div className="flex flex-col gap-2">
            {!hasReview && (
              <button
                onClick={() => setShowReview(true)}
                className="flex items-center justify-center gap-2 rounded-full bg-(--color-accent) py-2.5 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
              >
                <HugeiconsIcon icon={StarIcon} size={16} strokeWidth={1.5} />
                Beri Rating
              </button>
            )}
            <button
              onClick={handleReorder}
              disabled={reordering}
              className="flex items-center justify-center gap-2 rounded-full border border-(--color-accent) py-2.5 text-sm font-semibold text-(--color-accent) disabled:opacity-50"
            >
              <HugeiconsIcon icon={Refresh01Icon} size={16} strokeWidth={1.5} />
              {reordering ? "Memuat menu..." : "Pesan Lagi"}
            </button>
          </div>
        )}

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

        {effectiveChat && (
          <ChatPanel
            title={effectiveChat === "merchant" ? "Chat dengan Toko" : "Chat dengan Driver"}
            userId={userId}
            messages={(effectiveChat === "merchant" ? merchantChat.data : driverChat.data)?.messages ?? []}
            loaded={!!(effectiveChat === "merchant" ? merchantChat.data : driverChat.data)}
            emptyHint={
              effectiveChat === "merchant"
                ? "Toko akan menghubungi kamu di sini jika ada info soal pesananmu."
                : undefined
            }
            chatText={chatText}
            onChangeText={setChatText}
            onSend={() => {
              if (!chatText.trim()) return;
              (effectiveChat === "merchant" ? sendMerchantChat : sendDriverChat).mutate();
            }}
            sending={(effectiveChat === "merchant" ? sendMerchantChat : sendDriverChat).isPending}
            locked={effectiveChat === "merchant" && !merchantHasReplied}
            lockedHint={effectiveChat === "merchant" ? "Menunggu toko membalas dulu..." : undefined}
            error={effectiveChat === "merchant" ? merchantChatError : ""}
          />
        )}
      </div>

      {showReview && (
        <ReviewSheet
          orderId={o.id}
          hasDriver={!!o.driver_id}
          onClose={() => setShowReview(false)}
          onSubmitted={() => {
            setShowReview(false);
            queryClient.invalidateQueries({ queryKey: ["order", params.id] });
          }}
        />
      )}

      {showPicker && o.merchant?.id && (
        <ReplacementPickerSheet
          merchantId={o.merchant.id}
          onClose={() => setShowPicker(false)}
          onConfirm={(picked) => {
            const removedTotal = removedItem?.total_price ?? 0;
            const delta = picked.estimatedTotal - removedTotal;
            const deltaMsg =
              Math.abs(delta) < 1
                ? "Tidak ada selisih harga."
                : delta > 0
                  ? `Perkiraan tambahan bayar: ${formatIDR(delta)}`
                  : `Perkiraan refund: ${formatIDR(-delta)}`;
            setDialog({
              title: `Ganti ke ${picked.quantity}x ${picked.product.name}?`,
              message: deltaMsg,
              confirmLabel: "Ganti",
              onConfirm: () => replace.mutate(picked),
            });
          }}
        />
      )}

      {dialog && <ConfirmDialog {...dialog} onClose={() => setDialog(null)} />}
    </div>
  );
}

function ChatToggleButton({
  label,
  active,
  unread,
  onClick,
}: {
  label: string;
  active: boolean;
  unread: number;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`relative flex flex-1 items-center justify-center gap-2 rounded-full border py-2.5 text-sm font-semibold transition-colors ${
        active
          ? "border-(--color-accent) bg-(--color-accent) text-(--color-accent-contrast)"
          : "border-(--color-accent) text-(--color-accent)"
      }`}
    >
      <HugeiconsIcon icon={Message01Icon} size={16} strokeWidth={1.5} />
      {label}
      {unread > 0 && (
        <span className="absolute -right-1.5 -top-1.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-(--color-danger) px-1 text-[10px] font-bold text-(--color-accent-contrast)">
          {unread > 9 ? "9+" : unread}
        </span>
      )}
    </button>
  );
}

function ChatPanel({
  title,
  userId,
  messages,
  loaded,
  emptyHint,
  chatText,
  onChangeText,
  onSend,
  sending,
  locked,
  lockedHint,
  error,
}: {
  title: string;
  userId: string | undefined;
  messages: { id: string; sender_id: string; text: string }[];
  loaded: boolean;
  emptyHint?: string;
  chatText: string;
  onChangeText: (v: string) => void;
  onSend: () => void;
  sending: boolean;
  locked?: boolean;
  lockedHint?: string;
  error?: string;
}) {
  const disabled = sending || !!locked;
  return (
    <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
      <p className="mb-3 text-sm font-medium text-(--color-ink)">{title}</p>
      <div className="mb-3 flex max-h-60 flex-col gap-2 overflow-y-auto">
        {messages.map((m) => (
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
        {loaded && messages.length === 0 && (
          <p className="text-center text-xs text-(--color-ink-faint)">{emptyHint ?? "Belum ada percakapan."}</p>
        )}
      </div>
      {error && <p className="mb-2 text-xs text-(--color-danger)">{error}</p>}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSend();
        }}
        className="flex gap-2"
      >
        <input
          value={chatText}
          onChange={(e) => onChangeText(e.target.value)}
          disabled={disabled}
          placeholder={locked ? (lockedHint ?? "") : "Tulis pesan..."}
          className="flex-1 rounded-full border border-(--color-border) px-4 py-2.5 text-sm outline-none focus:border-(--color-ink-faint) disabled:opacity-60"
        />
        <button
          type="submit"
          disabled={disabled}
          className="rounded-full bg-(--color-accent) px-4 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-50"
        >
          Kirim
        </button>
      </form>
    </section>
  );
}

export default function OrderDetailPage() {
  return (
    <AuthGuard>
      <OrderDetailContent />
    </AuthGuard>
  );
}
