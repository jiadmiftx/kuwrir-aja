"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { Invoice01Icon, Store01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getMyOrders } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { orderStatusLabel, orderStatusToneClasses, isActiveOrder } from "@/lib/order-status";
import type { Order } from "@/lib/api/types";

function OrdersContent() {
  const router = useRouter();
  const orders = useQuery({
    queryKey: ["orders"],
    queryFn: getMyOrders,
    refetchInterval: 15_000, // fallback poll — push notifications are the primary refresh trigger on mobile; web has no push wired yet
  });

  const list = orders.data?.orders ?? [];
  const active = list.filter((o) => isActiveOrder(o.status));
  const past = list.filter((o) => !isActiveOrder(o.status));

  return (
    <div className="mx-auto max-w-(--content-width) px-4 pb-6 md:px-8">
      <header className="pt-5 md:pt-8">
        <h1 className="text-xl font-semibold tracking-tight text-(--color-ink) md:text-2xl">Pesanan Saya</h1>
      </header>

      {list.length === 0 && !orders.isLoading && (
        <div className="flex flex-col items-center gap-4 py-24">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-(--color-border-soft) text-(--color-ink-faint)">
            <HugeiconsIcon icon={Invoice01Icon} size={28} strokeWidth={1.5} />
          </div>
          <p className="text-sm text-(--color-ink-soft)">Belum ada pesanan</p>
          <Link
            href="/"
            className="rounded-full bg-(--color-accent) px-5 py-2.5 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover)"
          >
            Mulai Belanja
          </Link>
        </div>
      )}

      {active.length > 0 && (
        <section className="mt-6">
          <p className="mb-3 text-sm font-medium text-(--color-ink-soft)">Sedang Berlangsung</p>
          <div className="flex flex-col gap-2.5 md:grid md:grid-cols-2">
            {active.map((o) => (
              <OrderCard key={o.id} onClick={() => router.push(`/orders/${o.id}`)} order={o} />
            ))}
          </div>
        </section>
      )}

      {past.length > 0 && (
        <section className="mt-8">
          <p className="mb-3 text-sm font-medium text-(--color-ink-soft)">Riwayat</p>
          <div className="flex flex-col gap-2.5 md:grid md:grid-cols-2">
            {past.map((o) => (
              <OrderCard key={o.id} onClick={() => router.push(`/orders/${o.id}`)} order={o} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

function itemSummary(order: Order) {
  const items = order.items ?? [];
  if (items.length === 0) return null;
  const extra = items.length - 1;
  return extra > 0 ? `${items[0].item_name} +${extra} lainnya` : items[0].item_name;
}

function relativeDate(iso: string) {
  const t = new Date(iso);
  const diffMs = Date.now() - t.getTime();
  const minutes = Math.floor(diffMs / 60_000);
  if (minutes < 60) return `${Math.max(minutes, 0)} menit lalu`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} jam lalu`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} hari lalu`;
  return t.toLocaleDateString("id-ID", { day: "numeric", month: "short", year: "numeric" });
}

/// Informative order card, web equivalent of customer_app's _OrderCard:
/// store icon/logo, name + order number + relative date, status badge,
/// then a divider and an item-summary/total footer row — instead of the
/// old bare number/status/total stack that told a customer nothing about
/// what they actually ordered.
function OrderCard({ order, onClick }: { order: Order; onClick: () => void }) {
  const summary = itemSummary(order);
  return (
    <button
      onClick={onClick}
      className="flex flex-col gap-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-3.5 text-left transition-shadow hover:shadow-md"
    >
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-(--color-accent-soft)">
          {order.merchant?.logo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={order.merchant.logo_url} alt="" className="h-full w-full object-cover" />
          ) : (
            <HugeiconsIcon icon={Store01Icon} size={18} strokeWidth={1.5} className="text-(--color-accent)" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-(--color-ink)">{order.merchant?.name ?? order.order_number}</p>
          <p className="text-xs text-(--color-ink-faint)">
            #{order.order_number} · {relativeDate(order.created_at)}
          </p>
        </div>
        <span className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-medium ${orderStatusToneClasses(order.status)}`}>
          {orderStatusLabel(order.status)}
        </span>
      </div>
      <div className="flex items-center justify-between gap-2 border-t border-(--color-border-soft) pt-2.5">
        <p className="truncate text-xs text-(--color-ink-soft)">{summary ?? " "}</p>
        <p className="shrink-0 text-sm font-bold text-(--color-accent)">{formatIDR(order.total)}</p>
      </div>
    </button>
  );
}

export default function OrdersPage() {
  return (
    <AuthGuard>
      <OrdersContent />
    </AuthGuard>
  );
}
