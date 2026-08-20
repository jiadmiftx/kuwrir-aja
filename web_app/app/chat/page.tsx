"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import {
  ArrowRight01Icon,
  Chatting01Icon,
  CustomerService01Icon,
  Motorbike01Icon,
  Store01Icon,
} from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getChatUnreadCount, getMyOrders } from "@/lib/api/endpoints";
import { canChatDriver, canChatMerchant, orderStatusLabel, orderStatusToneClasses } from "@/lib/order-status";
import type { Order } from "@/lib/api/types";

// Same 4 statuses as customer_app's _ChatListScreen — an order only shows
// up here while there's realistically someone on the other end reading.
const CHAT_STATUSES = ["confirmed", "preparing", "ready", "picked_up"];

function ChatContent() {
  const orders = useQuery({ queryKey: ["orders"], queryFn: getMyOrders });
  const activeOrders = (orders.data?.orders ?? []).filter((o) => CHAT_STATUSES.includes(o.status));
  const anyChattable = activeOrders.length > 0;

  const unread = useQuery({
    queryKey: ["chat-unread"],
    queryFn: getChatUnreadCount,
    enabled: anyChattable,
    refetchInterval: anyChattable ? 30_000 : false,
  });

  return (
    <div className="mx-auto max-w-(--content-width) px-4 pb-6 md:px-8">
      <header className="pt-5 md:pt-8">
        <h1 className="text-xl font-semibold tracking-tight text-(--color-ink) md:text-2xl">Chat</h1>
      </header>

      <div className="mt-5 flex flex-col gap-2.5">
        <ChatRow
          href="/support"
          icon={CustomerService01Icon}
          iconColor="text-(--color-accent)"
          iconBg="bg-(--color-accent-soft)"
          title="Bantuan & Support"
          subtitle="Chat dengan tim admin Cocourir"
          unread={unread.data?.support ?? 0}
        />
      </div>

      {!orders.isLoading && !anyChattable && (
        <div className="flex flex-col items-center gap-3 py-20 text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-(--color-border-soft) text-(--color-ink-faint)">
            <HugeiconsIcon icon={Chatting01Icon} size={28} strokeWidth={1.5} />
          </div>
          <p className="text-sm text-(--color-ink-soft)">Tidak ada chat pesanan aktif</p>
          <p className="text-xs text-(--color-ink-faint)">Chat muncul saat pesanan sedang diproses</p>
        </div>
      )}

      {anyChattable && (
        <section className="mt-7">
          <p className="mb-2.5 text-xs font-semibold tracking-wide text-(--color-ink-faint)">PESANAN AKTIF</p>
          <div className="flex flex-col gap-2.5">
            {activeOrders.map((o) => (
              <OrderChatRows key={o.id} order={o} unread={unread.data} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

function OrderChatRows({
  order,
  unread,
}: {
  order: Order;
  unread: { orders: Record<string, Record<string, number>> } | undefined;
}) {
  const merchantUnread = unread?.orders?.[order.id]?.merchant ?? 0;
  const driverUnread = unread?.orders?.[order.id]?.driver ?? 0;

  return (
    <div className="flex flex-col gap-2.5">
      {canChatMerchant(order.status) && (
        <ChatRow
          href={`/orders/${order.id}?openChat=merchant`}
          icon={Store01Icon}
          iconColor="text-(--color-accent)"
          iconBg="bg-(--color-accent-soft)"
          title={order.merchant?.name ?? "Toko"}
          subtitle={`#${order.order_number} · Chat Toko`}
          unread={merchantUnread}
          status={order.status}
        />
      )}
      {canChatDriver(order) && (
        <ChatRow
          href={`/orders/${order.id}?openChat=driver`}
          icon={Motorbike01Icon}
          iconColor="text-(--color-info)"
          iconBg="bg-(--color-info-soft)"
          title="Driver"
          subtitle={`#${order.order_number} · Chat Driver`}
          unread={driverUnread}
          status={order.status}
        />
      )}
    </div>
  );
}

function ChatRow({
  href,
  icon,
  iconColor,
  iconBg,
  title,
  subtitle,
  unread,
  status,
}: {
  href: string;
  icon: typeof Store01Icon;
  iconColor: string;
  iconBg: string;
  title: string;
  subtitle: string;
  unread: number;
  status?: string;
}) {
  return (
    <Link
      href={href}
      className="flex items-center gap-3 rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-3.5 transition-shadow hover:shadow-md"
    >
      <div className={`relative flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${iconBg}`}>
        <HugeiconsIcon icon={icon} size={19} strokeWidth={1.5} className={iconColor} />
        {unread > 0 && (
          <span className="absolute -right-0.5 -top-0.5 flex h-4.5 min-w-4.5 items-center justify-center rounded-full bg-(--color-danger) px-1 text-[10px] font-bold text-(--color-accent-contrast) ring-2 ring-(--color-surface-raised)">
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold text-(--color-ink)">{title}</p>
        <p className="truncate text-xs text-(--color-ink-faint)">{subtitle}</p>
      </div>
      {status ? (
        <span className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-medium ${orderStatusToneClasses(status)}`}>
          {orderStatusLabel(status)}
        </span>
      ) : (
        <HugeiconsIcon icon={ArrowRight01Icon} size={16} strokeWidth={1.5} className="shrink-0 text-(--color-ink-faint)" />
      )}
    </Link>
  );
}

export default function ChatPage() {
  return (
    <AuthGuard>
      <ChatContent />
    </AuthGuard>
  );
}
