"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
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
    <div className="pb-6">
      <header className="sticky top-0 z-20 border-b border-gray-100 bg-white px-4 py-3">
        <p className="text-base font-bold text-gray-800">Pesanan Saya</p>
      </header>

      {list.length === 0 && !orders.isLoading && (
        <div className="flex flex-col items-center gap-3 py-20">
          <p className="text-4xl">🧾</p>
          <p className="text-sm text-gray-500">Belum ada pesanan</p>
          <Link href="/" className="rounded-full bg-emerald-600 px-5 py-2 text-sm font-semibold text-white">
            Mulai Belanja
          </Link>
        </div>
      )}

      {active.length > 0 && (
        <section className="px-4 py-3">
          <p className="mb-2 text-sm font-bold text-gray-800">Sedang Berlangsung</p>
          <div className="flex flex-col gap-2">
            {active.map((o) => (
              <OrderRow key={o.id} onClick={() => router.push(`/orders/${o.id}`)} order={o} />
            ))}
          </div>
        </section>
      )}

      {past.length > 0 && (
        <section className="px-4 py-3">
          <p className="mb-2 text-sm font-bold text-gray-800">Riwayat</p>
          <div className="flex flex-col gap-2">
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
    <button onClick={onClick} className="flex flex-col gap-1 rounded-xl border border-gray-100 p-3 text-left shadow-sm">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold text-gray-800">{order.merchant?.name ?? order.order_number}</p>
        <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-medium text-emerald-700">
          {orderStatusLabel(order.status)}
        </span>
      </div>
      <p className="text-xs text-gray-500">#{order.order_number}</p>
      <p className="text-sm font-bold text-gray-800">{formatIDR(order.total)}</p>
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
