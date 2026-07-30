"use client";

import { useEffect, useState } from "react";
import { MapContainer, Marker, TileLayer, useMapEvents } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// Avoids leaflet's default marker icon asset-path bug under bundlers by
// using a plain emoji pin instead of the shipped PNG icons.
const pinIcon = L.divIcon({
  html: '<div style="font-size:32px;line-height:1;transform:translate(-50%,-90%)">📍</div>',
  className: "",
  iconSize: [0, 0],
});

function ClickHandler({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({
    click(e) {
      onPick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

function Recenter({ lat, lng }: { lat: number; lng: number }) {
  const map = useMapEvents({});
  useEffect(() => {
    map.setView([lat, lng], map.getZoom());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lat, lng]);
  return null;
}

interface Props {
  lat: number;
  lng: number;
  onChange: (lat: number, lng: number) => void;
}

export default function LocationPickerMap({ lat, lng, onChange }: Props) {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- client-only mount gate; leaflet needs `window`
    setReady(true);
  }, []);
  if (!ready) return <div className="h-64 w-full animate-pulse bg-gray-100" />;

  return (
    <MapContainer center={[lat, lng]} zoom={16} scrollWheelZoom className="h-64 w-full">
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={[lat, lng]} icon={pinIcon} />
      <ClickHandler onPick={onChange} />
      <Recenter lat={lat} lng={lng} />
    </MapContainer>
  );
}
