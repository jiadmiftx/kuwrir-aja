"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { useMutation, useQueryClient } from "@tanstack/react-query";
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
      <header className="sticky top-0 z-20 flex items-center gap-2 border-b border-gray-100 bg-white px-4 py-3">
        <button onClick={() => router.back()} className="text-xl">
          ←
        </button>
        <p className="text-base font-bold text-gray-800">Tambah Alamat</p>
      </header>

      <LocationPickerMap lat={position.lat} lng={position.lng} onChange={handleMapChange} />
      <p className="px-4 py-2 text-xs text-gray-400">Ketuk peta untuk menandai lokasi pengiriman.</p>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          create.mutate();
        }}
        className="flex flex-col gap-3 px-4"
      >
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Label</span>
          <input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            required
            placeholder="Rumah, Kantor, dll"
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Alamat {geocoding && "(mencari...)"}</span>
          <textarea
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            required
            rows={2}
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-gray-700">Detail (opsional)</span>
          <input
            value={detail}
            onChange={(e) => setDetail(e.target.value)}
            placeholder="Nomor rumah, patokan, dll"
            className="rounded-lg border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
        </label>
        {create.isError && <p className="text-sm text-red-600">Gagal menyimpan alamat, coba lagi.</p>}
        <button
          type="submit"
          disabled={create.isPending || !address}
          className="mt-2 rounded-full bg-emerald-600 py-3 text-sm font-semibold text-white disabled:opacity-50"
        >
          {create.isPending ? "Menyimpan..." : "Simpan Alamat"}
        </button>
      </form>
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
