"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { Invoice01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getMyOrders } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { orderStatusLabel, isActiveOrder } from "@/lib/order-status";
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
              <OrderRow key={o.id} onClick={() => router.push(`/orders/${o.id}`)} order={o} />
            ))}
          </div>
        </section>
      )}

      {past.length > 0 && (
        <section className="mt-8">
          <p className="mb-3 text-sm font-medium text-(--color-ink-soft)">Riwayat</p>
          <div className="flex flex-col gap-2.5 md:grid md:grid-cols-2">
            {past.map((o) => (
              <OrderRow key={o.id} onClick={() => router.push(`/orders/${o.id}`)} order={o} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

function OrderRow({ order, onClick }: { order: Order; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="flex flex-col gap-1 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-3.5 text-left transition-shadow hover:shadow-md"
    >
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium text-(--color-ink)">{order.merchant?.name ?? order.order_number}</p>
        <span className="rounded-full bg-(--color-accent-soft) px-2 py-0.5 text-[11px] font-medium text-(--color-accent)">
          {orderStatusLabel(order.status)}
        </span>
      </div>
      <p className="text-xs text-(--color-ink-faint)">#{order.order_number}</p>
      <p className="text-sm font-semibold text-(--color-ink)">{formatIDR(order.total)}</p>
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
