"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import {
  ArrowLeft01Icon,
  Location01Icon,
  UserIcon,
  Discount01Icon,
  Cash01Icon,
  CreditCardIcon,
  StickyNote01Icon,
  ArrowDown01Icon,
} from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { useCartStore } from "@/lib/stores/cart";
import { useSelectedAddressStore } from "@/lib/stores/selected-address";
import { useAuthStore } from "@/lib/stores/auth";
import { createPayment, getAddresses, getPaymentMethods, placeOrder, quoteOrder } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { ApiError } from "@/lib/api/client";
import type { OrderItemRequest, PaymentMethod } from "@/lib/api/types";

function SectionCard({
  icon,
  title,
  action,
  children,
}: {
  icon: Parameters<typeof HugeiconsIcon>[0]["icon"];
  title: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <HugeiconsIcon icon={icon} size={16} strokeWidth={1.5} className="text-(--color-ink-faint)" />
          <p className="text-sm font-medium text-(--color-ink)">{title}</p>
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

function PaymentMethodOption({
  method,
  selected,
  onSelect,
}: {
  method: PaymentMethod;
  selected: boolean;
  onSelect: (code: string) => void;
}) {
  return (
    <label
      className={`flex items-center justify-between gap-2 rounded-xl border p-3 text-sm transition-colors ${
        selected ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)" : "border-(--color-border) text-(--color-ink-soft)"
      }`}
    >
      <span className="flex items-center gap-2.5">
        <input type="radio" checked={selected} onChange={() => onSelect(method.paymentMethod)} className="accent-(--color-accent)" />
        {method.paymentName}
      </span>
      {method.totalFee && Number(method.totalFee) > 0 && (
        <span className="text-xs text-(--color-ink-faint)">+{formatIDR(Number(method.totalFee))}</span>
      )}
    </label>
  );
}

function CheckoutContent() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const { merchantId, lines, clear } = useCartStore();
  const { addressId } = useSelectedAddressStore();

  const addresses = useQuery({ queryKey: ["addresses"], queryFn: getAddresses });
  const selectedAddress = addresses.data?.addresses.find((a) => a.id === addressId) ?? addresses.data?.addresses[0];

  const [receiverName, setReceiverName] = useState(user?.name ?? "");
  const [receiverPhone, setReceiverPhone] = useState(user?.phone ?? "");
  const [isEditingReceiver, setIsEditingReceiver] = useState(!user?.name || !user?.phone);
  const [notes, setNotes] = useState("");
  const [promoInput, setPromoInput] = useState("");
  const [promoCode, setPromoCode] = useState("");
  const [error, setError] = useState("");
  // "cash" or a Duitku channel code (e.g. "VC", "QRIS", "OV") — mirrors the
  // Flutter checkout screen, where the order's payment_type IS the exact
  // channel code the customer picked, not a generic "online" marker.
  const [paymentType, setPaymentType] = useState("cash");
  const [showOtherMethods, setShowOtherMethods] = useState(false);

  useEffect(() => {
    if (lines.length === 0) router.replace("/cart");
  }, [lines.length, router]);

  const items: OrderItemRequest[] = useMemo(
    () =>
      lines.map((l) => ({
        product_id: l.productId,
        quantity: l.quantity,
        notes: l.notes,
        variant_ids: l.variantIds,
      })),
    [lines]
  );

  const quote = useQuery({
    queryKey: ["quote", merchantId, items, selectedAddress?.id, promoCode, paymentType],
    queryFn: () =>
      quoteOrder({
        merchant_id: merchantId!,
        items,
        dropoff_lat: selectedAddress!.latitude,
        dropoff_lng: selectedAddress!.longitude,
        payment_type: paymentType,
        promo_code: promoCode,
      }),
    enabled: !!merchantId && items.length > 0 && !!selectedAddress,
  });

  // Loaded off the cash-quote total once known (channel fees can vary by
  // amount tier) — same order Flutter's checkout screen does it in.
  const paymentMethods = useQuery({
    queryKey: ["payment-methods", quote.data?.total],
    queryFn: () => getPaymentMethods(Math.round(quote.data!.total)),
    enabled: !!quote.data && quote.data.total > 0,
  });
  // QRIS surfaces as its own option (most-used channel); everything else
  // (VA, e-wallet, card, retail, PayLater) sits behind "Metode pembayaran
  // lain" so the default list stays short - Cash + QRIS - instead of
  // dumping 15+ channels on the customer at once.
  const qrisMethods = paymentMethods.data?.payment_methods.filter((m) => m.paymentName === "QRIS") ?? [];
  const otherMethods = paymentMethods.data?.payment_methods.filter((m) => m.paymentName !== "QRIS") ?? [];

  const place = useMutation({
    mutationFn: async () => {
      const { order } = await placeOrder({
        merchant_id: merchantId!,
        items,
        dropoff_address: selectedAddress!.address,
        dropoff_lat: selectedAddress!.latitude,
        dropoff_lng: selectedAddress!.longitude,
        receiver_name: receiverName,
        receiver_phone: receiverPhone,
        payment_type: paymentType,
        notes,
        promo_code: promoCode,
      });
      clear();
      if (paymentType === "cash") return { order, paymentUrl: null };
      // Order is placed either way — if link creation fails, the customer
      // can still retry payment from the order detail screen.
      try {
        const payment = await createPayment(order.id, paymentType);
        return { order, paymentUrl: payment.payment_url };
      } catch {
        return { order, paymentUrl: null };
      }
    },
    onSuccess: ({ order, paymentUrl }) => {
      if (paymentUrl) {
        window.location.href = paymentUrl;
        return;
      }
      router.replace(`/orders/${order.id}`);
    },
    onError: (err) => setError(err instanceof ApiError ? err.message : "Gagal membuat pesanan"),
  });

  return (
    <div className="pb-28">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Checkout</p>
      </div>

      <div className="mx-auto flex max-w-2xl flex-col gap-3 px-4 py-4 md:px-0">
        <SectionCard
          icon={Location01Icon}
          title="Alamat Pengiriman"
          action={
            <Link href="/addresses?pick=1" className="text-xs font-medium text-(--color-accent)">
              Ganti
            </Link>
          }
        >
          {selectedAddress ? (
            <div className="rounded-xl bg-(--color-surface) p-3">
              <p className="text-sm font-medium text-(--color-ink)">{selectedAddress.label}</p>
              <p className="text-xs text-(--color-ink-faint)">{selectedAddress.address}</p>
            </div>
          ) : (
            <Link href="/addresses/new" className="block rounded-xl bg-(--color-warning-soft) p-3 text-xs text-(--color-warning)">
              Belum ada alamat — tambahkan alamat pengiriman
            </Link>
          )}
        </SectionCard>

        <SectionCard
          icon={UserIcon}
          title="Penerima"
          action={
            !isEditingReceiver && (
              <button onClick={() => setIsEditingReceiver(true)} className="text-xs font-medium text-(--color-accent)">
                Ubah
              </button>
            )
          }
        >
          {isEditingReceiver ? (
            <div className="flex flex-col gap-2">
              <input
                value={receiverName}
                onChange={(e) => setReceiverName(e.target.value)}
                placeholder="Nama penerima"
                className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
              />
              <input
                value={receiverPhone}
                onChange={(e) => setReceiverPhone(e.target.value)}
                placeholder="No. HP penerima"
                className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
              />
              {receiverName && receiverPhone && (
                <button
                  onClick={() => setIsEditingReceiver(false)}
                  className="self-start text-xs font-medium text-(--color-accent)"
                >
                  Selesai
                </button>
              )}
            </div>
          ) : (
            <div className="rounded-xl bg-(--color-surface) p-3">
              <p className="text-sm font-medium text-(--color-ink)">{receiverName}</p>
              <p className="text-xs text-(--color-ink-faint)">{receiverPhone}</p>
            </div>
          )}
        </SectionCard>

        <SectionCard icon={Discount01Icon} title="Kode Promo">
          <div className="flex gap-2">
            <input
              value={promoInput}
              onChange={(e) => setPromoInput(e.target.value.toUpperCase())}
              placeholder="Masukkan kode promo"
              className="flex-1 rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
            <button
              onClick={() => setPromoCode(promoInput)}
              className="rounded-xl border border-(--color-accent) px-4 text-sm font-medium text-(--color-accent)"
            >
              Pakai
            </button>
          </div>
          {promoCode && quote.data && quote.data.discount_amount > 0 && (
            <p className="mt-2 text-xs text-(--color-accent)">
              Kode &quot;{promoCode}&quot; diterapkan · hemat {formatIDR(quote.data.discount_amount)}
            </p>
          )}
          {promoCode && quote.isError && <p className="mt-2 text-xs text-(--color-danger)">Kode promo tidak valid</p>}
        </SectionCard>

        <SectionCard icon={CreditCardIcon} title="Metode Pembayaran">
          <div className="flex flex-col gap-2">
            <label
              className={`flex items-center gap-2.5 rounded-xl border p-3 text-sm transition-colors ${
                paymentType === "cash"
                  ? "border-(--color-accent) bg-(--color-accent-soft) text-(--color-accent)"
                  : "border-(--color-border) text-(--color-ink-soft)"
              }`}
            >
              <input type="radio" checked={paymentType === "cash"} onChange={() => setPaymentType("cash")} className="accent-(--color-accent)" />
              <HugeiconsIcon icon={Cash01Icon} size={17} strokeWidth={1.5} />
              Bayar di Tempat (COD)
            </label>

            {paymentMethods.isLoading && <p className="text-xs text-(--color-ink-faint)">Memuat metode pembayaran online...</p>}
            {qrisMethods.map((m) => (
              <PaymentMethodOption key={m.paymentMethod} method={m} selected={paymentType === m.paymentMethod} onSelect={setPaymentType} />
            ))}

            {otherMethods.length > 0 && (
              <div className="rounded-xl border border-(--color-border)">
                <button
                  type="button"
                  onClick={() => setShowOtherMethods((v) => !v)}
                  className="flex w-full items-center justify-between p-3 text-sm text-(--color-ink-soft)"
                >
                  <span>Metode pembayaran lain</span>
                  <HugeiconsIcon
                    icon={ArrowDown01Icon}
                    size={16}
                    strokeWidth={1.5}
                    className={`transition-transform ${showOtherMethods ? "rotate-180" : ""}`}
                  />
                </button>
                {showOtherMethods && (
                  <div className="flex flex-col gap-2 border-t border-(--color-border) p-3 pt-2">
                    {otherMethods.map((m) => (
                      <PaymentMethodOption key={m.paymentMethod} method={m} selected={paymentType === m.paymentMethod} onSelect={setPaymentType} />
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </SectionCard>

        <SectionCard icon={StickyNote01Icon} title="Catatan Pesanan">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            placeholder="Catatan untuk merchant/driver (opsional)"
            className="w-full rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
          />
        </SectionCard>

        {quote.data && (
          <section className="rounded-2xl border border-(--color-border) bg-(--color-surface-raised) p-4">
            <p className="mb-3 text-sm font-medium text-(--color-ink)">Rincian Biaya</p>
            <div className="flex flex-col gap-2 text-sm">
              <div className="flex justify-between text-(--color-ink-soft)">
                <span>Subtotal</span>
                <span>{formatIDR(quote.data.subtotal)}</span>
              </div>
              {quote.data.packaging_fee > 0 && (
                <div className="flex justify-between text-(--color-ink-soft)">
                  <span>Biaya Kemasan</span>
                  <span>{formatIDR(quote.data.packaging_fee)}</span>
                </div>
              )}
              <div className="flex justify-between text-(--color-ink-soft)">
                <span>Ongkos Kirim</span>
                <span>{formatIDR(quote.data.delivery_fee)}</span>
              </div>
              {quote.data.tax_amount > 0 && (
                <div className="flex justify-between text-(--color-ink-soft)">
                  <span>Pajak</span>
                  <span>{formatIDR(quote.data.tax_amount)}</span>
                </div>
              )}
              {quote.data.app_service_fee > 0 && (
                <div className="flex justify-between text-(--color-ink-soft)">
                  <span>Biaya Layanan</span>
                  <span>{formatIDR(quote.data.app_service_fee)}</span>
                </div>
              )}
              {quote.data.discount_amount > 0 && (
                <div className="flex justify-between text-(--color-accent)">
                  <span>Diskon</span>
                  <span>-{formatIDR(quote.data.discount_amount)}</span>
                </div>
              )}
              <div className="mt-1 flex justify-between border-t border-(--color-border) pt-2 text-base font-semibold text-(--color-ink)">
                <span>Total</span>
                <span>{formatIDR(quote.data.total)}</span>
              </div>
            </div>
          </section>
        )}

        {(error || quote.isError) && (
          <p className="text-sm text-(--color-danger)">
            {error || (quote.error instanceof ApiError ? quote.error.message : "Gagal menghitung estimasi biaya")}
          </p>
        )}
      </div>

      <div className="fixed bottom-16 left-0 right-0 z-20 mx-auto max-w-2xl border-t border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mt-3 md:max-w-2xl md:rounded-2xl md:border md:px-5">
        <button
          disabled={!selectedAddress || !quote.data || place.isPending || !receiverName || !receiverPhone}
          onClick={() => place.mutate()}
          className="w-full rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
        >
          {place.isPending ? "Memproses..." : quote.data ? `Buat Pesanan · ${formatIDR(quote.data.total)}` : "Buat Pesanan"}
        </button>
      </div>
    </div>
  );
}

export default function CheckoutPage() {
  return (
    <AuthGuard>
      <CheckoutContent />
    </AuthGuard>
  );
}
