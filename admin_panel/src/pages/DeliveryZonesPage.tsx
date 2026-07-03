import { useState, useEffect, useMemo } from 'react'
import { MapContainer, TileLayer, Circle, GeoJSON as GeoJSONLayer, Marker, Popup } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Plus, Pencil, Trash2, X, CheckSquare, Square } from 'lucide-react'
import { toast } from 'sonner'
import { apiFetch as api } from '@/lib/api'

// Fix default marker icons (Leaflet asset path issue in Vite)
delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
})

const ZONE_COLORS = ['#16a34a', '#2563eb', '#9333ea', '#ea580c', '#0891b2']

interface Zone {
  id: string
  city_name: string
  latitude: number
  longitude: number
  radius_km: number
  base_fee: number
  per_km_fee: number
  is_default: boolean
  is_active: boolean
  osm_relation_id?: number
  boundary_geojson?: string
  parent_zone_id?: string | null
  children?: Zone[]
}

interface Driver {
  id: string
  latitude: number
  longitude: number
  is_online: boolean
  zone_id?: string
  user?: { name: string; phone: string }
}

interface Merchant {
  id: string
  name: string
  latitude: number
  longitude: number
  is_open: boolean
  zone_id?: string
}

interface NominatimResult {
  osm_id: number
  display_name: string
  lat: string
  lon: string
  geojson?: { type: string; coordinates: unknown }
}

// Overpass-derived kecamatan candidate. Full polygon is filled in afterwards
// via a batched Nominatim /lookup call, same source as the kota search.
interface KecamatanCandidate {
  osmId: number
  name: string
  lat?: number
  lon?: number
  geojson?: string
}

const fmt = (v: number) => 'Rp ' + v.toLocaleString('id-ID')
const LOMBOK_CENTER: [number, number] = [-8.6524, 116.3241]

const emptyForm = (): Partial<Zone> => ({
  city_name: '',
  latitude: 0,
  longitude: 0,
  radius_km: 5,
  base_fee: 15000,
  per_km_fee: 10000,
  is_default: false,
  is_active: true,
  boundary_geojson: undefined,
  osm_relation_id: undefined,
  parent_zone_id: null,
})

export default function DeliveryZonesPage() {
  const [zones, setZones] = useState<Zone[]>([])
  const [zonesLoading, setZonesLoading] = useState(true)
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [merchants, setMerchants] = useState<Merchant[]>([])
  const [showDrivers, setShowDrivers] = useState(true)
  const [showMerchants, setShowMerchants] = useState(true)
  const [showZones, setShowZones] = useState(true)

  // Panel: which kota is being created/edited (null = panel closed)
  const [panelOpen, setPanelOpen] = useState(false)
  const [editingZone, setEditingZone] = useState<Zone | null>(null)
  const [form, setForm] = useState<Partial<Zone>>(emptyForm())
  const [saving, setSaving] = useState(false)

  // Kota search (Nominatim)
  const [citySearch, setCitySearch] = useState('')
  const [cityResults, setCityResults] = useState<NominatimResult[]>([])
  const [citySearching, setCitySearching] = useState(false)

  // Kecamatan auto-fetch (Overpass listing + batched Nominatim polygons)
  const [kecamatanCandidates, setKecamatanCandidates] = useState<KecamatanCandidate[]>([])
  const [kecamatanLoading, setKecamatanLoading] = useState(false)
  const [kecamatanError, setKecamatanError] = useState<string | null>(null)
  const [selectedKecamatan, setSelectedKecamatan] = useState<Set<number>>(new Set())
  const [kecamatanFilter, setKecamatanFilter] = useState('')

  // Manual kecamatan fallback (separate search, deliberately isolated from
  // the kota search above — mixing the two is what caused kecamatan fields
  // to save as kota before).
  const [manualSearch, setManualSearch] = useState('')
  const [manualResults, setManualResults] = useState<NominatimResult[]>([])
  const [manualSearching, setManualSearching] = useState(false)
  const [manualPicked, setManualPicked] = useState<KecamatanCandidate[]>([])

  const fetchZones = () => {
    setZonesLoading(true)
    api('/api/v1/admin/delivery-zones')
      .then((r) => r.json())
      .then((d) => setZones(d.zones ?? []))
      .catch(() => {})
      .finally(() => setZonesLoading(false))
  }

  useEffect(() => {
    fetchZones()
    api('/api/v1/admin/drivers').then((r) => r.json()).then((d) => setDrivers(d.drivers ?? []))
    api('/api/v1/admin/merchants').then((r) => r.json()).then((d) => setMerchants(d.merchants ?? []))
  }, [])

  const resetPanel = () => {
    setEditingZone(null)
    setForm(emptyForm())
    setCitySearch('')
    setCityResults([])
    setKecamatanCandidates([])
    setSelectedKecamatan(new Set())
    setKecamatanError(null)
    setKecamatanFilter('')
    setManualSearch('')
    setManualResults([])
    setManualPicked([])
  }

  const openAddZone = () => {
    resetPanel()
    setPanelOpen(true)
  }

  const closePanel = () => {
    setPanelOpen(false)
    resetPanel()
  }

  // ── Kecamatan auto-fetch: Overpass lists admin_level=6 members of the
  // kota relation, then one batched Nominatim /lookup fetches all their
  // polygons in a single request (same polygon source already used for kota).
  const fetchKecamatan = async (kotaRelationId: number) => {
    setKecamatanLoading(true)
    setKecamatanError(null)
    setKecamatanCandidates([])
    try {
      const query = `[out:json][timeout:25];relation(${kotaRelationId});map_to_area->.a;relation["admin_level"="6"]["boundary"="administrative"](area.a);out tags center;`
      const res = await fetch('https://overpass-api.de/api/interpreter', {
        method: 'POST',
        body: `data=${encodeURIComponent(query)}`,
      })
      if (!res.ok) throw new Error('overpass failed')
      const data: { elements: { id: number; tags?: { name?: string }; center?: { lat: number; lon: number } }[] } = await res.json()
      const named = data.elements.filter((e) => e.tags?.name)
      if (named.length === 0) {
        setKecamatanCandidates([])
        return
      }

      const osmIds = named.map((e) => `R${e.id}`).join(',')
      const lookupRes = await fetch(
        `https://nominatim.openstreetmap.org/lookup?osm_ids=${osmIds}&format=json&polygon_geojson=1`,
        { headers: { 'User-Agent': 'CocourirAdmin/1.0' } }
      )
      const polygons: NominatimResult[] = lookupRes.ok ? await lookupRes.json() : []
      const polyById = new Map(polygons.map((p) => [p.osm_id, p]))

      const candidates: KecamatanCandidate[] = named.map((e) => {
        const poly = polyById.get(e.id)
        return {
          osmId: e.id,
          name: e.tags!.name!,
          lat: poly ? parseFloat(poly.lat) : e.center?.lat,
          lon: poly ? parseFloat(poly.lon) : e.center?.lon,
          geojson: poly?.geojson ? JSON.stringify(poly.geojson) : undefined,
        }
      })
      candidates.sort((a, b) => a.name.localeCompare(b.name))
      setKecamatanCandidates(candidates)
    } catch {
      setKecamatanError('Gagal mengambil daftar kecamatan. Coba lagi, atau tambah manual di bawah.')
    } finally {
      setKecamatanLoading(false)
    }
  }

  const searchCity = async () => {
    if (!citySearch.trim()) return
    setCitySearching(true)
    setCityResults([])
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(citySearch)}&polygon_geojson=1&format=json&limit=5&countrycodes=id`,
        { headers: { 'User-Agent': 'CocourirAdmin/1.0' } }
      )
      const data: NominatimResult[] = await res.json()
      setCityResults(data.filter((r) => r.geojson?.type === 'Polygon' || r.geojson?.type === 'MultiPolygon'))
    } catch {
      toast.error('Gagal mencari kota')
    } finally {
      setCitySearching(false)
    }
  }

  const applyCity = (result: NominatimResult) => {
    const geoJSON = result.geojson ? JSON.stringify(result.geojson) : undefined
    const simpleName = result.display_name.split(',')[0].trim()
    setForm((f) => ({
      ...f,
      city_name: simpleName,
      latitude: parseFloat(result.lat),
      longitude: parseFloat(result.lon),
      osm_relation_id: result.osm_id,
      boundary_geojson: geoJSON,
    }))
    setCityResults([])
    setCitySearch('')
    toast.success(`Batas wilayah "${simpleName}" berhasil diimport`)
    fetchKecamatan(result.osm_id)
  }

  const openEditZone = (zone: Zone) => {
    setEditingZone(zone)
    setForm({ ...zone })
    setPanelOpen(true)
    setCitySearch('')
    setCityResults([])
    setKecamatanFilter('')
    setManualSearch('')
    setManualResults([])
    setManualPicked([])

    const existingChildIds = new Set((zone.children ?? []).filter((c) => c.osm_relation_id).map((c) => c.osm_relation_id!))
    setSelectedKecamatan(existingChildIds)

    if (zone.osm_relation_id) {
      fetchKecamatan(zone.osm_relation_id).then(() => {
        // Preserve any saved kecamatan without OSM coverage as manually-picked
        setKecamatanCandidates((cands) => {
          const missing = (zone.children ?? []).filter(
            (c) => c.osm_relation_id && !cands.some((cand) => cand.osmId === c.osm_relation_id)
          )
          if (missing.length) {
            setManualPicked(
              missing.map((c) => ({
                osmId: c.osm_relation_id!,
                name: c.city_name,
                lat: c.latitude,
                lon: c.longitude,
                geojson: c.boundary_geojson,
              }))
            )
          }
          return cands
        })
      })
    } else {
      setKecamatanCandidates([])
    }
  }

  const toggleKecamatan = (osmId: number) => {
    setSelectedKecamatan((prev) => {
      const next = new Set(prev)
      if (next.has(osmId)) next.delete(osmId)
      else next.add(osmId)
      return next
    })
  }

  const allCandidates = useMemo(
    () => [...kecamatanCandidates, ...manualPicked],
    [kecamatanCandidates, manualPicked]
  )

  const filteredCandidates = useMemo(
    () =>
      kecamatanFilter.trim()
        ? kecamatanCandidates.filter((c) => c.name.toLowerCase().includes(kecamatanFilter.toLowerCase()))
        : kecamatanCandidates,
    [kecamatanCandidates, kecamatanFilter]
  )

  const selectAll = () => setSelectedKecamatan(new Set(allCandidates.map((c) => c.osmId)))
  const clearAll = () => setSelectedKecamatan(new Set())

  const searchManualKecamatan = async () => {
    if (!manualSearch.trim()) return
    setManualSearching(true)
    setManualResults([])
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(manualSearch)}&polygon_geojson=1&format=json&limit=5&countrycodes=id`,
        { headers: { 'User-Agent': 'CocourirAdmin/1.0' } }
      )
      const data: NominatimResult[] = await res.json()
      setManualResults(data.filter((r) => r.geojson?.type === 'Polygon' || r.geojson?.type === 'MultiPolygon'))
    } catch {
      toast.error('Gagal mencari kecamatan')
    } finally {
      setManualSearching(false)
    }
  }

  const pickManualKecamatan = (result: NominatimResult) => {
    const candidate: KecamatanCandidate = {
      osmId: result.osm_id,
      name: result.display_name.split(',')[0].trim(),
      lat: parseFloat(result.lat),
      lon: parseFloat(result.lon),
      geojson: result.geojson ? JSON.stringify(result.geojson) : undefined,
    }
    setManualPicked((prev) => (prev.some((p) => p.osmId === candidate.osmId) ? prev : [...prev, candidate]))
    setSelectedKecamatan((prev) => new Set(prev).add(candidate.osmId))
    setManualResults([])
    setManualSearch('')
  }

  const handleDeleteZone = async (id: string) => {
    if (!confirm('Hapus zona ini?')) return
    await api(`/api/v1/admin/delivery-zones/${id}`, { method: 'DELETE' })
    fetchZones()
    toast.success('Zona dihapus')
  }

  const handleSave = async () => {
    if (!form.city_name?.trim()) {
      toast.error('Nama kota/kabupaten wajib diisi')
      return
    }
    setSaving(true)
    try {
      let zoneId = editingZone?.id
      if (editingZone) {
        await api(`/api/v1/admin/delivery-zones/${editingZone.id}`, {
          method: 'PUT',
          body: JSON.stringify(form),
        })
      } else {
        const res = await api('/api/v1/admin/delivery-zones', {
          method: 'POST',
          body: JSON.stringify(form),
        })
        const data = await res.json()
        zoneId = data.zone?.id ?? data.id
      }

      const existingChildren = editingZone?.children ?? []
      const existingByOsmId = new Map(existingChildren.filter((c) => c.osm_relation_id).map((c) => [c.osm_relation_id!, c]))

      // Add newly checked kecamatan
      for (const osmId of selectedKecamatan) {
        if (existingByOsmId.has(osmId)) continue
        const cand = allCandidates.find((c) => c.osmId === osmId)
        if (!cand) continue
        await api('/api/v1/admin/delivery-zones', {
          method: 'POST',
          body: JSON.stringify({
            city_name: cand.name,
            latitude: cand.lat ?? form.latitude,
            longitude: cand.lon ?? form.longitude,
            osm_relation_id: cand.osmId,
            boundary_geojson: cand.geojson,
            parent_zone_id: zoneId,
            is_active: true,
          }),
        })
      }

      // Remove unchecked kecamatan that were previously saved
      for (const [osmId, child] of existingByOsmId) {
        if (!selectedKecamatan.has(osmId)) {
          await api(`/api/v1/admin/delivery-zones/${child.id}`, { method: 'DELETE' })
        }
      }

      toast.success(editingZone ? 'Zona diperbarui' : 'Zona ditambahkan')
      closePanel()
      fetchZones()
    } catch {
      toast.error('Gagal menyimpan zona')
    } finally {
      setSaving(false)
    }
  }

  const merchantIcon = L.divIcon({
    html: `<div style="background:#16a34a;color:white;border-radius:50%;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-size:14px;border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,.3)">🏪</div>`,
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  })

  const driverIcon = (online: boolean) =>
    L.divIcon({
      html: `<div style="background:${online ? '#2563eb' : '#94a3b8'};color:white;border-radius:50%;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-size:14px;border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,.3)">🏍️</div>`,
      className: '',
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    })

  return (
    <div className="space-y-4">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Delivery Zones</h2>
          <p className="text-muted-foreground">Kelola wilayah pengiriman, kecamatan layanan, dan lihat sebaran driver/merchant.</p>
        </div>
        {!panelOpen && (
          <Button onClick={openAddZone}>
            <Plus className="mr-2 h-4 w-4" /> Zona Baru
          </Button>
        )}
      </div>

      <div className={`grid gap-4 ${panelOpen ? 'lg:grid-cols-[420px_1fr]' : 'grid-cols-1'}`}>
        {/* ── Left panel: zone list, or the add/edit form ── */}
        {panelOpen ? (
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0">
              <CardTitle className="text-lg">{editingZone ? 'Edit Zona' : 'Tambah Zona Baru'}</CardTitle>
              <Button variant="ghost" size="icon" onClick={closePanel}>
                <X className="h-4 w-4" />
              </Button>
            </CardHeader>
            <CardContent className="space-y-4 max-h-[calc(100vh-220px)] overflow-y-auto">
              {/* Kota search */}
              <div className="space-y-2">
                <Label>Cari Kota/Kabupaten (OpenStreetMap)</Label>
                <div className="flex gap-2">
                  <Input
                    placeholder="Cth: Kota Mataram, Lombok Barat..."
                    value={citySearch}
                    onChange={(e) => setCitySearch(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && searchCity()}
                  />
                  <Button variant="outline" onClick={searchCity} disabled={citySearching} type="button">
                    {citySearching ? '...' : 'Cari'}
                  </Button>
                </div>
                {cityResults.length > 0 && (
                  <div className="rounded-md border bg-popover shadow-sm">
                    {cityResults.map((r) => (
                      <button
                        key={r.osm_id}
                        type="button"
                        className="w-full text-left px-3 py-2 text-sm hover:bg-accent transition-colors border-b last:border-0"
                        onClick={() => applyCity(r)}
                      >
                        <div className="font-medium">{r.display_name.split(',')[0]}</div>
                        <div className="text-xs text-muted-foreground truncate">{r.display_name}</div>
                      </button>
                    ))}
                  </div>
                )}
                {form.city_name && (
                  <p className="text-sm font-medium">
                    Kota terpilih: <span className="text-primary">{form.city_name}</span>
                    {form.boundary_geojson && <span className="text-green-600 text-xs ml-1">✓ polygon</span>}
                  </p>
                )}
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <Label>Base Fee (IDR)</Label>
                  <Input
                    type="number"
                    value={form.base_fee ?? 15000}
                    onChange={(e) => setForm((f) => ({ ...f, base_fee: parseFloat(e.target.value) }))}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Per KM Fee (IDR)</Label>
                  <Input
                    type="number"
                    value={form.per_km_fee ?? 10000}
                    onChange={(e) => setForm((f) => ({ ...f, per_km_fee: parseFloat(e.target.value) }))}
                  />
                </div>
              </div>
              <div className="flex items-center gap-6">
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_default || false}
                    onChange={(e) => setForm((f) => ({ ...f, is_default: e.target.checked }))}
                  />
                  Zona default
                </label>
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_active !== false}
                    onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                  />
                  Aktif
                </label>
              </div>

              <Separator />

              {/* Kecamatan checklist */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label>Kecamatan dalam wilayah layanan</Label>
                  {allCandidates.length > 0 && (
                    <div className="flex gap-1">
                      <Button variant="ghost" size="sm" className="h-6 px-2 text-xs" onClick={selectAll} type="button">
                        <CheckSquare className="h-3 w-3 mr-1" /> Semua
                      </Button>
                      <Button variant="ghost" size="sm" className="h-6 px-2 text-xs" onClick={clearAll} type="button">
                        <Square className="h-3 w-3 mr-1" /> Kosongkan
                      </Button>
                    </div>
                  )}
                </div>
                <p className="text-xs text-muted-foreground">
                  Kecamatan yang tidak dicentang akan dikenakan fee di luar zona (outside zone fee).
                </p>

                {kecamatanLoading && (
                  <p className="text-sm text-muted-foreground py-2">Mengambil daftar kecamatan...</p>
                )}
                {kecamatanError && <p className="text-sm text-destructive py-1">{kecamatanError}</p>}

                {!kecamatanLoading && kecamatanCandidates.length > 0 && (
                  <>
                    <Input
                      placeholder="Filter kecamatan..."
                      value={kecamatanFilter}
                      onChange={(e) => setKecamatanFilter(e.target.value)}
                      className="h-8 text-sm"
                    />
                    <div className="rounded-md border max-h-56 overflow-y-auto divide-y">
                      {filteredCandidates.map((c) => (
                        <label
                          key={c.osmId}
                          className="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-accent/50"
                        >
                          <input
                            type="checkbox"
                            checked={selectedKecamatan.has(c.osmId)}
                            onChange={() => toggleKecamatan(c.osmId)}
                          />
                          {c.name}
                          {!c.geojson && (
                            <span className="text-xs text-muted-foreground ml-auto">tanpa polygon</span>
                          )}
                        </label>
                      ))}
                    </div>
                  </>
                )}

                {!kecamatanLoading && !form.osm_relation_id && kecamatanCandidates.length === 0 && (
                  <p className="text-xs text-muted-foreground py-1">Cari kota di atas untuk mengambil daftar kecamatan otomatis.</p>
                )}
                {!kecamatanLoading && form.osm_relation_id && kecamatanCandidates.length === 0 && !kecamatanError && (
                  <p className="text-xs text-muted-foreground py-1">Tidak ada kecamatan ditemukan untuk kota ini. Tambah manual di bawah.</p>
                )}

                {manualPicked.length > 0 && (
                  <div className="rounded-md border max-h-40 overflow-y-auto divide-y">
                    {manualPicked.map((c) => (
                      <label key={c.osmId} className="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-accent/50">
                        <input type="checkbox" checked={selectedKecamatan.has(c.osmId)} onChange={() => toggleKecamatan(c.osmId)} />
                        {c.name}
                        <span className="text-xs text-muted-foreground ml-auto">manual</span>
                      </label>
                    ))}
                  </div>
                )}

                {/* Manual fallback search */}
                <details className="text-sm">
                  <summary className="cursor-pointer text-muted-foreground hover:text-foreground">
                    + Tambah kecamatan manual
                  </summary>
                  <div className="mt-2 space-y-2">
                    <div className="flex gap-2">
                      <Input
                        placeholder="Cth: Kecamatan Narmada..."
                        value={manualSearch}
                        onChange={(e) => setManualSearch(e.target.value)}
                        onKeyDown={(e) => e.key === 'Enter' && searchManualKecamatan()}
                      />
                      <Button variant="outline" onClick={searchManualKecamatan} disabled={manualSearching} type="button">
                        {manualSearching ? '...' : 'Cari'}
                      </Button>
                    </div>
                    {manualResults.length > 0 && (
                      <div className="rounded-md border bg-popover shadow-sm">
                        {manualResults.map((r) => (
                          <button
                            key={r.osm_id}
                            type="button"
                            className="w-full text-left px-3 py-2 text-sm hover:bg-accent transition-colors border-b last:border-0"
                            onClick={() => pickManualKecamatan(r)}
                          >
                            <div className="font-medium">{r.display_name.split(',')[0]}</div>
                            <div className="text-xs text-muted-foreground truncate">{r.display_name}</div>
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                </details>
              </div>
            </CardContent>
            <div className="flex gap-2 p-4 pt-0">
              <Button variant="outline" onClick={closePanel} className="flex-1">
                Batal
              </Button>
              <Button onClick={handleSave} disabled={saving} className="flex-1">
                {saving ? 'Menyimpan...' : 'Simpan Zona'}
              </Button>
            </div>
          </Card>
        ) : (
          <Card>
            <CardHeader>
              <CardTitle>Daftar Zona</CardTitle>
              <CardDescription>Kota/kabupaten dan kecamatan layanan di dalamnya.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-1">
              {zonesLoading ? (
                <p className="text-muted-foreground text-sm">Memuat zona...</p>
              ) : zones.length === 0 ? (
                <p className="text-muted-foreground text-sm">Belum ada zona. Klik "Zona Baru" untuk menambahkan.</p>
              ) : (
                zones.map((zone, i) => (
                  <div key={zone.id} className="rounded-md border">
                    <div className="flex items-center justify-between px-3 py-2">
                      <div className="flex items-center gap-2 min-w-0">
                        <span
                          className="inline-block w-2.5 h-2.5 rounded-full shrink-0"
                          style={{ background: ZONE_COLORS[i % ZONE_COLORS.length] }}
                        />
                        <span className="font-medium truncate">{zone.city_name}</span>
                        {zone.is_default && <Badge variant="secondary" className="text-xs shrink-0">default</Badge>}
                        <Badge variant={zone.is_active ? 'default' : 'secondary'} className="text-xs shrink-0">
                          {zone.is_active ? 'Aktif' : 'Nonaktif'}
                        </Badge>
                      </div>
                      <div className="flex gap-1 shrink-0">
                        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => openEditZone(zone)}>
                          <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => handleDeleteZone(zone.id)}>
                          <Trash2 className="h-3.5 w-3.5 text-destructive" />
                        </Button>
                      </div>
                    </div>
                    <div className="px-3 pb-2 text-xs text-muted-foreground">
                      {fmt(zone.base_fee)} · {fmt(zone.per_km_fee)}/km
                      {zone.children && zone.children.length > 0 && (
                        <span> · {zone.children.length} kecamatan</span>
                      )}
                    </div>
                  </div>
                ))
              )}
            </CardContent>
          </Card>
        )}

        {/* ── Right: map ── */}
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setShowZones((v) => !v)}
              className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium border transition-opacity ${showZones ? 'opacity-100' : 'opacity-40'}`}
            >
              <span className="inline-block w-3 h-3 rounded-full bg-green-600" /> Zone Areas
            </button>
            <button
              onClick={() => setShowMerchants((v) => !v)}
              className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium border transition-opacity ${showMerchants ? 'opacity-100' : 'opacity-40'}`}
            >
              🏪 Merchants ({merchants.filter((m) => m.latitude && m.longitude).length})
            </button>
            <button
              onClick={() => setShowDrivers((v) => !v)}
              className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium border transition-opacity ${showDrivers ? 'opacity-100' : 'opacity-40'}`}
            >
              🏍️ Drivers ({drivers.filter((d) => d.latitude && d.longitude).length})
              <Badge variant="secondary" className="text-xs ml-1">
                {drivers.filter((d) => d.is_online).length} online
              </Badge>
            </button>
          </div>

          <Card className="overflow-hidden">
            <CardContent className="p-0">
              <MapContainer center={LOMBOK_CENTER} zoom={10} style={{ height: '600px', width: '100%' }}>
                <TileLayer
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                />

                {/* Saved zones */}
                {showZones &&
                  zones.filter((z) => z.is_active).map((zone, i) => {
                    const color = ZONE_COLORS[i % ZONE_COLORS.length]
                    const renderZoneLayer = (z: Zone, col: string, isChild = false) => {
                      const popup = (
                        <Popup>
                          <div className="space-y-1 text-sm min-w-[180px]">
                            {isChild && <div className="text-xs text-muted-foreground">Kecamatan · {zone.city_name}</div>}
                            <div className="font-semibold text-base">{z.city_name}</div>
                            {z.is_default && <span className="text-xs bg-blue-100 text-blue-700 px-1 rounded">Default</span>}
                            {z.boundary_geojson ? (
                              <div className="text-xs text-green-600">✓ Polygon kecamatan</div>
                            ) : (
                              <div>Radius: {z.radius_km} km</div>
                            )}
                            {!isChild && (
                              <>
                                <div>Base fee: {fmt(z.base_fee)}</div>
                                <div>Per KM extra: {fmt(z.per_km_fee)}/km</div>
                                <div className="text-xs text-gray-500">
                                  {drivers.filter((d) => d.zone_id === z.id).length} driver ·{' '}
                                  {merchants.filter((m) => m.zone_id === z.id).length} merchant
                                </div>
                              </>
                            )}
                          </div>
                        </Popup>
                      )
                      if (z.boundary_geojson) {
                        // eslint-disable-next-line @typescript-eslint/no-explicit-any
                        let geoData: any = null
                        try {
                          geoData = JSON.parse(z.boundary_geojson)
                        } catch {
                          /* skip */
                        }
                        if (geoData) {
                          return (
                            <GeoJSONLayer
                              key={z.id}
                              data={geoData}
                              style={() => ({
                                color: col,
                                fillColor: col,
                                fillOpacity: isChild ? 0.06 : 0.1,
                                weight: isChild ? 1 : 2,
                                dashArray: isChild ? '4 4' : undefined,
                              })}
                            >
                              {popup}
                            </GeoJSONLayer>
                          )
                        }
                      }
                      if (!isChild) {
                        return (
                          <Circle
                            key={z.id}
                            center={[z.latitude, z.longitude]}
                            radius={z.radius_km * 1000}
                            pathOptions={{ color: col, fillColor: col, fillOpacity: 0.08, weight: 2 }}
                          >
                            {popup}
                          </Circle>
                        )
                      }
                      return null
                    }
                    return (
                      <>
                        {renderZoneLayer(zone, color)}
                        {zone.children?.filter((c) => c.is_active).map((child) => renderZoneLayer(child, color, true))}
                      </>
                    )
                  })}

                {/* Pending kecamatan candidates while panel is open — grey when
                    unselected, primary color when checked, previewing the
                    outside-zone/inside-zone split before saving. */}
                {panelOpen &&
                  allCandidates.map((c) => {
                    if (!c.geojson) return null
                    const selected = selectedKecamatan.has(c.osmId)
                    // eslint-disable-next-line @typescript-eslint/no-explicit-any
                    let geoData: any
                    try {
                      geoData = JSON.parse(c.geojson)
                    } catch {
                      return null
                    }
                    return (
                      <GeoJSONLayer
                        key={`cand-${c.osmId}`}
                        data={geoData}
                        style={() => ({
                          color: selected ? '#16a34a' : '#94a3b8',
                          fillColor: selected ? '#16a34a' : '#94a3b8',
                          fillOpacity: selected ? 0.18 : 0.05,
                          weight: selected ? 2 : 1,
                          dashArray: selected ? undefined : '3 5',
                        })}
                      >
                        <Popup>
                          <div className="text-sm font-medium">{c.name}</div>
                          <div className="text-xs text-muted-foreground">
                            {selected ? 'Masuk area layanan' : 'Di luar area layanan'}
                          </div>
                        </Popup>
                      </GeoJSONLayer>
                    )
                  })}

                {showMerchants &&
                  merchants.filter((m) => m.latitude && m.longitude).map((m) => (
                    <Marker key={m.id} position={[m.latitude, m.longitude]} icon={merchantIcon}>
                      <Popup>
                        <div className="text-sm">
                          <div className="font-semibold">{m.name}</div>
                          <div className={m.is_open ? 'text-green-600' : 'text-gray-400'}>{m.is_open ? 'Buka' : 'Tutup'}</div>
                          {m.zone_id && (
                            <div className="text-xs text-gray-500">
                              Zone: {zones.find((z) => z.id === m.zone_id)?.city_name ?? m.zone_id}
                            </div>
                          )}
                        </div>
                      </Popup>
                    </Marker>
                  ))}

                {showDrivers &&
                  drivers.filter((d) => d.latitude && d.longitude).map((d) => (
                    <Marker key={d.id} position={[d.latitude, d.longitude]} icon={driverIcon(d.is_online)}>
                      <Popup>
                        <div className="text-sm">
                          <div className="font-semibold">{d.user?.name ?? 'Driver'}</div>
                          <div className={d.is_online ? 'text-blue-600' : 'text-gray-400'}>{d.is_online ? 'Online' : 'Offline'}</div>
                          {d.zone_id && (
                            <div className="text-xs text-gray-500">
                              Zone: {zones.find((z) => z.id === d.zone_id)?.city_name ?? d.zone_id}
                            </div>
                          )}
                        </div>
                      </Popup>
                    </Marker>
                  ))}
              </MapContainer>
            </CardContent>
          </Card>

          {!panelOpen && (
            <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
              {zones.filter((z) => z.is_active).map((zone, i) => (
                <Card key={zone.id}>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm flex items-center gap-2">
                      <span className="inline-block w-3 h-3 rounded-full" style={{ background: ZONE_COLORS[i % ZONE_COLORS.length] }} />
                      {zone.city_name}
                      {zone.is_default && <Badge variant="secondary" className="text-xs">Default</Badge>}
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="text-xs text-muted-foreground space-y-0.5">
                    <div>Base fee: {fmt(zone.base_fee)} · Per KM: {fmt(zone.per_km_fee)}</div>
                    <div className="pt-1 text-foreground font-medium">
                      {drivers.filter((d) => d.zone_id === zone.id).length} driver ·{' '}
                      {merchants.filter((m) => m.zone_id === zone.id).length} merchant
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
