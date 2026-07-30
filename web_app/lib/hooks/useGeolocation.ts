"use client";

import { useEffect, useState } from "react";

interface GeoState {
  lat: number | null;
  lng: number | null;
  status: "idle" | "loading" | "granted" | "denied" | "unsupported";
}

export function useGeolocation() {
  const [state, setState] = useState<GeoState>({ lat: null, lng: null, status: "idle" });

  useEffect(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- one-shot sync with the browser Geolocation API, not derivable from render
      setState((s) => ({ ...s, status: "unsupported" }));
      return;
    }
    setState((s) => ({ ...s, status: "loading" }));
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        setState({ lat: pos.coords.latitude, lng: pos.coords.longitude, status: "granted" }),
      () => setState((s) => ({ ...s, status: "denied" })),
      { enableHighAccuracy: true, timeout: 10_000 }
    );
  }, []);

  return state;
}
