"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { HugeiconsIcon } from "@hugeicons/react";
import { ArrowLeft01Icon } from "@hugeicons/core-free-icons";
import { AuthGuard } from "@/components/AuthGuard";
import { createAddress } from "@/lib/api/endpoints";
import { reverseGeocode } from "@/lib/geocode";
import { useGeolocation } from "@/lib/hooks/useGeolocation";

const LocationPickerMap = dynamic(() => import("@/components/LocationPickerMap"), { ssr: false });

const DEFAULT_CENTER = { lat: -8.723, lng: 116.203 }; // Kuta, Lombok

function NewAddressContent() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const geo = useGeolocation();

  const [position, setPosition] = useState(DEFAULT_CENTER);
  const [address, setAddress] = useState("");
  const [label, setLabel] = useState("Rumah");
  const [detail, setDetail] = useState("");
  const [geocoding, setGeocoding] = useState(false);
  const [initializedFromGeo, setInitializedFromGeo] = useState(false);

  useEffect(() => {
    if (geo.status === "granted" && !initializedFromGeo) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- one-shot sync from browser geolocation, guarded by initializedFromGeo
      setInitializedFromGeo(true);
      setPosition({ lat: geo.lat!, lng: geo.lng! });
      reverseGeocode(geo.lat!, geo.lng!)
        .then(setAddress)
        .catch(() => {});
    }
  }, [geo.status, geo.lat, geo.lng, initializedFromGeo]);

  async function handleMapChange(lat: number, lng: number) {
    setPosition({ lat, lng });
    setGeocoding(true);
    try {
      const result = await reverseGeocode(lat, lng);
      setAddress(result);
    } catch {
      // keep previous address text
    } finally {
      setGeocoding(false);
    }
  }

  const create = useMutation({
    mutationFn: () =>
      createAddress({
        label,
        address,
        detail,
        latitude: position.lat,
        longitude: position.lng,
        is_default: false,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["addresses"] });
      router.replace("/addresses");
    },
  });

  return (
    <div className="pb-6">
      <div className="sticky top-0 z-20 flex items-center gap-2 border-b border-(--color-border) bg-(--color-surface-raised) px-4 py-3 md:static md:mx-auto md:max-w-2xl md:border-none md:bg-transparent md:px-0 md:pt-8">
        <button onClick={() => router.back()} className="flex h-9 w-9 items-center justify-center text-(--color-ink-soft) md:hidden" aria-label="Kembali">
          <HugeiconsIcon icon={ArrowLeft01Icon} size={20} strokeWidth={1.5} />
        </button>
        <p className="text-base font-semibold text-(--color-ink) md:text-xl">Tambah Alamat</p>
      </div>

      <div className="mx-auto max-w-2xl md:px-0">
        <div className="overflow-hidden md:mt-4 md:rounded-2xl">
          <LocationPickerMap lat={position.lat} lng={position.lng} onChange={handleMapChange} />
        </div>
        <p className="px-4 py-2 text-xs text-(--color-ink-faint) md:px-0">Ketuk peta untuk menandai lokasi pengiriman.</p>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            create.mutate();
          }}
          className="flex flex-col gap-3 px-4 md:px-0"
        >
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Label</span>
            <input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              required
              placeholder="Rumah, Kantor, dll"
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Alamat {geocoding && "(mencari...)"}</span>
            <textarea
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              required
              rows={2}
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-(--color-ink-soft)">Detail (opsional)</span>
            <input
              value={detail}
              onChange={(e) => setDetail(e.target.value)}
              placeholder="Nomor rumah, patokan, dll"
              className="rounded-xl border border-(--color-border) px-3.5 py-2.5 text-sm outline-none focus:border-(--color-ink-faint)"
            />
          </label>
          {create.isError && <p className="text-sm text-(--color-danger)">Gagal menyimpan alamat, coba lagi.</p>}
          <button
            type="submit"
            disabled={create.isPending || !address}
            className="mt-2 rounded-full bg-(--color-accent) py-3 text-sm font-semibold text-(--color-accent-contrast) transition-colors hover:bg-(--color-accent-hover) disabled:opacity-40"
          >
            {create.isPending ? "Menyimpan..." : "Simpan Alamat"}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function NewAddressPage() {
  return (
    <AuthGuard>
      <NewAddressContent />
    </AuthGuard>
  );
}
