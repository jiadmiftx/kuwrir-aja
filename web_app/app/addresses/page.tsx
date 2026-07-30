"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon, PlusSignIcon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { getAddresses, deleteAddress, setDefaultAddress } from "@/lib/api/endpoints";
import { useSelectedAddressStore } from "@/lib/stores/selected-address";

function AddressesContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const pickMode = searchParams.get("pick") === "1";
  const queryClient = useQueryClient();
  const { addressId, setAddressId } = useSelectedAddressStore();

  const addresses = useQuery({ queryKey: ["addresses"], queryFn: getAddresses });

  const del = useMutation({
    mutationFn: deleteAddress,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["addresses"] }),
  });
  const setDefault = useMutation({
    mutationFn: setDefaultAddress,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["addresses"] }),
  });

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-(--content-width) md:border-none md:bg-transparent md:px-8 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">{pickMode ? "Pilih Alamat" : "Alamat Tersimpan"}</p>
      </div>

      <div className="mx-auto max-w-(--content-width) px-4 md:px-8">
        <div className="flex flex-col gap-2.5 py-4 md:grid md:grid-cols-2">
          {addresses.data?.addresses.map((addr) => (
            <div
              key={addr.id}
              className={`rounded-2xl border p-3.5 ${
                pickMode && addressId === addr.id
                  ? "border-(--color-accent) bg-(--color-accent-soft)"
                  : "border-(--color-border) bg-(--color-surface-raised)"
              }`}
              onClick={() => {
                if (pickMode) {
                  setAddressId(addr.id);
                  router.back();
                }
              }}
              role={pickMode ? "button" : undefined}
            >
              <div className="flex items-center justify-between">
                <p className="text-sm font-medium text-(--color-ink)">
                  {addr.label} {addr.is_default && <span className="ml-1 text-xs text-(--color-accent)">(Utama)</span>}
                </p>
                {!pickMode && (
                  <div className="flex gap-3 text-xs">
                    {!addr.is_default && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setDefault.mutate(addr.id);
                        }}
                        className="font-medium text-(--color-accent)"
                      >
                        Jadikan Utama
                      </button>
                    )}
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        if (confirm("Hapus alamat ini?")) del.mutate(addr.id);
                      }}
                      className="font-medium text-(--color-danger)"
                    >
                      Hapus
                    </button>
                  </div>
                )}
              </div>
              <p className="mt-0.5 text-xs text-(--color-ink-soft)">{addr.address}</p>
              {addr.detail && <p className="text-xs text-(--color-ink-faint)">{addr.detail}</p>}
            </div>
          ))}
          {addresses.data && addresses.data.addresses.length === 0 && (
            <p className="py-8 text-center text-sm text-(--color-ink-faint)">Belum ada alamat tersimpan.</p>
          )}
        </div>

        <Link
          href="/addresses/new"
          className="mb-4 flex w-full max-w-md items-center justify-center gap-2 rounded-full border border-(--color-accent) py-3 text-sm font-semibold text-(--color-accent)"
        >
          <HugeiconsIcon icon={PlusSignIcon} size={16} strokeWidth={1.5} />
          Tambah Alamat Baru
        </Link>
      </div>
    </div>
  );
}

export default function AddressesPage() {
  return (
    <AuthGuard>
      <AddressesContent />
    </AuthGuard>
  );
}
