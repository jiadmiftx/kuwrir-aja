"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
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
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">{pickMode ? "Pilih Alamat" : "Alamat Tersimpan"}</p>
      </header>

      <div className="flex flex-col gap-2 p-4">
        {addresses.data?.addresses.map((addr) => (
          <div
            key={addr.id}
            className={`rounded-xl border p-3 ${
              pickMode && addressId === addr.id ? "border-emerald-500 bg-emerald-50" : "border-gray-100"
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
              <p className="text-sm font-semibold text-gray-800">
                {addr.label} {addr.is_default && <span className="ml-1 text-xs text-emerald-600">(Utama)</span>}
              </p>
              {!pickMode && (
                <div className="flex gap-2 text-xs">
                  {!addr.is_default && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setDefault.mutate(addr.id);
                      }}
                      className="text-emerald-600"
                    >
                      Jadikan Utama
                    </button>
                  )}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      if (confirm("Hapus alamat ini?")) del.mutate(addr.id);
                    }}
                    className="text-red-500"
                  >
                    Hapus
                  </button>
                </div>
              )}
            </div>
            <p className="mt-0.5 text-xs text-gray-500">{addr.address}</p>
            {addr.detail && <p className="text-xs text-gray-400">{addr.detail}</p>}
          </div>
        ))}
        {addresses.data && addresses.data.addresses.length === 0 && (
          <p className="py-8 text-center text-sm text-gray-400">Belum ada alamat tersimpan.</p>
        )}
      </div>

      <div className="px-4">
        <Link
          href="/addresses/new"
          className="block w-full rounded-full border border-emerald-600 py-3 text-center text-sm font-semibold text-emerald-600"
        >
          + Tambah Alamat Baru
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
