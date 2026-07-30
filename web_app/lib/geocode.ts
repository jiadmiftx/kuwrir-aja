// Public Nominatim reverse geocoding, called directly from the browser.
// Production docker-compose deliberately has no self-hosted Nominatim (see
// plan) — acceptable for the traffic this MVP expects; revisit with a
// backend proxy + caching if volume grows.
export async function reverseGeocode(lat: number, lng: number): Promise<string> {
  const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=0`;
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error("Gagal mengambil alamat");
  const data = await res.json();
  return data?.display_name ?? `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
}
