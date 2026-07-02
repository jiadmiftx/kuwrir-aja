import { useState, useEffect } from 'react'
import { MapContainer, TileLayer, Circle, GeoJSON, Marker, Popup } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
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
  is_active: boolean
  is_default: boolean
  boundary_geojson?: string
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

const fmt = (v: number) => 'Rp ' + v.toLocaleString('id-ID')

const LOMBOK_CENTER: [number, number] = [-8.6524, 116.3241]

export default function ZonesMapPage() {
  const [zones, setZones] = useState<Zone[]>([])
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [merchants, setMerchants] = useState<Merchant[]>([])
  const [showDrivers, setShowDrivers] = useState(true)
  const [showMerchants, setShowMerchants] = useState(true)
  const [showZones, setShowZones] = useState(true)

  useEffect(() => {
    api('/api/v1/admin/delivery-zones').then(r => r.json()).then(d => setZones(d.zones ?? []))
    api('/api/v1/admin/drivers').then(r => r.json()).then(d => setDrivers(d.drivers ?? []))
    api('/api/v1/admin/merchants').then(r => r.json()).then(d => setMerchants(d.merchants ?? []))
  }, [])

  const merchantIcon = L.divIcon({
    html: `<div style="background:#16a34a;color:white;border-radius:50%;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-size:14px;border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,.3)">🏪</div>`,
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  })

  const driverIcon = (online: boolean) => L.divIcon({
    html: `<div style="background:${online ? '#2563eb' : '#94a3b8'};color:white;border-radius:50%;width:28px;height:28px;display:flex;align-items:center;justify-content:center;font-size:14px;border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,.3)">🏍️</div>`,
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  })

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">Zone Map</h2>
        <p className="text-muted-foreground">Visualisasi wilayah pengiriman, merchant, dan driver</p>
      </div>

      {/* Legend & toggles */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setShowZones(v => !v)}
          className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium border transition-opacity ${showZones ? 'opacity-100' : 'opacity-40'}`}
        >
          <span className="inline-block w-3 h-3 rounded-full bg-green-600" /> Zone Areas
        </button>
        <button
          onClick={() => setShowMerchants(v => !v)}
          className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium border transition-opacity ${showMerchants ? 'opacity-100' : 'opacity-40'}`}
        >
          🏪 Merchants ({merchants.filter(m => m.latitude && m.longitude).length})
        </button>
        <button
          onClick={() => setShowDrivers(v => !v)}
          className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium border transition-opacity ${showDrivers ? 'opacity-100' : 'opacity-40'}`}
        >
          🏍️ Drivers ({drivers.filter(d => d.latitude && d.longitude).length})
          <Badge variant="secondary" className="text-xs ml-1">
            {drivers.filter(d => d.is_online).length} online
          </Badge>
        </button>
      </div>

      {/* Map */}
      <Card className="overflow-hidden">
        <CardContent className="p-0">
          <MapContainer
            center={LOMBOK_CENTER}
            zoom={10}
            style={{ height: '600px', width: '100%' }}
          >
            <TileLayer
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            />

            {/* Zone areas: GeoJSON polygon if available, else circle */}
            {showZones && zones.filter(z => z.is_active && z.latitude && z.longitude).map((zone, i) => {
              const color = ZONE_COLORS[i % ZONE_COLORS.length]
              const popup = (
                <Popup>
                  <div className="space-y-1 text-sm min-w-[180px]">
                    <div className="font-semibold text-base">{zone.city_name}</div>
                    {zone.is_default && <span className="text-xs bg-blue-100 text-blue-700 px-1 rounded">Default</span>}
                    {zone.boundary_geojson
                      ? <div className="text-xs text-green-600">✓ Batas wilayah polygon</div>
                      : <div>Radius: {zone.radius_km} km</div>
                    }
                    <div>Base fee: {fmt(zone.base_fee)}</div>
                    <div>Per KM extra: {fmt(zone.per_km_fee)}/km</div>
                    <div className="text-xs text-gray-500">
                      {drivers.filter(d => d.zone_id === zone.id).length} driver ·{' '}
                      {merchants.filter(m => m.zone_id === zone.id).length} merchant
                    </div>
                  </div>
                </Popup>
              )
              if (zone.boundary_geojson) {
                let geoData: GeoJSON.GeoJsonObject | null = null
                try { geoData = JSON.parse(zone.boundary_geojson) } catch { /* skip */ }
                if (geoData) {
                  return (
                    <GeoJSON
                      key={zone.id}
                      data={geoData}
                      style={() => ({ color, fillColor: color, fillOpacity: 0.1, weight: 2 })}
                    >
                      {popup}
                    </GeoJSON>
                  )
                }
              }
              return (
                <Circle
                  key={zone.id}
                  center={[zone.latitude, zone.longitude]}
                  radius={zone.radius_km * 1000}
                  pathOptions={{ color, fillColor: color, fillOpacity: 0.08, weight: 2 }}
                >
                  {popup}
                </Circle>
              )
            })}

            {/* Merchant markers */}
            {showMerchants && merchants.filter(m => m.latitude && m.longitude).map(m => (
              <Marker key={m.id} position={[m.latitude, m.longitude]} icon={merchantIcon}>
                <Popup>
                  <div className="text-sm">
                    <div className="font-semibold">{m.name}</div>
                    <div className={m.is_open ? 'text-green-600' : 'text-gray-400'}>
                      {m.is_open ? 'Buka' : 'Tutup'}
                    </div>
                    {m.zone_id && (
                      <div className="text-xs text-gray-500">
                        Zone: {zones.find(z => z.id === m.zone_id)?.city_name ?? m.zone_id}
                      </div>
                    )}
                  </div>
                </Popup>
              </Marker>
            ))}

            {/* Driver markers */}
            {showDrivers && drivers.filter(d => d.latitude && d.longitude).map(d => (
              <Marker key={d.id} position={[d.latitude, d.longitude]} icon={driverIcon(d.is_online)}>
                <Popup>
                  <div className="text-sm">
                    <div className="font-semibold">{d.user?.name ?? 'Driver'}</div>
                    <div className={d.is_online ? 'text-blue-600' : 'text-gray-400'}>
                      {d.is_online ? 'Online' : 'Offline'}
                    </div>
                    {d.zone_id && (
                      <div className="text-xs text-gray-500">
                        Zone: {zones.find(z => z.id === d.zone_id)?.city_name ?? d.zone_id}
                      </div>
                    )}
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </CardContent>
      </Card>

      {/* Zone summary cards */}
      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
        {zones.filter(z => z.is_active).map((zone, i) => (
          <Card key={zone.id}>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center gap-2">
                <span
                  className="inline-block w-3 h-3 rounded-full"
                  style={{ background: ZONE_COLORS[i % ZONE_COLORS.length] }}
                />
                {zone.city_name}
                {zone.is_default && <Badge variant="secondary" className="text-xs">Default</Badge>}
              </CardTitle>
            </CardHeader>
            <CardContent className="text-xs text-muted-foreground space-y-0.5">
              <div>Radius: {zone.radius_km} km · Base fee: {fmt(zone.base_fee)}</div>
              <div>Per KM extra: {fmt(zone.per_km_fee)}</div>
              <div className="pt-1 text-foreground font-medium">
                {drivers.filter(d => d.zone_id === zone.id).length} driver ·{' '}
                {merchants.filter(m => m.zone_id === zone.id).length} merchant
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}
