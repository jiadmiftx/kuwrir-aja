"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
import { AuthGuard } from "@/components/AuthGuard";
import { useCartStore } from "@/lib/stores/cart";
import { useSelectedAddressStore } from "@/lib/stores/selected-address";
import { useAuthStore } from "@/lib/stores/auth";
import { createPayment, getAddresses, getPaymentMethods, placeOrder, quoteOrder } from "@/lib/api/endpoints";
import { formatIDR } from "@/lib/format";
import { ApiError } from "@/lib/api/client";
import type { OrderItemRequest } from "@/lib/api/types";

function CheckoutContent() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const { merchantId, lines, clear } = useCartStore();
  const { addressId } = useSelectedAddressStore();

  const addresses = useQuery({ queryKey: ["addresses"], queryFn: getAddresses });
  const selectedAddress = addresses.data?.addresses.find((a) => a.id === addressId) ?? addresses.data?.addresses[0];

  const [receiverName, setReceiverName] = useState(user?.name ?? "");
  const [receiverPhone, setReceiverPhone] = useState(user?.phone ?? "");
  const [notes, setNotes] = useState("");
  const [promoInput, setPromoInput] = useState("");
  const [promoCode, setPromoCode] = useState("");
  const [error, setError] = useState("");
  // "cash" or a Duitku channel code (e.g. "VC", "QRIS", "OV") — mirrors the
  // Flutter checkout screen, where the order's payment_type IS the exact
  // channel code the customer picked, not a generic "online" marker.
  const [paymentType, setPaymentType] = useState("cash");

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
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Checkout</p>
      </header>

      <section className="border-b border-gray-100 px-4 py-3">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-sm font-semibold text-gray-800">Alamat Pengiriman</p>
          <Link href="/addresses?pick=1" className="text-xs text-emerald-600">
            Ganti
          </Link>
        </div>
        {selectedAddress ? (
          <div className="rounded-lg bg-gray-50 p-3">
            <p className="text-sm font-medium text-gray-800">{selectedAddress.label}</p>
            <p className="text-xs text-gray-500">{selectedAddress.address}</p>
          </div>
        ) : (
          <Link href="/addresses/new" className="block rounded-lg bg-amber-50 p-3 text-xs text-amber-700">
            Belum ada alamat — tambahkan alamat pengiriman
          </Link>
        )}
      </section>

      <section className="border-b border-gray-100 px-4 py-3">
        <p className="mb-2 text-sm font-semibold text-gray-800">Penerima</p>
        <div className="flex flex-col gap-2">
          <input
            value={receiverName}
            onChange={(e) => setReceiverName(e.target.value)}
            placeholder="Nama penerima"
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <input
            value={receiverPhone}
            onChange={(e) => setReceiverPhone(e.target.value)}
            placeholder="No. HP penerima"
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
        </div>
      </section>

      <section className="border-b border-gray-100 px-4 py-3">
        <p className="mb-2 text-sm font-semibold text-gray-800">Kode Promo</p>
        <div className="flex gap-2">
          <input
            value={promoInput}
            onChange={(e) => setPromoInput(e.target.value.toUpperCase())}
            placeholder="Masukkan kode promo"
            className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <button
            onClick={() => setPromoCode(promoInput)}
            className="rounded-lg border border-emerald-600 px-4 text-sm font-semibold text-emerald-600"
          >
            Pakai
          </button>
        </div>
        {promoCode && quote.data && quote.data.discount_amount > 0 && (
          <p className="mt-1.5 text-xs text-emerald-600">
            Kode &quot;{promoCode}&quot; diterapkan · hemat {formatIDR(quote.data.discount_amount)}
          </p>
        )}
        {promoCode && quote.isError && <p className="mt-1.5 text-xs text-red-500">Kode promo tidak valid</p>}
      </section>

      <section className="border-b border-gray-100 px-4 py-3">
        <p className="mb-2 text-sm font-semibold text-gray-800">Metode Pembayaran</p>
        <div className="flex flex-col gap-2">
          <label
            className={`flex items-center gap-2 rounded-lg border p-3 text-sm ${
              paymentType === "cash" ? "border-emerald-500 bg-emerald-50 text-emerald-700" : "border-gray-200 text-gray-700"
            }`}
          >
            <input type="radio" checked={paymentType === "cash"} onChange={() => setPaymentType("cash")} />
            💵 Bayar di Tempat (COD)
          </label>

          {paymentMethods.isLoading && <p className="text-xs text-gray-400">Memuat metode pembayaran online...</p>}
          {paymentMethods.data?.payment_methods.map((m) => (
            <label
              key={m.paymentMethod}
              className={`flex items-center justify-between gap-2 rounded-lg border p-3 text-sm ${
                paymentType === m.paymentMethod
                  ? "border-emerald-500 bg-emerald-50 text-emerald-700"
                  : "border-gray-200 text-gray-700"
              }`}
            >
              <span className="flex items-center gap-2">
                <input
                  type="radio"
                  checked={paymentType === m.paymentMethod}
                  onChange={() => setPaymentType(m.paymentMethod)}
                />
                {m.paymentName}
              </span>
              {m.totalFee && Number(m.totalFee) > 0 && (
                <span className="text-xs text-gray-400">+{formatIDR(Number(m.totalFee))}</span>
              )}
            </label>
          ))}
        </div>
      </section>

      <section className="px-4 py-3">
        <p className="mb-2 text-sm font-semibold text-gray-800">Catatan Pesanan</p>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={2}
          placeholder="Catatan untuk merchant/driver (opsional)"
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
        />
      </section>

      {quote.data && (
        <section className="px-4 py-3">
          <p className="mb-2 text-sm font-semibold text-gray-800">Rincian Biaya</p>
          <div className="flex flex-col gap-1.5 text-sm">
            <div className="flex justify-between text-gray-600">
              <span>Subtotal</span>
              <span>{formatIDR(quote.data.subtotal)}</span>
            </div>
            {quote.data.packaging_fee > 0 && (
              <div className="flex justify-between text-gray-600">
                <span>Biaya Kemasan</span>
                <span>{formatIDR(quote.data.packaging_fee)}</span>
              </div>
            )}
            <div className="flex justify-between text-gray-600">
              <span>Ongkos Kirim</span>
              <span>{formatIDR(quote.data.delivery_fee)}</span>
            </div>
            {quote.data.tax_amount > 0 && (
              <div className="flex justify-between text-gray-600">
                <span>Pajak</span>
                <span>{formatIDR(quote.data.tax_amount)}</span>
              </div>
            )}
            {quote.data.app_service_fee > 0 && (
              <div className="flex justify-between text-gray-600">
                <span>Biaya Layanan</span>
                <span>{formatIDR(quote.data.app_service_fee)}</span>
              </div>
            )}
            {quote.data.discount_amount > 0 && (
              <div className="flex justify-between text-emerald-600">
                <span>Diskon</span>
                <span>-{formatIDR(quote.data.discount_amount)}</span>
              </div>
            )}
            <div className="mt-1 flex justify-between border-t border-gray-100 pt-1.5 text-base font-bold text-gray-800">
              <span>Total</span>
              <span>{formatIDR(quote.data.total)}</span>
            </div>
          </div>
        </section>
      )}

      {(error || quote.isError) && (
        <p className="px-4 text-sm text-red-600">
          {error || (quote.error instanceof ApiError ? quote.error.message : "Gagal menghitung estimasi biaya")}
        </p>
      )}

      <div className="fixed bottom-16 left-0 right-0 z-20 mx-auto max-w-(--shell-width) border-t border-gray-100 bg-white px-4 py-3">
        <button
          disabled={!selectedAddress || !quote.data || place.isPending || !receiverName || !receiverPhone}
          onClick={() => place.mutate()}
          className="w-full rounded-full bg-emerald-600 py-3 text-sm font-semibold text-white disabled:opacity-50"
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
